extends "res://experimental/apex2/driver_kernel_12.gd"
## APEX 2 / Racecraft 1.3 is isolated. The official Core2 session is unchanged.
const Resolver = preload("res://experimental/apex2/racecraft_resolver.gd")
const RACECRAFT_TAG: String = "APEX2_RACECRAFT_1.3_EXPERIMENTAL_CORRIDORS"

func initialize(scenario: Dictionary) -> bool:
	if not super.initialize(scenario):
		return false
	state["racecraft_model"] = RACECRAFT_TAG
	state["racecraft_passes"] = 0
	state["racecraft_attempts"] = 0
	state["racecraft_aborts"] = 0
	state["racecraft_last_tick"] = 0
	for car in state.cars:
		car["racecraft"] = Resolver.initial_state()
		car["traffic_speed_cap_mm_s"] = Resolver.MAX_V_MM_S
	return true

func step_tick() -> bool:
	if not initialized or bool(state.finished) or int(state.tick) >= MAX_TICKS:
		return false
	var prior_distances: Dictionary = {}
	for car in state.cars:
		prior_distances[int(car.id)] = int(car.dynamics.distance_mm)
	var action: Dictionary = Resolver.plan(state.cars, state.track_profile, int(state.lap_length_mm), int(state.tick) + 1)
	for car in state.cars:
		var id: int = int(car.id)
		car.racecraft = action.states[id]
		car.traffic_speed_cap_mm_s = int(action.speed_caps[id])
	var advanced: bool = super.step_tick()
	if not advanced:
		return false
	state.racecraft_last_tick = int(state.tick)
	for transition in action.transitions:
		_event(str(transition.type), int(transition.car_id), {"phase": str(transition.phase), "reason": str(transition.reason)})
	# Sporting positions derive only from vehicle distance, not a duel scoreboard.
	for car in state.cars:
		var r: Dictionary = car.racecraft
		if str(r.phase) not in ["ATTACK", "SIDE_BY_SIDE"]:
			continue
		var target: Dictionary = _lookup_car(int(r.target_id))
		if target.is_empty():
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
	for car in state.cars:
		var r: Dictionary = car.racecraft
		if str(r.phase) == "ABORT" and int(r.phase_tick) == int(state.tick):
			state.racecraft_aborts = int(state.racecraft_aborts) + 1
		if str(r.phase) == "ATTACK" and int(r.phase_tick) == int(state.tick):
			state.racecraft_attempts = int(state.racecraft_attempts) + 1
	return true

func restore(data: Dictionary) -> bool:
	if not data.get("state", null) is Dictionary:
		return false
	var candidate: Dictionary = data.state
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
	return super.restore(data)
