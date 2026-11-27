extends RefCounted
## APEX 2 / Racecraft Resolver 1.3: experimental, deterministic encounter service.
## Inputs: immutable-in-practice pre-tick longitudinal roster + persistent duel states.
## Output: desired lanes, finite-speed following constraints and ordered transitions.
## No direct progress/position edits; overtakes require actual longitudinal crossing.
## Lane/corner capacity is a synthetic corridor abstraction, NOT surveyed geometry.
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

static func _lane_allowed(lane: String, car_id: int, distance_mm: int, proposed: Dictionary, roster: Array) -> bool:
	for opponent in roster:
		var other_id: int = int(opponent.id)
		if other_id == car_id or bool(opponent.finished):
			continue
		if absi(int(opponent.dynamics.distance_mm) - distance_mm) > LANE_CLEAR_MM:
			continue
		var other_state: Dictionary = proposed.get(other_id, opponent.racecraft)
		if str(other_state.lane) == lane:
			return false
	return true

static func _can_pass(profile: Array, lap_mm: int, distance_mm: int) -> bool:
	if profile.is_empty() or lap_mm <= 0:
		return false
	var location: int = posmod(distance_mm, lap_mm)
	var idx: int = 0
	for j in range(profile.size()):
		if int(profile[j].start_mm) <= location:
			idx = j
		else:
			break
	return int(profile[idx].radius_mm) >= CORNER_PASS_MIN_RADIUS_MM

