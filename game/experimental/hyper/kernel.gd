extends "res://experimental/apex2/driver_kernel_12.gd"
## Hyper Evolution: isolated playable successor to Racecraft 1.3.
const Resolver = preload("res://experimental/hyper/traffic.gd")
const Control306 = preload("res://experimental/hyper2/race_control_306.gd")
const RACECRAFT_TAG: String = "APEX2_HYPER_2.0_ALPHA1"

const IndexedQueue = preload("res://experimental/hyper/indexed_queue.gd")
const Env = preload("res://experimental/hyper/environment.gd")
const DRY: Array[String] = ["Macio", "Médio", "Duro"]
const PIT_TRANSIT_TICKS: int = 42 # stationary-equivalent entry/exit loss, not pit lane geometry
const SERVICE_TICKS: int = 15

func initialize(scenario: Dictionary) -> bool:
	if not Env.valid_weather(scenario.get("hyper_weather", [])) or not Env.valid_zones(scenario.get("hyper_drs_zones", [])):
		return false
	if not super.initialize(scenario):
		return false
	queue = IndexedQueue.new()
	state["racecraft_model"] = RACECRAFT_TAG
	state["hyper_drs_zones"] = scenario.get("hyper_drs_zones", []).duplicate(true)
	if scenario.has("hyper_career_token"):
		state["hyper_career_token"] = str(scenario.hyper_career_token)
	state["hyper_weather"] = scenario.get("hyper_weather", []).duplicate(true)
	state["hyper_weather_cursor"] = 0
	state["hyper_strategy_auto"] = bool(scenario.get("hyper_strategy_auto", true))
	state["hyper_player_team"] = str(scenario.get("hyper_player_team", "Ferrari"))
	state["hyper_player_pit_auto"] = bool(scenario.get("hyper_player_pit_auto", true))
	state["hyper_pit_transit"] = clampi(int(scenario.get("hyper_pit_loss_ms", 21000)) / STEP_MS - SERVICE_TICKS, 30, 180)
	state["racecraft_passes"] = 0
	state["racecraft_attempts"] = 0
	state["racecraft_aborts"] = 0
	state["racecraft_last_tick"] = 0
	for car in state.cars:
		car["racecraft"] = Resolver.initial_state()
		car["traffic_speed_cap_mm_s"] = Resolver.MAX_V_MM_S
		car["hyper"] = {"pit_count": 0, "pit_remaining": 0, "last_pit_lap": 0, "pit_arrival": -1, "compounds_used": [str(car.tire)], "kers_j": 400000, "kers_lap": 0, "wake_drag": 1000, "wake_downforce": 1000, "finish_tick": -1, "retired": false, "strategy_reason": "initial", "setup_wet": 0, "drs_prev_progress": int(car.progress_units), "drs_armed_lap": -1, "drs_armed": [], "drs_active": false}
		var spec: Dictionary = scenario.get("hyper_specs", {}).get(str(car.id), {})
		car.dynamics.wheel_power_w = clampi(int(spec.get("power", 510000)), 470000, 535000)
		car.dynamics.drag_milli = clampi(int(spec.get("drag", 1130)), 1040, 1220)
		car.dynamics.downforce_milli = clampi(int(spec.get("downforce", 2650)), 2300, 2900)
		car.hyper.setup_wet = clampi(int(spec.get("wet_setup", 0)), 0, 1000)
		if spec.has("service_ticks"): car.hyper.service_ticks = clampi(int(spec.service_ticks),10,20)
		if spec.has("strategy_interval"): car.hyper.strategy_interval = 100 if int(spec.strategy_interval) >= 100 else 50
	return true

