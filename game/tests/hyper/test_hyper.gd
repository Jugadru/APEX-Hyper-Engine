extends SceneTree
const K = preload("res://experimental/hyper/kernel.gd")
const S = preload("res://experimental/hyper/scenario.gd")
const E = preload("res://experimental/hyper/environment.gd")
const T = preload("res://experimental/hyper/traffic.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scenario: Dictionary = S.create("ITA", "Seco", 1303)
	var k = K.new()
	check(k.initialize(scenario), "initialize 24 cars")
	check(k.state.cars.size() == 24, "24 cars")
	check(E.wake(10000, 1000000).drag < 1000 and E.wake(10000, 1000000).downforce == 1000, "straight slipstream")
	check(E.wake(10000, 50000).downforce < 1000 and E.wake(10000, 50000).drag == 1000, "corner dirty air")
	check(E.wake(100000, 50000).downforce == 1000, "distant wake neutral")
	check(T.wrapped_delta(3000, 4999000, 5000000) == 4000, "wrap across finish line")
	check(not E.valid_weather([{"tick": 4,"water": 7000}]), "invalid weather rejected")
	var id: int = int(k.state.cars[0].id)
	var compound: String = str(k.state.compounds[0])
	check(k.submit({"type":"schedule_pit","source":"Manual","car_id":id,"requested_lap":21,"compound":compound}).accepted, "manual V21 queued")
	check(not k.submit({"type":"order_pit","source":"AI","car_id":id,"compound":compound}).accepted, "AI cannot override pending manual")
	k.step_ticks(50)
	check(int(k.state.cars[0].pit_requested_lap) == 21, "V21 active")
	check(not k.submit({"type":"cancel_pit","source":"AI","car_id":id}).accepted, "AI cannot cancel active manual")
	var cp: Dictionary = k.checkpoint()
	var restored = K.new()
	check(restored.restore(cp), "restore checkpoint")
	k.step_ticks(100)
	for i in range(100): restored.step_tick()
	check(k.sporting_hash() == restored.sporting_hash(), "batch equals single ticks")
	var bad: Dictionary = k.checkpoint()
	bad.state.cars[0].hyper.kers_j = 900000
	check(not restored.restore(bad), "invalid KERS checkpoint rejected")
	# Controlled fixture: two teammates cross pit entry at the same moment.
	var p = K.new()
	var fixture: Dictionary = scenario.duplicate(true)
	fixture.hyper_strategy_auto = false
	fixture.hyper_weather = [{"tick": 2, "water": 5000}]
	check(p.initialize(fixture), "pit fixture init")
	var first: Dictionary = p.state.cars[0]
	var second: Dictionary = {}
	for car in p.state.cars:
		if car.team == first.team and car.id != first.id: second = car; break
	for car in [first,second]:
		car.progress_units = 945000
		car.dynamics.distance_mm = int(int(p.state.lap_length_mm)*945000/1000000)
		car.dynamics.speed_mm_s = 60000
		car.dynamics.wear_micro = 500000
		check(p.submit({"type":"schedule_pit","source":"Manual","car_id":int(car.id),"requested_lap":1,"compound":compound,"allow_double_stack":true}).accepted, "double stack command")
	var max_busy: int = 0
	var queued: bool = false
	for i in range(200):
		p.step_tick()
		var busy: int = 0
		for car in [first,second]:
			if car.pit_stage == "PIT_SERVICE": busy += 1
			if car.pit_stage == "PIT_WAIT": queued = true
		max_busy = maxi(max_busy,busy)
	check(max_busy == 1 and queued, "garage FIFO serializes service")
	check(first.hyper.pit_count == 1 and second.hyper.pit_count == 1, "both services completed")
	check(first.pit_stage == "TRACK" and second.pit_stage == "TRACK", "both return to track")
	check(first.dynamics.wear_micro < 500000 and second.dynamics.wear_micro < 500000, "tires actually replaced")
	check(p.state.water_microns == 5000, "weather schedule applied")
	check(p.classification().size() == 24, "classification roster")
	var snap: Dictionary = p.snapshot(); snap.cars[0].hyper.kers_j = -1
	check(p.state.cars[0].hyper.kers_j >= 0, "snapshot isolated")
	print("HYPER_TEST ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
