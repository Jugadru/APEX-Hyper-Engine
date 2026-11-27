extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Driver = preload("res://experimental/apex2/driver_kernel_12.gd")
const Racecraft = preload("res://experimental/apex2/racecraft_kernel_13.gd")
func _initialize() -> void: call_deferred("run")
func measure(klass: Script, scenario: Dictionary, ticks: int) -> Dictionary:
	var engine = klass.new()
	if not engine.initialize(scenario):
		return {"status":"FAIL"}
	var began: int = Time.get_ticks_usec()
	var n: int = engine.step_ticks(ticks)
	var elapsed: int = Time.get_ticks_usec() - began
	return {"status":"PASS" if n == ticks else "FAIL", "ticks":n, "total_ms":float(elapsed) / 1000.0, "ms_per_tick":float(elapsed) / maxi(1, n) / 1000.0, "events":engine.state.events.size(), "hash":engine.sporting_hash()}
func run() -> void:
	var output: Dictionary = {"description":"APEX 2 Driver 1.2 vs Racecraft 1.3; 24 cars, headless; different rules, not a superiority claim", "scenarios":[], "status":"PASS"}
	for e in [{"code":"GBR", "condition":"Seco"}, {"code":"BEL", "condition":"Chuva intensa"}, {"code":"ITA", "condition":"Seco"}, {"code":"SIN", "condition":"Chuva intensa"}]:
		var scenario: Dictionary = Adapter.create_pair(e.code, e.condition, 1303).scenario
		var control: Dictionary = measure(Driver, scenario, 160)
		var experimental: Dictionary = measure(Racecraft, scenario, 160)
		if control.status != "PASS" or experimental.status != "PASS":
			output.status = "FAIL"
		output.scenarios.append({"circuit":e.code,"weather":e.condition,"driver_12":control,"racecraft_13":experimental})
	var file := FileAccess.open("res://qa/apex2_racecraft_13/benchmark.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(output, "  "))
		file.close()
	print("APEX2_RACECRAFT_BENCHMARK_13_", output.status, " scenarios=", output.scenarios.size())
	quit(0 if output.status == "PASS" else 1)