func step_tick() -> bool:
	if not initialized or bool(state.finished) or int(state.tick) >= MAX_TICKS:
		return false
	_weather_next()
	_pit_service()
	if int(state.tick) % 50 == 0:
		_strategy_cycle()
	var prior_distances: Dictionary = {}
	for car in state.cars:
		prior_distances[int(car.id)] = int(car.dynamics.distance_mm)
	var control_snapshot:Dictionary={}
	if state.has(Control306.KEY) and int(state.mega_control.remaining)>0:control_snapshot=Control306.begin(state[Control306.KEY],state.cars,int(state.lap_length_mm))
	var action: Dictionary = Resolver.plan(state.cars, state.track_profile, int(state.lap_length_mm), int(state.tick) + 1,int(state.water_microns))
	if state.has("wet_attack_reasons"):
		for reason in action.wet_reasons:state.wet_attack_reasons[reason]=int(state.wet_attack_reasons[reason])+int(action.wet_reasons[reason])
	for car in state.cars:
		var id: int = int(car.id)
		car.racecraft = action.states[id]
		car.traffic_speed_cap_mm_s = int(action.speed_caps[id])
		if not control_snapshot.is_empty():car.traffic_speed_cap_mm_s=mini(int(car.traffic_speed_cap_mm_s),int(control_snapshot.caps.get(id,Control306.CAP_MM_S)))
	_wake_grid(action.wake_gaps)
	for car in state.cars:
		Env.drs_update(car,state.hyper_drs_zones,int(action.physical_front_gaps.get(int(car.id),state.lap_length_mm)),int(state.water_microns))
		if bool(car.get("mega_30",{}).get("neutral",false)):
			car.hyper.drs_active=false;car.hyper.drs_armed=[]
	var advanced: bool = super.step_tick()
	if not advanced:
		return false
	state.racecraft_last_tick = int(state.tick)
	for car in state.cars:
		if bool(car.finished) and int(car.hyper.finish_tick) < 0:
			car.hyper.finish_tick = int(state.tick)
		if not bool(car.finished) and int(car.dynamics.fuel_g) == 0 and int(car.dynamics.speed_mm_s) <= 1000:
			car.finished = true
			car.hyper.retired = true
			car.hyper.finish_tick = int(state.tick)
			_event("hyper_retired", int(car.id), {"reason": "fuel_exhausted"})
	for transition in action.transitions:
		if str(transition.phase) == "ATTACK": state.racecraft_attempts = int(state.racecraft_attempts) + 1
		if str(transition.phase) == "ABORT": state.racecraft_aborts = int(state.racecraft_aborts) + 1
		_event(str(transition.type), int(transition.car_id), {"phase": str(transition.phase), "reason": str(transition.reason)})
	# Sporting positions derive only from vehicle distance, not a duel scoreboard.
	for car in state.cars:
		var r: Dictionary = car.racecraft
		if bool(car.hyper.retired) or str(car.pit_stage) != "TRACK" or str(r.phase) not in ["ATTACK", "SIDE_BY_SIDE"]:
			continue
		var target: Dictionary = _lookup_car(int(r.target_id))
		if car.has("mega_30") and (bool(r.get("lapping",false)) or target.get("finished",false) or bool(car.mega_30.neutral)):continue
		if target.is_empty() or bool(target.hyper.retired) or str(target.pit_stage) != "TRACK":
			continue
		var id: int = int(car.id)
		var opponent_id: int = int(target.id)
		var old_delta: int = int(prior_distances[id]) - int(prior_distances[opponent_id])
		var new_delta: int = int(car.dynamics.distance_mm) - int(target.dynamics.distance_mm)
		if old_delta <= Resolver.CROSS_CONFIRM_MM and new_delta > Resolver.CROSS_CONFIRM_MM and str(r.lane) != str(target.racecraft.lane):
			r.passes = int(r.passes) + 1
			state.racecraft_passes = int(state.racecraft_passes) + 1
			_event("racecraft_overtake_confirmed", id, {"defender_id": opponent_id, "gap_mm": new_delta, "lane": str(r.lane)})
			Resolver._phase(r, "RECOVER", int(state.tick), [], id, "pass_confirmed")
			r.cooldown_until = int(state.tick) + 35
	if not control_snapshot.is_empty():
		for warning in Control306.settle(state[Control306.KEY],control_snapshot.rows,Control306.snapshot(state.cars),int(state.mega_control.remaining)<=1,int(state.lap_length_mm)):
			_event(str(warning.type),int(warning.car_id),warning)
	return true

func _apply_command(command: Dictionary) -> Dictionary:
	var car: Dictionary = _lookup_car(int(command.car_id))
	if not car.is_empty() and str(command.type) == "cancel_pit" and str(car.pit_stage) != "TRACK":
		return {"ok": false, "reason": "pit_already_in_progress"}
	return super._apply_command(command)

