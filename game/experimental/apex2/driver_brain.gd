extends RefCounted
## APEX 2 / Driver Brain 1.2 — deterministic tactical intent service.
## The brain observes a bounded sporting snapshot, not rendering state.
## It does NOT resolve overtakes, lateral positioning, collisions or pit service.
const SCHEMA: int = 12
const ATTACK_GAP_UNITS: int = 16000
const DEFEND_GAP_UNITS: int = 12000
const SENSE_RANGE_UNITS: int = 60000

static func _fingerprint(seed: int, id: int, salt: int) -> int:
	# Integer-only reproducible local profile: no consumption of the Core 2 RNG.
	var v: int = (seed & 0x7fffffff) ^ ((id + 29) * 13007) ^ (salt * 8191)
	v = (v * 1103515245 + 12345) & 0x7fffffff
	return v

static func initial_profile(seed: int, car_id: int) -> Dictionary:
	return {
		"schema": SCHEMA,
		"control_mode": "AUTO",
		"aggression": 300 + _fingerprint(seed, car_id, 1) % 550,
		"patience": 250 + _fingerprint(seed, car_id, 2) % 600,
		"awareness": 380 + _fingerprint(seed, car_id, 3) % 560,
		"risk_tolerance": 280 + _fingerprint(seed, car_id, 4) % 570,
		"obedience": 450 + _fingerprint(seed, car_id, 5) % 490,
		"confidence": 500,
		"fatigue": 0,
		"intent": "HOLD",
		"reason": "initial",
		"desired_pace": "Normal",
		"last_decision_tick": -1,
		"last_target_id": -1,
		"last_gap_units": -1,
		"last_observation": {}
	}

static func observe(car: Dictionary, field: Array, tick: int, seed: int, awareness: int) -> Dictionary:
	# The car roster is a stable pre-movement snapshot, never sorted by a camera.
	var progress: int = int(car.progress_units)
	var own_speed: int = int(car.speed_mm_s)
	var front_id: int = -1
	var behind_id: int = -1
	var gap_front: int = SENSE_RANGE_UNITS + 1
	var gap_behind: int = SENSE_RANGE_UNITS + 1
	var front_speed: int = own_speed
	var behind_speed: int = own_speed
	for opponent in field:
		if int(opponent.id) == int(car.id) or bool(opponent.finished):
			continue
		var difference: int = int(opponent.progress_units) - progress
		if difference > 0 and difference <= SENSE_RANGE_UNITS and difference < gap_front:
			front_id = int(opponent.id)
			gap_front = difference
			front_speed = int(opponent.speed_mm_s)
		elif difference < 0 and -difference <= SENSE_RANGE_UNITS and -difference < gap_behind:
			behind_id = int(opponent.id)
			gap_behind = -difference
			behind_speed = int(opponent.speed_mm_s)
	# Perception error decreases with awareness and changes only at decision cadence.
	var error_range: int = maxi(0, int((1000 - awareness) * 900 / 1000))
	var error: int = _fingerprint(seed, int(car.id), 7 + tick) % (2 * error_range + 1) - error_range
	return {
		"front_id": front_id,
		"behind_id": behind_id,
		"front_gap_units": gap_front,
		"behind_gap_units": gap_behind,
		"perceived_front_gap_units": maxi(0, gap_front + error) if front_id >= 0 else gap_front,
		"front_relative_mm_s": own_speed - front_speed,
		"behind_relative_mm_s": behind_speed - own_speed,
		"fuel_g": int(car.fuel_g),
		"wear_micro": int(car.wear_micro),
		"tire_temp_centi": int(car.tire_temp_centi),
		"actual_pace": str(car.get("pace", "Normal")),
		"tick": tick
	}

static func evaluate(brain: Dictionary, observation: Dictionary, tick: int, optimal_temp_centi: int) -> Dictionary:
	var next: Dictionary = brain.duplicate(true)
	var prior_intent: String = str(brain.intent)
	var prior_pace: String = str(brain.desired_pace)
	var confidence: int = int(next.confidence)
	var front_id: int = int(observation.front_id)
	var actual_gap: int = int(observation.front_gap_units)
	if front_id >= 0 and front_id == int(brain.last_target_id) and int(brain.last_gap_units) >= 0:
		# Confidence follows observable progress against the same opponent.
		confidence += 3 if actual_gap < int(brain.last_gap_units) else -2
	var tired: int = int(next.fatigue)
	var old_tire: bool = int(observation.wear_micro) >= 700000
	var overheated: bool = int(observation.tire_temp_centi) >= optimal_temp_centi + 2200
	var low_fuel: bool = int(observation.fuel_g) <= 8000
	var intent: String = "HOLD"
	var reason: String = "stable_running"
	var pace: String = "Normal"
	if low_fuel or old_tire or overheated:
		intent = "PRESERVE"
		reason = "fuel_low" if low_fuel else ("tire_worn" if old_tire else "tire_overheated")
		pace = "Conservar"
	elif front_id >= 0 and int(observation.perceived_front_gap_units) <= ATTACK_GAP_UNITS and int(observation.front_relative_mm_s) >= 1300 and confidence + int(next.aggression) + int(next.risk_tolerance) >= 1370 + int(next.patience / 2) and tired < 800:
		intent = "PREPARE_ATTACK"
		reason = "slower_car_ahead"
		pace = "Atacar"
	elif int(observation.behind_id) >= 0 and int(observation.behind_gap_units) <= DEFEND_GAP_UNITS and int(observation.behind_relative_mm_s) >= 1400 and int(next.awareness) + int(next.risk_tolerance) >= 1000 and tired < 850:
		intent = "COVER_THREAT"
		reason = "faster_car_behind"
		pace = "Atacar"
	elif tired >= 850:
		intent = "RECOVER"
		reason = "driver_fatigue"
		pace = "Conservar"
	# An accepted manual order always takes sporting precedence. Lower obedience
	# raises cognitive load when an aggressive manual instruction conflicts with
	# the driver's own conservation assessment; it NEVER vetoes that command.
	var effective_pace: String = str(observation.get("actual_pace", "Normal")) if str(next.control_mode) == "MANUAL" else pace
	if effective_pace == "Atacar":
		tired = mini(1000, tired + 8)
	elif effective_pace == "Conservar":
		tired = maxi(0, tired - 6)
	else:
		tired = maxi(0, tired - 2)
	if str(next.control_mode) == "MANUAL" and effective_pace == "Atacar" and pace == "Conservar":
		var stress: int = 1 + int((1000 - int(next.obedience)) / 180)
		tired = mini(1000, tired + stress)
		confidence -= stress
	next.confidence = clampi(confidence, 150, 950)
	next.fatigue = tired
	next.intent = intent
	next.reason = reason
	next.desired_pace = pace
	next.last_target_id = front_id
	next.last_gap_units = actual_gap if front_id >= 0 else -1
	next.last_decision_tick = tick
	next.last_observation = observation.duplicate(true)
	return {"driver": next, "changed": intent != prior_intent or pace != prior_pace, "pace": pace, "reason": reason, "intent": intent}