static func plan(roster: Array, profile: Array, lap_mm: int, tick: int) -> Dictionary:
	## No writes to the supplied roster. Loop order is by stable car id.
	var by_id: Dictionary = {}
	var ids: Array[int] = []
	for car in roster:
		by_id[int(car.id)] = car
		ids.append(int(car.id))
	ids.sort()
	var proposed: Dictionary = {}
	var transitions: Array = []
	var claims: Dictionary = {}
	for id in ids:
		var car: Dictionary = by_id[id]
		var r: Dictionary = proposed.get(id, car.racecraft).duplicate(true)
		proposed[id] = r
		if bool(car.finished):
			continue
		var distance: int = int(car.dynamics.distance_mm)
		var speed: int = int(car.dynamics.speed_mm_s)
		var front_id: int = -1
		var gap: int = SEARCH_MM + 1
		for candidate_id in ids:
			if candidate_id == id:
				continue
			var other: Dictionary = by_id[candidate_id]
			if bool(other.finished) or str(other.pit_stage) != "TRACK":
				continue
			var difference: int = int(other.dynamics.distance_mm) - distance
			if difference > 0 and difference < gap:
				gap = difference
				front_id = candidate_id
		var phase: String = str(r.phase)
		var target_id: int = int(r.target_id)
		var target_gap: int = -1
		if by_id.has(target_id):
			target_gap = int(by_id[target_id].dynamics.distance_mm) - distance
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
			elif phase == "RECOVER" and tick - int(r.phase_tick) >= 8:
				_phase(r, "CRUISE", tick, transitions, id, "lane_restored")
				r.target_id = -1
				r.defense_used = false
				r.lane = "CENTER"
		elif phase == "CRUISE":
			if tick >= int(r.cooldown_until) and front_id >= 0 and gap < SEARCH_MM and speed - int(by_id[front_id].dynamics.speed_mm_s) >= 1700:
				r.target_id = front_id
				_phase(r, "APPROACH", tick, transitions, id, "closing_on_slower_car")
		elif phase == "APPROACH":
			if front_id != target_id or target_gap < 0 or target_gap > SEARCH_MM:
				_phase(r, "ABORT", tick, transitions, id, "opportunity_lost")
				r.aborts = int(r.aborts) + 1
			elif str(car.driver.intent) == "PREPARE_ATTACK" and target_gap <= PREPARE_MM:
				_phase(r, "PREPARE", tick, transitions, id, "driver_attack_intent")
			elif tick - int(r.phase_tick) > 180:
				_phase(r, "ABORT", tick, transitions, id, "approach_timeout")
				r.aborts = int(r.aborts) + 1
		elif phase == "PREPARE":
			if target_gap < -5000 or target_gap > SEARCH_MM:
				_phase(r, "ABORT", tick, transitions, id, "gap_changed")
				r.aborts = int(r.aborts) + 1
			elif target_gap <= INITIATE_MM and _can_pass(profile, lap_mm, distance) and not claims.has(target_id):
				var defender: Dictionary = by_id[target_id]
				var defensive_lane: String = "LEFT" if target_id % 2 == 0 else "RIGHT"
				var incoming_state: Dictionary = proposed.get(target_id, defender.racecraft).duplicate(true)
				if str(defender.driver.intent) == "COVER_THREAT" and str(incoming_state.phase) in ["CRUISE", "APPROACH", "RECOVER"] and _lane_allowed(defensive_lane, target_id, int(defender.dynamics.distance_mm), proposed, roster):
					incoming_state.target_id = id
					incoming_state.lane = defensive_lane
					incoming_state.defense_used = true
					_phase(incoming_state, "DEFEND", tick, transitions, target_id, "single_defensive_move")
					proposed[target_id] = incoming_state
				var first_lane: String = "RIGHT" if str(incoming_state.lane) == "LEFT" else "LEFT"
				var second_lane: String = "LEFT" if first_lane == "RIGHT" else "RIGHT"
				var selected: String = ""
				for lane in [first_lane, second_lane]:
					if lane != str(incoming_state.lane) and _lane_allowed(lane, id, distance, proposed, roster):
						selected = lane
						break
				if not selected.is_empty():
					r.lane = selected
					r.attempts = int(r.attempts) + 1
					claims[target_id] = id
					_phase(r, "ATTACK", tick, transitions, id, "clear_alternative_corridor")
			elif tick - int(r.phase_tick) >= 150:
				_phase(r, "ABORT", tick, transitions, id, "no_safe_corridor")
				r.aborts = int(r.aborts) + 1
		elif phase in ["ATTACK", "SIDE_BY_SIDE"]:
			if target_gap < -50000 or target_gap > SEARCH_MM or tick - int(r.phase_tick) > 160:
				_phase(r, "ABORT", tick, transitions, id, "duel_abandoned")
				r.aborts = int(r.aborts) + 1
			elif phase == "ATTACK" and absi(target_gap) <= SIDE_BY_SIDE_MM:
				_phase(r, "SIDE_BY_SIDE", tick, transitions, id, "longitudinal_overlap")
		r.last_gap_mm = target_gap if int(r.target_id) >= 0 else -1
	# Evaluate each car's following envelope using the newly agreed lanes.
	var caps: Dictionary = {}
	for id in ids:
		var car: Dictionary = by_id[id]
		var cap: int = MAX_V_MM_S
		if bool(car.finished):
			caps[id] = cap
			continue
		var own_distance: int = int(car.dynamics.distance_mm)
		for rival_id in ids:
			if rival_id == id:
				continue
			var rival: Dictionary = by_id[rival_id]
			if bool(rival.finished) or str(rival.pit_stage) != "TRACK":
				continue
			var rival_gap: int = int(rival.dynamics.distance_mm) - own_distance
			if rival_gap <= 0 or rival_gap > FOLLOW_MM:
				continue
			if str(proposed[id].lane) != str(proposed[rival_id].lane):
				continue
			# Physically bounded brake target is consumed by Vehicle Dynamics.
			# No artificial position swap or extra power is introduced.
			var available: int = maxi(0, rival_gap - SAFE_MM)
			cap = mini(cap, maxi(0, int(rival.dynamics.speed_mm_s) + int(available / 4)))
		caps[id] = cap
	return {"states": proposed, "speed_caps": caps, "transitions": transitions}