func _weather_next() -> void:
	var cursor: int = int(state.hyper_weather_cursor)
	while cursor < state.hyper_weather.size() and int(state.hyper_weather[cursor].tick) <= int(state.tick) + 1:
		state.water_microns = int(state.hyper_weather[cursor].water)
		cursor += 1
		_event("hyper_weather_change", -1, {"water_microns": int(state.water_microns)})
	state.hyper_weather_cursor = cursor

func _strategy_cycle() -> void:
	if not bool(state.hyper_strategy_auto):
		return
	for car in state.cars:
		if bool(car.finished) or str(car.pit_stage) != "TRACK" or int(car.pit_requested_lap) > 0:
			continue
		if int(state.tick) % int(car.hyper.get("strategy_interval",50)) != 0: continue
		if str(car.team) == str(state.hyper_player_team) and not bool(state.hyper_player_pit_auto):
			continue
		var lap: int = int(car.laps_done) + 1
		if lap >= int(state.race_laps) - 1 or lap - int(car.hyper.last_pit_lap) < 2:
			continue
		var advice: Dictionary = Env.pit_advice(car, state.compounds, int(state.water_microns), int(state.race_laps) - lap)
		car.hyper.strategy_reason = str(advice.reason)
		if not bool(advice.stop):
			continue
		var result: Dictionary = submit({"type": "order_pit", "source": "AI", "car_id": int(car.id), "compound": str(advice.compound), "allow_double_stack": true})
		if bool(result.accepted):
			_event("hyper_strategy_order", int(car.id), {"reason": str(advice.reason), "compound": str(advice.compound)})

func _pit_service() -> void:
	# Each garage services only one car; transit is independent of the garage.
	var busy: Dictionary = {}
	var waiting: Array = []
	for car in state.cars:
		if bool(car.finished):
			continue
		var h: Dictionary = car.hyper
		match str(car.pit_stage):
			"ENTRY_OBSERVED":
				car.pit_stage = "PIT_IN"
				h.pit_remaining = int(state.hyper_pit_transit) / 2
				h.pit_arrival = int(car.pit_entry_tick)
				car.racecraft = _clear_duel(car.racecraft)
			"PIT_IN", "PIT_OUT", "PIT_SERVICE":
				h.pit_remaining = maxi(0, int(h.pit_remaining) - 1)
				if int(h.pit_remaining) == 0:
					if str(car.pit_stage) == "PIT_IN":
						car.pit_stage = "PIT_WAIT"
					elif str(car.pit_stage) == "PIT_SERVICE":
						car.tire = str(car.pit_target)
						car.dynamics.wear_micro = 0
						car.dynamics.wear_remainder = 0
						car.dynamics.tire_temp_centi = int(state.ambient_centi) + 3500
						h.pit_count = int(h.pit_count) + 1
						h.last_pit_lap = int(car.pit_requested_lap)
						if not str(car.tire) in h.compounds_used:
							h.compounds_used.append(str(car.tire))
						car.pit_stage = "PIT_OUT"
						h.pit_remaining = int(state.hyper_pit_transit) - int(int(state.hyper_pit_transit) / 2)
						_event("hyper_pit_serviced", int(car.id), {"compound": str(car.tire), "lap": int(h.last_pit_lap)})
					else:
						car.pit_stage = "TRACK"
						car.pit_requested_lap = 0
						car.pit_order_source = ""
						car.pit_target = ""
						_event("hyper_pit_exit", int(car.id))
		if str(car.pit_stage) == "PIT_SERVICE":
			busy[str(car.team)] = true
		elif str(car.pit_stage) == "PIT_WAIT":
			waiting.append(car)
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.hyper.pit_arrival) == int(b.hyper.pit_arrival): return int(a.id) < int(b.id)
		return int(a.hyper.pit_arrival) < int(b.hyper.pit_arrival))
	for car in waiting:
		if busy.has(str(car.team)):
			continue
		busy[str(car.team)] = true
		car.pit_stage = "PIT_SERVICE"
		car.hyper.pit_remaining = int(car.hyper.get("service_ticks",SERVICE_TICKS))
		if int(car.get("mega_30",{}).get("damage",0))>0:
			car.hyper.pit_remaining+=4 # 0.8s for partial repair, existing garage occupied
		_event("hyper_pit_service_start", int(car.id))

func _clear_duel(old: Dictionary) -> Dictionary:
	var r: Dictionary = Resolver.initial_state()
	for key in ["passes", "attempts", "aborts"]:
		r[key] = old[key]
	return r

