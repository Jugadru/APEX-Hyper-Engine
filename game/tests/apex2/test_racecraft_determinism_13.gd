extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Kernel = preload("res://experimental/apex2/racecraft_kernel_13.gd")
var checks: int = 0
var problems: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		problems.append(label)
		printerr("APEX2_RACECRAFT_DET13_FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for entry in [{"code":"GBR", "weather":"Seco"}, {"code":"BEL", "weather":"Chuva intensa"}, {"code":"ITA", "weather":"Seco"}, {"code":"SIN", "weather":"Chuva intensa"}]:
		var scenario: Dictionary = Adapter.create_pair(entry.code, entry.weather, 1303).scenario
		var scalar = Kernel.new()
		var batch = Kernel.new()
		check(scalar.initialize(scenario) and batch.initialize(scenario), "%s initialized" % entry.code)
		check(batch.step_ticks(240) == 240, "%s batch" % entry.code)
		var advanced: bool = true
		for t in range(240):
			if not scalar.step_tick():
				advanced = false
				break
		check(advanced, "%s scalar" % entry.code)
		check(scalar.sporting_hash() == batch.sporting_hash(), "%s tick grouping same hash" % entry.code)
		check(scalar.state.events == batch.state.events, "%s stable event ordering" % entry.code)
		var initial_hash: String = batch.sporting_hash()
		var cp: Dictionary = batch.checkpoint()
		var restored = Kernel.new()
		check(restored.restore(cp), "%s checkpoint restore" % entry.code)
		check(restored.sporting_hash() == initial_hash, "%s checkpoint hash" % entry.code)
		check(restored.step_ticks(120) == 120 and batch.step_ticks(120) == 120, "%s resumed ticks" % entry.code)
		check(restored.sporting_hash() == batch.sporting_hash(), "%s resumed hash" % entry.code)
		var original: Dictionary = batch.snapshot()
		var replay = Kernel.new()
		check(replay.restore(cp) and replay.step_ticks(90) == 90, "%s independent replay" % entry.code)
		check(original == batch.snapshot(), "%s replay does not mutate live engine" % entry.code)
		var last_event_id: int = 0
		var event_ok: bool = true
		for event in batch.state.events:
			if int(event.id) <= last_event_id or int(event.tick) > int(batch.state.tick):
				event_ok = false
				break
			last_event_id = int(event.id)
		check(event_ok, "%s events are monotone and in simulation time" % entry.code)
		print("APEX2_RACECRAFT_13_DET_HASH ", entry.code, " tick=", int(batch.state.tick), " hash=", batch.sporting_hash())
	var wet: Dictionary = Adapter.create_pair("BEL", "Chuva intensa", 1303).scenario
	var pit = Kernel.new()
	check(pit.initialize(wet), "manual regression initialized")
	var car_id: int = int(pit.state.cars[0].id)
	var compound: String = str(wet.compounds[-1])
	check(bool(pit.submit({"type":"schedule_pit", "source":"Manual", "car_id":car_id, "requested_lap":21, "compound":compound}).accepted), "manual stop V21 submitted")
	check(not bool(pit.submit({"type":"order_pit", "source":"AI", "car_id":car_id, "compound":compound}).accepted), "AI order does not preempt manual V21")
	check(pit.step_ticks(500) == 500, "wet race elapsed")
	check(int(pit.state.cars[0].pit_requested_lap) == 21 and int(pit.state.cars[0].pit_entry_tick) == -1, "V21 order held and not triggered early")
	var ok: bool = problems.is_empty()
	print("APEX2_RACECRAFT_DETERMINISM_13_%s checks=%d problems=%s" % ["PASS" if ok else "FAIL", checks, str(problems)])
	quit(0 if ok else 1)
