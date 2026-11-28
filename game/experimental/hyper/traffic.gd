extends RefCounted
## APEX 2 / Racecraft Resolver 1.3: experimental, deterministic encounter service.
## Inputs: immutable-in-practice pre-tick longitudinal roster + persistent duel states.
## Output: desired lanes, finite-speed following constraints and ordered transitions.
## No direct progress/position edits; overtakes require actual longitudinal crossing.
## Lane/corner capacity is a synthetic corridor abstraction, NOT surveyed geometry.
const Dynamics23 = preload("res://experimental/hyper2/dynamics_23.gd")
const Geometry302 = preload("res://experimental/hyper2/geometry_302.gd")
const Wet303 = preload("res://experimental/hyper2/wet_303.gd")
const WetRacecraft3064 = preload("res://experimental/hyper2/wet_racecraft_3064.gd")
const Style305 = preload("res://experimental/hyper2/racecraft_305.gd")
const SCHEMA: int = 13
const PHASES: Array[String] = ["CRUISE", "APPROACH", "PREPARE", "ATTACK", "SIDE_BY_SIDE", "DEFEND", "ABORT", "RECOVER"]
const LANES: Array[String] = ["CENTER", "LEFT", "RIGHT"]
const SEARCH_MM: int = 90000
const PREPARE_MM: int = 48000
const INITIATE_MM: int = 29000
const SIDE_BY_SIDE_MM: int = 5500
const FOLLOW_MM: int = 22000
const SAFE_MM: int = 10000
const CROSS_CONFIRM_MM: int = 2500
const LANE_CLEAR_MM: int = 11000
const CORNER_PASS_MIN_RADIUS_MM: int = 125000
const MAX_V_MM_S: int = 106000

static func wrapped_delta(other: int, own: int, lap_mm: int) -> int:
	return posmod(other - own + int(lap_mm / 2), lap_mm) - int(lap_mm / 2)

static func initial_state() -> Dictionary:
	return {"schema": SCHEMA, "phase": "CRUISE", "lane": "CENTER", "target_id": -1,
		"phase_tick": 0, "cooldown_until": 0, "defense_used": false,
		"passes": 0, "aborts": 0, "attempts": 0, "last_gap_mm": -1}

static func _phase(entry: Dictionary, next_phase: String, tick: int, events: Array, car_id: int, reason: String) -> void:
	if str(entry.phase) == next_phase:
		return
	entry.phase = next_phase
	entry.phase_tick = tick
	events.append({"type": "racecraft_phase", "car_id": car_id, "phase": next_phase, "reason": reason})

static func _lane_allowed(lane: String, car_id: int, distance_mm: int, proposed: Dictionary, roster: Array, lap_mm: int) -> bool:
	for opponent in roster:
		var other_id: int = int(opponent.id)
		if other_id == car_id or bool(opponent.finished) or str(opponent.pit_stage) != "TRACK":
			continue
		if absi(wrapped_delta(int(opponent.dynamics.distance_mm), distance_mm, lap_mm)) > LANE_CLEAR_MM:
			continue
		var other_state: Dictionary = proposed.get(other_id, opponent.racecraft)
		if str(other_state.lane) == lane:
			return false
	return true

static func _future_clear(lane:String,car:Dictionary,proposed:Dictionary,roster:Array,lap:int)->bool:
	# Half-second constant-velocity projection; not a collision solver.
	var own:int=int(car.dynamics.distance_mm)+int(car.dynamics.speed_mm_s)/2
	for other in roster:
		if int(other.id)==int(car.id) or other.finished or str(other.pit_stage)!="TRACK":continue
		if str(proposed.get(int(other.id),other.racecraft).lane)!=lane:continue
		var projected:int=int(other.dynamics.distance_mm)+int(other.dynamics.speed_mm_s)/2
		if absi(wrapped_delta(projected,own,lap))<=LANE_CLEAR_MM:return false
	return true
