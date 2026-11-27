extends "res://experimental/apex2/vehicle_kernel_11.gd"
## Driver Brain 1.2 adds observation -> intent -> validated future-tick pace orders.
## Racecraft, pit physics and the official Core 2 game remain untouched.
const Brain = preload("res://experimental/apex2/driver_brain.gd")
const VehicleSpec = preload("res://experimental/apex2/vehicle_dynamics.gd")
const DRIVER_MODEL_TAG: String = "APEX2_DRIVER_BRAIN_1.2_INTENT_ONLY"
const DECISION_TICKS: int = 20 # 4 seconds of sporting time.

func initialize(scenario: Dictionary) -> bool:
	if not super.initialize(scenario):
		return false
	state["driver_model"] = DRIVER_MODEL_TAG
	state["brain_last_cycle_tick"] = -1
	for car in state.cars:
		car["driver"] = Brain.initial_profile(int(state.seed), int(car.id))
	return true

func _apply_command(command: Dictionary) -> Dictionary:
	var car: Dictionary = _lookup_car(int(command.car_id))
	if str(command.type) == "set_pace" and str(command.source) == "AI" and not car.is_empty() and str(car.get("driver", {}).get("control_mode", "")) == "MANUAL":
		return {"ok": false, "reason": "manual_pace_protected"}
	var result: Dictionary = super._apply_command(command)
	if bool(result.ok) and str(command.type) == "set_pace" and str(command.source) == "Manual" and not car.is_empty():
		car.driver.control_mode = "MANUAL"
		car.driver.desired_pace = str(command.pace)
		_event("driver_manual_pace_confirmed", int(car.id), {"pace": str(command.pace)})
	return result

func _evaluate_grid() -> void:
	# Construct every observation from the same pre-movement tick state.
	var field: Array = []
	for car in state.cars:
		field.append({
			"id": int(car.id), "finished": bool(car.finished),
			"progress_units": int(car.progress_units),
			"speed_mm_s": int(car.dynamics.speed_mm_s),
			"fuel_g": int(car.dynamics.fuel_g),
			"wear_micro": int(car.dynamics.wear_micro),
			"tire_temp_centi": int(car.dynamics.tire_temp_centi),
			"pace": str(car.pace)
		})
	for index in range(state.cars.size()):
		var car: Dictionary = state.cars[index]
		if bool(car.finished):
			continue
		var profile: Dictionary = car.driver
		var measured: Dictionary = Brain.observe(field[index], field, int(state.tick), int(state.seed), int(profile.awareness))
		var compound: Dictionary = VehicleSpec.TYRES.get(str(car.tire), VehicleSpec.TYRES["Médio"])
		var plan: Dictionary = Brain.evaluate(profile, measured, int(state.tick), int(compound.optimal_centi))
		car.driver = plan.driver
		if bool(plan.changed):
			_event("driver_intent_changed", int(car.id), {"intent": str(plan.intent), "reason": str(plan.reason)})
		if str(car.driver.control_mode) == "AUTO" and str(plan.pace) != str(car.pace):
			# The brain is a decision service; the queue owns authorization and ordering.
			var request: Dictionary = {"type": "set_pace", "source": "AI", "car_id": int(car.id), "pace": str(plan.pace), "at_tick": int(state.tick) + 1}
			var outcome: Dictionary = queue.submit(request, state)
			if not bool(outcome.accepted):
				_event("driver_intent_rejected", int(car.id), {"reason": str(outcome.reason)})
	state.brain_last_cycle_tick = int(state.tick)

func _advance_reference_car(car: Dictionary, previous: int) -> void:
	if (int(state.tick) - 1) % DECISION_TICKS == 0 and int(state.brain_last_cycle_tick) != int(state.tick):
		_evaluate_grid()
	super._advance_reference_car(car, previous)

func restore(data: Dictionary) -> bool:
	if not data.get("state", null) is Dictionary:
		return false
	var candidate: Dictionary = data.state
	if str(candidate.get("driver_model", "")) != DRIVER_MODEL_TAG:
		return false
	var last_cycle: int = int(candidate.get("brain_last_cycle_tick", -2))
	if last_cycle < -1 or last_cycle > int(candidate.get("tick", -1)):
		return false
	for car in candidate.get("cars", []):
		if not car is Dictionary or not car.get("driver", null) is Dictionary:
			return false
		var driver: Dictionary = car.driver
		if not driver.has_all(["schema", "control_mode", "aggression", "patience", "awareness", "risk_tolerance", "obedience", "confidence", "fatigue", "intent", "reason", "desired_pace", "last_decision_tick", "last_target_id", "last_gap_units", "last_observation"]):
			return false
		if int(driver.schema) != Brain.SCHEMA or str(driver.control_mode) not in ["AUTO", "MANUAL"]:
			return false
		if str(driver.desired_pace) not in ["Normal", "Atacar", "Conservar"]:
			return false
		if str(driver.intent) not in ["HOLD", "PREPARE_ATTACK", "COVER_THREAT", "PRESERVE", "RECOVER"]:
			return false
		for field in ["aggression", "patience", "awareness", "risk_tolerance", "obedience", "confidence", "fatigue"]:
			if typeof(driver[field]) != TYPE_INT or int(driver[field]) < 0 or int(driver[field]) > 1000:
				return false
		if int(driver.last_decision_tick) < -1 or int(driver.last_decision_tick) > int(candidate.tick):
			return false
		if not driver.last_observation is Dictionary:
			return false
		if int(driver.last_decision_tick) >= 0 and not driver.last_observation.has_all(["front_id", "behind_id", "front_gap_units", "behind_gap_units", "perceived_front_gap_units", "front_relative_mm_s", "behind_relative_mm_s", "fuel_g", "wear_micro", "tire_temp_centi", "actual_pace", "tick"]):
			return false
	return super.restore(data)
