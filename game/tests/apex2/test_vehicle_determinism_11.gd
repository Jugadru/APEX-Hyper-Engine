extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Kernel = preload("res://experimental/apex2/vehicle_kernel_11.gd")
var tests: int = 0
var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	tests += 1
	if not ok: fails.append(label); printerr("APEX2_DET11_FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for row in [{"track":"GBR","weather":"Seco"},{"track":"BEL","weather":"Chuva intensa"},{"track":"ITA","weather":"Seco"},{"track":"SIN","weather":"Chuva intensa"}]:
		var scenario: Dictionary = Adapter.create_pair(row.track, row.weather, 6701).scenario
		var a = Kernel.new(); var b = Kernel.new()
		ck(a.initialize(scenario) and b.initialize(scenario), "%s initialized" % row.track)
		var id: int = int(a.state.cars[0].id)
		var command: Dictionary = {"type":"set_pace","source":"Manual","car_id":id,"pace":"Atacar"}
		ck(bool(a.submit(command).accepted) and bool(b.submit(command).accepted), "%s accepts same command" % row.track)
		ck(a.step_ticks(280) == 280, "%s batch 280 ticks" % row.track)
		for i in range(280):
			if not b.step_tick(): ck(false,"%s scalar tick %d" % [row.track,i]); break
		ck(a.sporting_hash() == b.sporting_hash(), "%s scalar batch hashes match" % row.track)
		ck(a.state.events == b.state.events, "%s event order matches" % row.track)
		var checkpoint: Dictionary = a.checkpoint()
		var c = Kernel.new()
		ck(c.restore(checkpoint), "%s checkpoint restored" % row.track)
		ck(a.step_ticks(100) == 100 and c.step_ticks(100) == 100, "%s continues" % row.track)
		ck(a.sporting_hash() == c.sporting_hash(), "%s restored continuation hash" % row.track)
		var copy: Dictionary = a.snapshot()
		var viewer = Kernel.new()
		ck(viewer.restore(checkpoint) and viewer.step_ticks(100) == 100, "%s replay in separate object" % row.track)
		ck(a.snapshot() == copy, "%s replay did not alter original" % row.track)
		print("APEX2_DET11_SCENARIO ",row.track," ticks=",a.state.tick," hash=",a.sporting_hash())
	var lap: Dictionary = Adapter.create_pair("BEL", "Chuva intensa", 222).scenario
	var k = Kernel.new()
	ck(k.initialize(lap), "V21 initialize")
	var req: Dictionary = {"type":"schedule_pit","source":"Manual","car_id":int(k.state.cars[0].id),"requested_lap":21,"compound":str(lap.compounds[-1])}
	ck(bool(k.submit(req).accepted), "manual order V21 queued")
	var ai: Dictionary = {"type":"order_pit","source":"AI","car_id":int(k.state.cars[0].id),"compound":str(lap.compounds[-1])}
	ck(not bool(k.submit(ai).accepted), "AI cannot preempt V21")
	ck(k.step_ticks(700) == 700, "V21 early ticks")
	ck(int(k.state.cars[0].pit_requested_lap) == 21 and int(k.state.cars[0].pit_entry_tick) == -1, "V21 remains protected; no V4 entry")
	var ok: bool = fails.is_empty()
	print("APEX2_DETERMINISM_11_%s checks=%d failures=%s" % ["PASS" if ok else "FAIL", tests, str(fails)])
	quit(0 if ok else 1)