func _wake_grid(gaps: Dictionary) -> void:
	for car in state.cars:
		var h: Dictionary = car.hyper
		h.wake_drag = 1000
		h.wake_downforce = 1000
		if bool(car.finished) or str(car.pit_stage) != "TRACK": continue
		var gap: int = int(gaps.get(int(car.id),65001))
		if gap > 65000: continue
		var location: int = posmod(int(car.dynamics.distance_mm), int(state.lap_length_mm))
		var idx: int = Vehicle._profile_index(state.track_profile, location)
		var effect: Dictionary = Env.wake(gap, int(state.track_profile[idx].radius_mm))
		h.wake_drag = int(effect.drag)
		h.wake_downforce = int(effect.downforce)

func _advance_reference_car(car: Dictionary, previous: int) -> void:
	if str(car.pit_stage) != "TRACK":
		car.dynamics.speed_mm_s = 0
		return
	var h: Dictionary = car.hyper
	var d: Dictionary = car.dynamics
	if int(h.kers_lap) != int(car.laps_done):
		h.kers_lap = int(car.laps_done)
		h.kers_j = 400000
	var power: int = int(d.wheel_power_w)
	var drag: int = int(d.drag_milli)
	var downforce: int = int(d.downforce_milli)
	var boost: int = mini(12000, int(h.kers_j)) if str(car.pace) == "Atacar" and int(d.speed_mm_s) > 25000 and int(d.fuel_g) > 0 else 0
	if bool(car.get("mega_30",{}).get("neutral",false)) or bool(car.get("mega_30",{}).get("failure",false)):boost=0
	car["hyper_kers_power_w"] = int(boost * 1000 / STEP_MS)
	d.wheel_power_w = power + int(car.hyper_kers_power_w)
	# DRS zones come from the original project's approximations; no official geometry claimed.
	var drs_factor: int = 850 if bool(h.drs_active) and int(d.speed_mm_s) <= int(car.traffic_speed_cap_mm_s) else 1000
	d.drag_milli = int(drag * int(h.wake_drag) * drs_factor / 1000000)
	var mismatch: int = absi(int(h.setup_wet) - int(int(state.water_microns) / 6))
	d.downforce_milli = int(downforce * int(h.wake_downforce) * (1000 - int(mismatch / 15)) / 1000000)
	super._advance_reference_car(car, previous)
	if d.has("powertrain_22"):
		h.kers_j=maxi(0,int(h.kers_j)-mini(boost,int(d.powertrain_22.kers_used_j)))
	elif int(d.last_brake_n) == 0:
		h.kers_j = int(h.kers_j) - boost
	car.erase("hyper_kers_power_w")
	d.wheel_power_w = power
	d.drag_milli = drag
	d.downforce_milli = downforce

func classification() -> Array:
	var rows: Array = []
	for car in state.cars:
		rows.append({"id": int(car.id), "name": str(car.name), "team": str(car.team), "laps": int(car.laps_done), "progress": int(car.progress_units), "tire": str(car.tire), "wear": int(car.dynamics.wear_micro), "speed": int(car.dynamics.speed_mm_s), "pit": str(car.pit_stage), "stops": int(car.hyper.pit_count), "phase": str(car.racecraft.phase), "drs": bool(car.hyper.drs_active), "kers_j": int(car.hyper.kers_j), "finish_tick": int(car.hyper.finish_tick), "retired": bool(car.hyper.retired), "finished": bool(car.finished)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.retired) != bool(b.retired): return not bool(a.retired)
		if bool(a.finished) != bool(b.finished): return bool(a.finished)
		if bool(a.finished) and not bool(a.retired) and int(a.finish_tick) != int(b.finish_tick): return int(a.finish_tick) < int(b.finish_tick)
		if int(a.progress) != int(b.progress): return int(a.progress) > int(b.progress)
		return int(a.id) < int(b.id))
	return rows

