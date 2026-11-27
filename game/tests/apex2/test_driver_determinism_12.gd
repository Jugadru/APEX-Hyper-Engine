extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const DriverKernel = preload("res://experimental/apex2/driver_kernel_12.gd")
var checks: int = 0
var problems: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		problems.append(label)
		printerr("APEX2_DRIVER_DET12_FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for row in [{"track":"GBR", "weather":"Seco"}, {"track":"BEL", "weather":"Chuva intensa"}, {"track":"ITA", "weather":"Seco"}, {"track":"SIN", "weather":"Chuva intensa"}]:
		var scenario: Dictionary = Adapter.create_pair(row.track, row.weather, 1202).scenario
		var batch = DriverKernel.new(); var scalar = DriverKernel.new()
		check(batch.initialize(scenario) and scalar.initialize(scenario), "%s initialized" % row.track)
		check(batch.step_ticks(320) == 320, "%s batch ticks" % row.track)
		var all_ok: bool = true
		for t in range(320):
			if not scalar.step_tick(): all_ok = false; break
		check(all_ok, "%s scalar ticks" % row.track)
		check(batch.sporting_hash() == scalar.sporting_hash(), "%s scalar batch hash" % row.track)
		check(batch.state.events == scalar.state.events, "%s event ordering" % row.track)
		var frozen: Dictionary = batch.snapshot()
		var cp: Dictionary = batch.checkpoint()
		var rest = DriverKernel.new()
		check(rest.restore(cp), "%s checkpoint restore" % row.track)
		check(rest.sporting_hash() == batch.sporting_hash(), "%s restored hash" % row.track)
		check(batch.step_ticks(120) == 120 and rest.step_ticks(120) == 120, "%s deterministic continuation" % row.track)
		check(batch.sporting_hash() == rest.sporting_hash(), "%s continuation hashes" % row.track)
		var protected_snapshot: Dictionary = batch.snapshot()
		var spectator = DriverKernel.new()
		check(spectator.restore(cp) and spectator.step_ticks(40) == 40, "%s independent replay" % row.track)
		check(protected_snapshot == batch.snapshot(), "%s replay must not mutate original race" % row.track)
		check(frozen != batch.snapshot() and spectator.sporting_hash() != batch.sporting_hash(), "%s replay separate sporting time" % row.track)
		print("APEX2_DRIVER_12_HASH ", row.track, " tick=", batch.state.tick, " hash=", batch.sporting_hash())
	var wet: Dictionary = Adapter.create_pair("BEL", "Chuva intensa", 1202).scenario
	var v21 = DriverKernel.new()
	check(v21.initialize(wet), "Spa V21 initialized")
	var car_id: int = int(v21.state.cars[0].id)
	check(bool(v21.submit({"type":"schedule_pit", "source":"Manual", "car_id":car_id, "requested_lap":21, "compound":str(wet.compounds[-1])}).accepted), "Spa V21 accepted")
	check(not bool(v21.submit({"type":"order_pit", "source":"AI", "car_id":car_id, "compound":str(wet.compounds[-1])}).accepted), "AI cannot preempt manual V21")
	check(v21.step_ticks(500) == 500, "Spa pre-V21 elapsed")
	check(int(v21.state.cars[0].pit_requested_lap) == 21 and int(v21.state.cars[0].pit_entry_tick) == -1, "V21 not executed early")
	var ok: bool = problems.is_empty()
	print("APEX2_DRIVER_DETERMINISM_12_%s checks=%d problems=%s" % ["PASS" if ok else "FAIL", checks, str(problems)])
	quit(0 if ok else 1)
