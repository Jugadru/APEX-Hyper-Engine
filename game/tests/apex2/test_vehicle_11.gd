extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Vehicle = preload("res://experimental/apex2/vehicle_dynamics.gd")
const Kernel = preload("res://experimental/apex2/vehicle_kernel_11.gd")
var count: int = 0
var problems: Array[String] = []
func check(value: bool, description: String) -> void:
	count += 1
	if not value:
		problems.append(description)
		printerr("VEHICLE_11_FAIL ", description)
func _initialize() -> void: call_deferred("run")
func get_car(k) -> Dictionary: return k.state.cars[0]
func run() -> void:
	check(Vehicle.integer_sqrt(0) == 0 and Vehicle.integer_sqrt(81) == 9 and Vehicle.integer_sqrt(80) == 8, "integer sqrt exact")
	check(Vehicle.track_profile([], 5000000).is_empty(), "reject invalid geometry")
	var scenario: Dictionary = Adapter.create_pair("ITA", "Seco", 10101).scenario
	check(scenario.cars.size() == 24, "2012 roster")
	var profile: Array = Vehicle.track_profile(scenario.geometry_points, int(scenario.lap_length_mm))
	check(profile.size() > 30, "geometry profiles available")
	var monotonic: bool = true
	for i in range(1, profile.size()):
		if int(profile[i].start_mm) <= int(profile[i-1].start_mm): monotonic = false
	check(monotonic, "strictly increasing segment starts")
	check(Vehicle.friction_mu("Macio", 0, 9500, 0) > Vehicle.friction_mu("Macio", 6000, 9500, 0), "slick wet penalty")
	check(Vehicle.friction_mu("Chuva", 6000, 6800, 0) > Vehicle.friction_mu("Chuva", 0, 6800, 0), "wet tyre water operating range")
	check(Vehicle.friction_mu("Macio", 0, 9500, 0) > Vehicle.friction_mu("Macio", 0, 9500, 800000), "wear reduces adhesion")
	check(Vehicle.friction_mu("Macio", 0, 9500, 0) > Vehicle.friction_mu("Macio", 0, 2000, 0), "cold tyre reduces adhesion")
	var start = Kernel.new()
	check(start.initialize(scenario), "Vehicle Kernel initializes independently")
	check(str(start.state.vehicle_model) == Kernel.MODEL_TAG and start.state.cars.size() == 24, "vehicle state installed in each car")
	var initial: Dictionary = start.snapshot()
	check(start.step_ticks(400) == 400, "advance 400 ticks")
	var after: Dictionary = start.snapshot()
	check(int(after.cars[0].dynamics.speed_mm_s) > 0, "power accelerates car")
	check(int(after.cars[0].dynamics.fuel_g) < int(initial.cars[0].dynamics.fuel_g), "fuel consumed")
	check(int(after.cars[0].dynamics.wear_micro) > 0, "tire wears with distance")
	check(int(after.cars[0].progress_units) > int(initial.cars[0].progress_units), "progress follows physical distance")
	check(int(after.cars[0].dynamics.speed_mm_s) <= Vehicle.MAX_V_MM_S, "velocity capped")
	var isolated: Dictionary = start.snapshot()
	isolated.cars[0].dynamics.fuel_g = 0
	check(start.snapshot() == after, "snapshot does not mutate sport")
	var restored = Kernel.new()
	check(restored.restore(start.checkpoint()), "checkpoint restore")
	check(restored.sporting_hash() == start.sporting_hash(), "checkpoint hash")
	check(restored.step_ticks(100) == 100 and start.step_ticks(100) == 100, "post restore tick parity")
	check(restored.sporting_hash() == start.sporting_hash(), "post restore deterministic")
	var fake: Dictionary = start.checkpoint()
	fake.state.cars[0].dynamics.speed_mm_s = -10
	var prior: String = restored.sporting_hash()
	check(not restored.restore(fake), "reject invalid physical speed")
	check(restored.sporting_hash() == prior, "invalid restore transactional")
	var dry: Dictionary = Adapter.create_pair("GBR", "Seco", 2700).scenario
	var wet: Dictionary = Adapter.create_pair("GBR", "Chuva intensa", 2700).scenario
	var d = Kernel.new(); var w = Kernel.new()
	check(d.initialize(dry) and w.initialize(wet), "dry and wet initialization")
	check(int(w.state.water_microns) > int(d.state.water_microns), "observed weather transferred")
	d.step_ticks(700); w.step_ticks(700)
	check(int(d.state.cars[0].progress_units) > int(w.state.cars[0].progress_units), "wet weather slows car on same circuit")
	# Isolate aero/traction hypotheses, same initial state and physical input.
	var less_drag = Kernel.new(); var more_drag = Kernel.new()
	check(less_drag.initialize(dry) and more_drag.initialize(dry), "drag comparison initialized")
	for c in more_drag.state.cars: c.dynamics.drag_milli = 2100
	less_drag.step_ticks(600); more_drag.step_ticks(600)
	check(int(less_drag.state.cars[0].progress_units) > int(more_drag.state.cars[0].progress_units), "drag has causal cost")
	var less_power = Kernel.new(); var more_power = Kernel.new()
	check(less_power.initialize(dry) and more_power.initialize(dry), "power comparison initialized")
	for c in less_power.state.cars: c.dynamics.wheel_power_w = 85000
	less_power.step_ticks(600); more_power.step_ticks(600)
	check(int(more_power.state.cars[0].progress_units) > int(less_power.state.cars[0].progress_units), "power affects progress")
	var good: bool = problems.is_empty()
	print("APEX2_VEHICLE_11_%s checks=%d problems=%s hash=%s" % ["PASS" if good else "FAIL", count, str(problems), start.sporting_hash()])
	quit(0 if good else 1)