func restore(data: Dictionary) -> bool:
	if not data.get("state", null) is Dictionary:
		return false
	var candidate: Dictionary = data.state
	if candidate.has("hyper_evolution_revision") and get_script().resource_path == "res://experimental/hyper/kernel.gd": return false
	if not candidate.has_all(["hyper_weather", "hyper_drs_zones", "hyper_weather_cursor", "hyper_strategy_auto", "hyper_player_team", "hyper_player_pit_auto", "hyper_pit_transit"]) or not Env.valid_weather(candidate.hyper_weather) or not Env.valid_zones(candidate.hyper_drs_zones):
		return false
	if int(candidate.hyper_weather_cursor) < 0 or int(candidate.hyper_weather_cursor) > candidate.hyper_weather.size() or int(candidate.hyper_pit_transit) < 30 or int(candidate.hyper_pit_transit) > 180:
		return false
	var busy: Dictionary = {}
	for car in candidate.get("cars", []):
		if not car is Dictionary or not car.get("hyper", null) is Dictionary:
			return false
		var h: Dictionary = car.hyper
		if not h.has_all(["pit_count", "pit_remaining", "last_pit_lap", "pit_arrival", "compounds_used", "kers_j", "kers_lap", "wake_drag", "wake_downforce", "finish_tick", "retired", "strategy_reason", "setup_wet", "drs_prev_progress", "drs_armed_lap", "drs_armed", "drs_active"]): return false
		if int(h.kers_j) < 0 or int(h.kers_j) > 400000 or int(h.pit_remaining) < 0 or int(h.pit_remaining) > 180 or int(h.pit_count) < 0 or int(h.setup_wet) < 0 or int(h.setup_wet) > 1000 or not h.compounds_used is Array: return false
		if h.has("service_ticks") and (typeof(h.service_ticks) != TYPE_INT or int(h.service_ticks) < 10 or int(h.service_ticks) > 20): return false
		if h.has("strategy_interval") and int(h.strategy_interval) not in [50,100]: return false
		if not h.drs_armed is Array or typeof(h.drs_active) != TYPE_BOOL: return false
		for idx in h.drs_armed:
			if typeof(idx) != TYPE_INT or int(idx) < 0 or int(idx) >= candidate.hyper_drs_zones.size(): return false
		if str(car.get("pit_stage", "")) not in ["TRACK", "ENTRY_OBSERVED", "PIT_IN", "PIT_WAIT", "PIT_SERVICE", "PIT_OUT"]: return false
		if str(car.pit_stage) == "PIT_SERVICE":
			if busy.has(str(car.team)): return false
			busy[str(car.team)] = true
	if str(candidate.get("racecraft_model", "")) != RACECRAFT_TAG:
		return false
	if not candidate.has_all(["racecraft_passes", "racecraft_attempts", "racecraft_aborts", "racecraft_last_tick"]):
		return false
	for key in ["racecraft_passes", "racecraft_attempts", "racecraft_aborts", "racecraft_last_tick"]:
		if typeof(candidate[key]) != TYPE_INT or int(candidate[key]) < 0:
			return false
	if int(candidate.racecraft_last_tick) > int(candidate.get("tick", -1)):
		return false
	var roster: Dictionary = {}
	for car in candidate.get("cars", []):
		if not car is Dictionary or not car.get("racecraft", null) is Dictionary:
			return false
		roster[int(car.get("id", -1))] = true
	for car in candidate.cars:
		var r: Dictionary = car.racecraft
		if not r.has_all(["schema", "phase", "lane", "target_id", "phase_tick", "cooldown_until", "defense_used", "passes", "aborts", "attempts", "last_gap_mm"]):
			return false
		if int(r.schema) != Resolver.SCHEMA or str(r.phase) not in Resolver.PHASES or str(r.lane) not in Resolver.LANES:
			return false
		if typeof(r.target_id) != TYPE_INT or (int(r.target_id) != -1 and (not roster.has(int(r.target_id)) or int(r.target_id) == int(car.id))):
			return false
		for key in ["phase_tick", "cooldown_until", "passes", "aborts", "attempts"]:
			if typeof(r[key]) != TYPE_INT or int(r[key]) < 0:
				return false
		if int(r.phase_tick) > int(candidate.tick) or typeof(r.defense_used) != TYPE_BOOL:
			return false
		if typeof(car.get("traffic_speed_cap_mm_s", null)) != TYPE_INT or int(car.traffic_speed_cap_mm_s) < 0 or int(car.traffic_speed_cap_mm_s) > Resolver.MAX_V_MM_S:
			return false
	if not super.restore(data): return false
	var indexed = IndexedQueue.new()
	if not indexed.restore_state(queue.export_state()): return false
	queue = indexed
	return true