static func _can_pass(profile: Array, lap_mm: int, distance_mm: int) -> bool:
	if profile.is_empty() or lap_mm <= 0:
		return false
	var location: int = posmod(distance_mm, lap_mm)
	if profile[0].has("curvature"):return Geometry302.radius_at(profile,lap_mm,location)>=CORNER_PASS_MIN_RADIUS_MM
	return int(profile[Geometry302.index(profile,location)].radius_mm) >= CORNER_PASS_MIN_RADIUS_MM

static func plan(roster: Array, profile: Array, lap_mm: int, tick: int, water: int=0, wet_refinement:bool=false) -> Dictionary:
	## No writes to the supplied roster. Loop order is by stable car id.
	var by_id: Dictionary = {}
	var ids: Array[int] = []
	for car in roster:
		by_id[int(car.id)] = car
		ids.append(int(car.id))
	ids.sort()
	# The next car on the same sporting lap can be found by sorted absolute distance.
	# Physical traffic across the finish line is indexed separately below.
	var absolute: Array = []
	for car in roster:
		if not bool(car.finished) and str(car.pit_stage) == "TRACK":
			absolute.append([int(car.dynamics.distance_mm), int(car.id)])
	absolute.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]) if int(a[0]) == int(b[0]) else int(a[0]) < int(b[0]))
	var next_sporting: Dictionary = {}
	for i in range(absolute.size()):
		var j: int = i + 1
		while j < absolute.size() and int(absolute[j][0]) == int(absolute[i][0]): j += 1
		if j < absolute.size(): next_sporting[int(absolute[i][1])] = absolute[j]
	# Physical front neighbour is separate from rank (Alpha 2 lapping).
	var physical: Array=[]
	var physical_next: Dictionary={}
	if not roster.is_empty() and roster[0].has("evolution"):
		for item in absolute: physical.append([posmod(int(item[0]),lap_mm),int(item[1]),int(item[0])])
		physical.sort_custom(func(a:Array,b:Array)->bool:return int(a[1])<int(b[1]) if a[0]==b[0] else int(a[0])<int(b[0]))
		for i in range(physical.size()):
			if physical.size()<2:break
			var front:Array=physical[(i+1)%physical.size()]
			physical_next[int(physical[i][1])]=[int(front[1]),posmod(int(front[0])-int(physical[i][0]),lap_mm),int(front[2])]
	var wet_reasons:Dictionary={}
	if not roster.is_empty() and roster[0].has(Wet303.KEY):wet_reasons=Wet303.counters()
	var proposed: Dictionary = {}
	var transitions: Array = []
	var claims: Dictionary = {}
	for active in roster:
		if not bool(active.finished) and str(active.pit_stage) == "TRACK" and str(active.racecraft.phase) in ["ATTACK", "SIDE_BY_SIDE"]:
			claims[int(active.racecraft.target_id)] = int(active.id)
	for id in ids:
		var car: Dictionary = by_id[id]
		var r: Dictionary = proposed.get(id, car.racecraft).duplicate(true)
		proposed[id] = r
		if bool(car.finished) or str(car.pit_stage) != "TRACK":
			continue
		var distance: int = int(car.dynamics.distance_mm)
		var speed: int = int(car.dynamics.speed_mm_s)
		var front_id: int = -1
		var gap: int = SEARCH_MM + 1
		if next_sporting.has(id):
			var next: Array = next_sporting[id]
			var difference: int = int(next[0]) - distance
			if difference <= SEARCH_MM:
				gap = difference
				front_id = int(next[1])
		var is_lapping:bool=false
		if physical_next.has(id):
			var near:Array=physical_next[id]
			if int(near[1])>0 and int(near[1])<gap and distance-int(near[2])>lap_mm/2:
				front_id=int(near[0]);gap=int(near[1]);is_lapping=true
		var styled:bool=car.has(Style305.KEY)
		var phase: String = str(r.phase)
		if bool(car.get("mega_30",{}).get("neutral",false)) and phase in ["APPROACH","PREPARE","ATTACK","SIDE_BY_SIDE"]:
			_phase(r,"ABORT",tick,transitions,id,"virtual_neutralization")
			phase="ABORT";r.aborts=int(r.aborts)+1
		var target_id: int = int(r.target_id)
		var target_gap: int = -1
		if by_id.has(target_id):
			target_gap = int(by_id[target_id].dynamics.distance_mm) - distance
			if bool(r.get("lapping",false)):target_gap=wrapped_delta(int(by_id[target_id].dynamics.distance_mm),distance,lap_mm)
		if phase == "DEFEND":
			# Defender holds a single lawful move until attacker leaves the duel.
			var attacker: Dictionary = by_id.get(target_id, {})
			if attacker.is_empty() or str(proposed.get(target_id, attacker.racecraft).phase) not in ["PREPARE", "ATTACK", "SIDE_BY_SIDE"]:
				_phase(r, "RECOVER", tick, transitions, id, "threat_resolved")
			elif tick - int(r.phase_tick) > 150:
				_phase(r, "RECOVER", tick, transitions, id, "defense_timeout")
		elif phase in ["ABORT", "RECOVER"]:
			if phase == "ABORT" and tick - int(r.phase_tick) >= 3:
				_phase(r, "RECOVER", tick, transitions, id, "attack_disengaged")
			elif phase == "RECOVER" and tick - int(r.phase_tick) >= 8 and _lane_allowed("CENTER", id, distance, proposed, roster, lap_mm):
				_phase(r, "CRUISE", tick, transitions, id, "lane_restored")
				r.target_id = -1
				r.erase("lapping")
				r.defense_used = false
				r.lane = "CENTER"
		elif phase == "CRUISE":
			if not bool(car.get("mega_30",{}).get("neutral",false)) and tick >= int(r.cooldown_until) and front_id >= 0 and gap < SEARCH_MM and (Style305.approach(car,gap,speed-int(by_id[front_id].dynamics.speed_mm_s),water) if styled else speed-int(by_id[front_id].dynamics.speed_mm_s)>=1700):
				r.target_id = front_id
				if car.has("evolution"):r["lapping"]=is_lapping
				_phase(r, "APPROACH", tick, transitions, id, "lapping_traffic" if is_lapping else "closing_on_slower_car")
		elif phase == "APPROACH":
			if front_id != target_id or target_gap < 0 or target_gap > SEARCH_MM:
				_phase(r, "ABORT", tick, transitions, id, "opportunity_lost")
				r.aborts = int(r.aborts) + 1
			elif (bool(r.get("lapping",false)) or (Style305.prepare(car,target_gap,speed-int(by_id[target_id].dynamics.speed_mm_s),water) if styled else str(car.driver.intent)=="PREPARE_ATTACK")) and target_gap <= PREPARE_MM:
				_phase(r, "PREPARE", tick, transitions, id, "driver_attack_intent")
			elif tick - int(r.phase_tick) > 180:
				_phase(r, "ABORT", tick, transitions, id, "approach_timeout")
				r.aborts = int(r.aborts) + 1
		elif phase == "PREPARE":
			var wet_mode:bool=car.has(Wet303.KEY) and water>700
			var wet_reason:String=""
			var early:bool=false
			if wet_refinement and wet_mode and styled and by_id.has(target_id):
				early=WetRacecraft3064.window(car,target_gap,speed-int(by_id[target_id].dynamics.speed_mm_s),water)
			if (wet_mode or styled) and by_id.has(target_id) and (target_gap<=INITIATE_MM or early):
				wet_reason=Style305.reason(car,profile,lap_mm,distance,target_gap,speed-int(by_id[target_id].dynamics.speed_mm_s),water) if styled else Wet303.attack_reason(car,Geometry302.radius_at(profile,lap_mm,distance),target_gap,speed-int(by_id[target_id].dynamics.speed_mm_s),water)
				if early:wet_reason=WetRacecraft3064.reason(car,profile,lap_mm,distance,target_gap,speed-int(by_id[target_id].dynamics.speed_mm_s),water)
				if wet_reason=="eligible" and claims.has(target_id):wet_reason="claim"
				if wet_mode:wet_reasons[wet_reason]=int(wet_reasons[wet_reason])+1
			if not by_id.has(target_id) or bool(by_id[target_id].finished) or str(by_id[target_id].pit_stage) != "TRACK" or target_gap < -5000 or target_gap > SEARCH_MM:
				_phase(r, "ABORT", tick, transitions, id, "gap_changed")
				r.aborts = int(r.aborts) + 1
			elif (target_gap <= INITIATE_MM or early) and not claims.has(target_id) and (wet_reason=="eligible" if wet_mode or styled else (_can_pass(profile, lap_mm, distance) and _evolution_commit(car, profile, lap_mm, distance, target_gap,water))):
				var defender: Dictionary = by_id[target_id]
				var defensive_lane: String = "LEFT" if target_id % 2 == 0 else "RIGHT"
				if styled:defensive_lane=Style305.preferred_lane(defender[Style305.KEY],Geometry302.curvature_at(profile,lap_mm,int(defender.dynamics.distance_mm)))
				var incoming_state: Dictionary = proposed.get(target_id, defender.racecraft).duplicate(true)
				var pre_defense:Dictionary=incoming_state.duplicate(true) if styled else {}
				var defense_event_index:int=transitions.size()
				var staged_defense:bool=false
				if not bool(r.get("lapping",false)) and (Style305.defense_allowed(defender,target_gap,speed-int(defender.dynamics.speed_mm_s)) and not bool(incoming_state.defense_used) if styled else str(defender.driver.intent)=="COVER_THREAT") and str(incoming_state.phase) in ["CRUISE", "APPROACH", "RECOVER"] and _lane_allowed(defensive_lane, target_id, int(defender.dynamics.distance_mm), proposed, roster, lap_mm) and (not styled or _future_clear(defensive_lane,defender,proposed,roster,lap_mm)):
					incoming_state.target_id = id
					incoming_state.lane = defensive_lane
					incoming_state.defense_used = true
					_phase(incoming_state, "DEFEND", tick, transitions, target_id, "single_defensive_move")
					proposed[target_id] = incoming_state
					staged_defense=styled
				var first_lane: String = "RIGHT" if str(incoming_state.lane) == "LEFT" else "LEFT"
				if styled and str(incoming_state.lane)=="CENTER":first_lane=Style305.preferred_lane(car[Style305.KEY],Geometry302.curvature_at(profile,lap_mm,distance))
				var second_lane: String = "LEFT" if first_lane == "RIGHT" else "RIGHT"
				var selected: String = ""
				for lane in [first_lane, second_lane]:
					if lane != str(incoming_state.lane) and _lane_allowed(lane, id, distance, proposed, roster, lap_mm) and (not styled or _future_clear(lane,car,proposed,roster,lap_mm)):
						selected = lane
						break
				if not selected.is_empty():
					r.lane = selected
					r.attempts = int(r.attempts) + 1
					claims[target_id] = id
					_phase(r, "ATTACK", tick, transitions, id, "wet_early_clear_corridor" if early else "clear_alternative_corridor")
					if wet_mode:wet_reasons.committed=int(wet_reasons.committed)+1
				else:
					if staged_defense:
						# A defense is committed only with a real attack corridor.
						proposed[target_id]=pre_defense
						transitions.resize(defense_event_index)
					if wet_mode:wet_reasons.lane=int(wet_reasons.lane)+1
			if str(r.phase) == "PREPARE" and tick - int(r.phase_tick) >= 150:
				_phase(r, "ABORT", tick, transitions, id, "no_safe_corridor")
				r.aborts = int(r.aborts) + 1
		elif phase in ["ATTACK", "SIDE_BY_SIDE"]:
			if not by_id.has(target_id) or bool(by_id[target_id].finished) or str(by_id[target_id].pit_stage) != "TRACK" or target_gap < -50000 or target_gap > SEARCH_MM or tick - int(r.phase_tick) > 160:
				_phase(r, "ABORT", tick, transitions, id, "duel_abandoned")
				r.aborts = int(r.aborts) + 1
			elif bool(r.get("lapping",false)) and target_gap < -SIDE_BY_SIDE_MM and str(r.lane)!=str(proposed.get(target_id,by_id[target_id].racecraft).lane):
				_phase(r,"RECOVER",tick,transitions,id,"lapping_completed")
				transitions[-1].type="hyper_lap_pass_confirmed"
				r.cooldown_until=tick+35
			elif phase == "ATTACK" and absi(target_gap) <= SIDE_BY_SIDE_MM:
				_phase(r, "SIDE_BY_SIDE", tick, transitions, id, "longitudinal_overlap")
		if styled and str(r.phase)=="ABORT" and phase!="ABORT":r.cooldown_until=tick+Style305.cooldown(car[Style305.KEY])
		r.last_gap_mm = target_gap if int(r.target_id) >= 0 else -1
	# Index the physical field by lane, including wrapped distances for lapped traffic.
	var lane_groups: Dictionary = {"CENTER": [], "LEFT": [], "RIGHT": []}
	var caps: Dictionary = {}
	var wakes: Dictionary = {}
	var all_physical: Array = []
	var front_gaps: Dictionary = {}
	for id in ids:
		caps[id] = MAX_V_MM_S
		wakes[id] = 65001
		front_gaps[id] = lap_mm
		var car: Dictionary = by_id[id]
		if bool(car.finished) or str(car.pit_stage) != "TRACK": continue
		var entry: Array = [posmod(int(car.dynamics.distance_mm), lap_mm), id, int(car.dynamics.speed_mm_s)]
		lane_groups[str(proposed[id].lane)].append(entry)
		all_physical.append(entry)
	var order := func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]) if int(a[0]) == int(b[0]) else int(a[0]) < int(b[0])
	all_physical.sort_custom(order)
	for i in range(all_physical.size()):
		for ahead in range(1, all_physical.size()):
			var other: Array = all_physical[(i+ahead)%all_physical.size()]
			var gap: int = posmod(int(other[0])-int(all_physical[i][0]),lap_mm)
			if gap > 0:
				front_gaps[int(all_physical[i][1])] = gap
				break
	for lane in LANES:
		var field: Array = lane_groups[lane]
		field.sort_custom(order)
		for i in range(field.size()):
			var id: int = int(field[i][1])
			for ahead in range(1, field.size()):
				var rival: Array = field[(i+ahead)%field.size()]
				var rival_gap: int = posmod(int(rival[0])-int(field[i][0]),lap_mm)
				if rival_gap <= 0: continue
				if rival_gap > 65000: break
				wakes[id] = mini(int(wakes[id]),rival_gap)
				if rival_gap <= FOLLOW_MM:
					var available: int = maxi(0,rival_gap-SAFE_MM)
					caps[id] = mini(int(caps[id]),maxi(0,int(rival[2])+int(available/4)))
	return {"states": proposed, "speed_caps": caps, "transitions": transitions, "wake_gaps": wakes, "physical_front_gaps": front_gaps,"wet_reasons":wet_reasons}

static func _evolution_commit(car: Dictionary, profile: Array, lap_mm: int, distance: int, gap: int,water:int=0) -> bool:
	if bool(car.get("mega_30",{}).get("neutral",false)):return false
	if not car.has("evolution"): return true
	if int(car.evolution.error_left)>0: return false
	var location: int=posmod(distance,lap_mm)
	var radius: int=Geometry302.radius_at(profile,lap_mm,location) if profile[0].has("curvature") else int(profile[Geometry302.index(profile,location)].radius_mm)
	# Late lateral commitment is not allowed in a corner. Existing occupied lanes remain held.
	if car.dynamics.has(Dynamics23.KEY) and not Dynamics23.attack_allowed(car,radius,gap,water): return false
	return radius>=350000 or gap>=14000+int(water/2)
