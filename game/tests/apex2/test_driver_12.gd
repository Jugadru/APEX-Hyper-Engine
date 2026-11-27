extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Brain = preload("res://experimental/apex2/driver_brain.gd")
const DriverKernel = preload("res://experimental/apex2/driver_kernel_12.gd")
var checks: int = 0
var problems: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		problems.append(label)
		printerr("APEX2_BRAIN12_FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var p: Dictionary = Brain.initial_profile(77, 3)
	check(p == Brain.initial_profile(77, 3), "seeded traits reproducible")
	check(p != Brain.initial_profile(77, 4), "driver ids make distinct traits")
	check(int(p.aggression) >= 300 and int(p.aggression) <= 849, "aggression bounded")
	check(int(p.awareness) >= 380 and int(p.awareness) <= 939, "awareness bounded")
	check(str(p.control_mode) == "AUTO", "driver defaults auto")
	var field: Array = [
		{"id": 3, "finished": false, "progress_units": 200000, "speed_mm_s": 80000, "fuel_g": 50000, "wear_micro": 0, "tire_temp_centi": 8500, "pace": "Normal"},
		{"id": 1, "finished": false, "progress_units": 206000, "speed_mm_s": 65000},
		{"id": 2, "finished": false, "progress_units": 201000, "speed_mm_s": 62000},
		{"id": 4, "finished": false, "progress_units": 195000, "speed_mm_s": 90000}
	]
	var obs: Dictionary = Brain.observe(field[0], field, 21, 77, int(p.awareness))
	check(int(obs.front_id) == 2 and int(obs.front_gap_units) == 1000, "nearest front not array index")
	check(int(obs.behind_id) == 4 and int(obs.behind_gap_units) == 5000, "nearest threat behind")
	check(int(obs.front_relative_mm_s) == 18000, "relative pace observable")
	check(Brain.observe(field[0], field, 21, 77, int(p.awareness)) == obs, "perception deterministic")
	check(absi(int(obs.perceived_front_gap_units) - 1000) <= 900, "subjective error bounded")
	p.aggression = 900; p.risk_tolerance = 850
	var attack: Dictionary = Brain.evaluate(p, obs, 21, 8500)
	check(str(attack.intent) == "PREPARE_ATTACK" and str(attack.pace) == "Atacar", "speed advantage triggers attack preparation")
	check(str(attack.driver.last_observation.reason if attack.driver.last_observation.has("reason") else attack.reason) == "slower_car_ahead", "reason is contextual")
	var patient: Dictionary = p.duplicate(true)
	patient.aggression = 600; patient.risk_tolerance = 600; patient.confidence = 500; patient.patience = 950
	var impatient: Dictionary = patient.duplicate(true); impatient.patience = 100
	check(str(Brain.evaluate(patient, obs, 21, 8500).intent) != "PREPARE_ATTACK", "patient driver avoids marginal attack")
	check(str(Brain.evaluate(impatient, obs, 21, 8500).intent) == "PREPARE_ATTACK", "patience has causal decision cost")
	var manual_high: Dictionary = p.duplicate(true); manual_high.control_mode = "MANUAL"; manual_high.obedience = 900
	var manual_low: Dictionary = manual_high.duplicate(true); manual_low.obedience = 450
	var manual_hot: Dictionary = obs.duplicate(true); manual_hot.fuel_g = 3000; manual_hot.actual_pace = "Atacar"
	check(int(Brain.evaluate(manual_high, manual_hot, 21, 8500).driver.fatigue) < int(Brain.evaluate(manual_low, manual_hot, 21, 8500).driver.fatigue), "obedience reduces stress but never vetoes orders")
	var old_tire: Dictionary = obs.duplicate(true)
	old_tire.wear_micro = 850000
	var conserve: Dictionary = Brain.evaluate(p, old_tire, 21, 8500)
	check(str(conserve.intent) == "PRESERVE" and str(conserve.pace) == "Conservar", "wear forces caution")
	var hot: Dictionary = obs.duplicate(true); hot.tire_temp_centi = 11500
	check(str(Brain.evaluate(p, hot, 21, 8500).reason) == "tire_overheated", "heat changes intent")
	var low_fuel: Dictionary = obs.duplicate(true); low_fuel.fuel_g = 2500
	check(str(Brain.evaluate(p, low_fuel, 21, 8500).reason) == "fuel_low", "fuel changes intent")
	var threat: Dictionary = obs.duplicate(true)
	threat.front_id = -1; threat.front_gap_units = Brain.SENSE_RANGE_UNITS + 1
	threat.perceived_front_gap_units = Brain.SENSE_RANGE_UNITS + 1
	check(str(Brain.evaluate(p, threat, 21, 8500).intent) == "COVER_THREAT", "rear threat detected")
	var tired_profile: Dictionary = p.duplicate(true); tired_profile.fatigue = 900
	var quiet: Dictionary = threat.duplicate(true); quiet.behind_id = -1
	check(str(Brain.evaluate(tired_profile, quiet, 21, 8500).intent) == "RECOVER", "fatigue causes recovery")
	var scenario: Dictionary = Adapter.create_pair("ITA", "Seco", 1202).scenario
	var k = DriverKernel.new()
	check(k.initialize(scenario), "1.2 kernel initialized")
	check(k.state.cars.size() == 24 and str(k.state.driver_model) == DriverKernel.DRIVER_MODEL_TAG, "24 synthetic driver minds installed")
	# Force a reproducible gap/relative-speed fixture. It is not a complete racecraft simulation.
	var car: Dictionary = k.state.cars[0]
	var ahead: Dictionary = k.state.cars[1]
	car.progress_units = 20000; ahead.progress_units = 24000
	car.dynamics.distance_mm = int(int(car.progress_units) * int(k.state.lap_length_mm) / DriverKernel.LAP_UNITS)
	ahead.dynamics.distance_mm = int(int(ahead.progress_units) * int(k.state.lap_length_mm) / DriverKernel.LAP_UNITS)
	car.dynamics.speed_mm_s = 95000; ahead.dynamics.speed_mm_s = 70000
	car.driver.aggression = 850; car.driver.risk_tolerance = 850
	check(k.step_tick(), "brain decision tick")
	check(int(car.driver.last_decision_tick) == 1 and int(k.state.brain_last_cycle_tick) == 1, "observation cadence started")
	check(str(car.driver.intent) == "PREPARE_ATTACK", "kernel attack intent follows observation")
	var pending: bool = false
	for r in k.queue.records:
		if int(r.car_id) == int(car.id) and str(r.type) == "set_pace" and str(r.source) == "AI" and str(r.status) == "PENDING": pending = true
	check(pending, "AI request passed via deterministic queue")
	check(str(car.pace) == "Normal", "AI intent is not applied until due tick")
	check(k.step_tick(), "execute scheduled brain command")
	check(str(car.pace) == "Atacar", "queue applies AI pace")
	var manual: Dictionary = {"type":"set_pace", "source":"Manual", "car_id":int(car.id), "pace":"Conservar"}
	check(bool(k.submit(manual).accepted), "manual pace validated via queue")
	check(k.step_tick(), "manual pace executed")
	check(str(car.driver.control_mode) == "MANUAL" and str(car.pace) == "Conservar", "manual control persists")
	var ai: Dictionary = {"type":"set_pace", "source":"AI", "car_id":int(car.id), "pace":"Atacar"}
	check(bool(k.submit(ai).accepted), "AI command can be recorded for later rejection")
	check(k.step_tick(), "AI attempted manual override")
	check(str(car.pace) == "Conservar", "manual control prevents AI override")
	var rejected: bool = false
	for r in k.queue.records:
		if str(r.reason) == "manual_pace_protected": rejected = true
	check(rejected, "manual protection reason auditable")
	var another_manual: Dictionary = {"type":"set_pace", "source":"Manual", "car_id":int(car.id), "pace":"Normal"}
	check(bool(k.submit(another_manual).accepted), "manual can revise own pace")
	check(k.step_tick() and str(car.pace) == "Normal", "new manual pace confirmed")
	var simultaneous = DriverKernel.new()
	check(simultaneous.initialize(scenario), "simultaneous orders initialized")
	var other_id: int = int(simultaneous.state.cars[0].id)
	var both_tick: int = int(simultaneous.state.tick) + 1
	check(bool(simultaneous.submit({"type":"set_pace", "source":"AI", "car_id":other_id, "pace":"Atacar", "at_tick":both_tick}).accepted), "AI scheduled alongside manual")
	check(bool(simultaneous.submit({"type":"set_pace", "source":"Manual", "car_id":other_id, "pace":"Conservar", "at_tick":both_tick}).accepted), "manual accepted on same tick")
	check(simultaneous.step_tick(), "simultaneous due tick advanced")
	check(str(simultaneous.state.cars[0].pace) == "Conservar" and str(simultaneous.state.cars[0].driver.control_mode) == "MANUAL", "manual priority wins same tick")
	var simultaneous_rejected: bool = false
	for record in simultaneous.queue.records:
		if str(record.source) == "AI" and str(record.status) == "REJECTED" and str(record.reason) == "manual_pace_protected": simultaneous_rejected = true
	check(simultaneous_rejected, "same-tick AI rejection auditable")
	var copy: Dictionary = k.snapshot()
	var checkpoint: Dictionary = k.checkpoint()
	var viewer = DriverKernel.new()
	check(viewer.restore(checkpoint), "1.2 checkpoint loads")
	check(viewer.sporting_hash() == k.sporting_hash(), "1.2 checkpoint hash")
	check(viewer.step_ticks(45) == 45 and k.step_ticks(45) == 45, "resume after checkpoint")
	check(viewer.sporting_hash() == k.sporting_hash(), "resume hash identical")
	check(viewer.snapshot() != copy and bool(copy.cars[0].driver.control_mode == "MANUAL"), "deep copy independent")
	var bad: Dictionary = k.checkpoint(); bad.state.cars[0].driver.confidence = 1100
	var before_hash: String = k.sporting_hash()
	check(not k.restore(bad), "corrupt driver confidence rejected")
	check(k.sporting_hash() == before_hash, "invalid restore transactional")
	var ok: bool = problems.is_empty()
	print("APEX2_DRIVER_12_%s checks=%d problems=%s" % ["PASS" if ok else "FAIL", checks, str(problems)])
	quit(0 if ok else 1)
