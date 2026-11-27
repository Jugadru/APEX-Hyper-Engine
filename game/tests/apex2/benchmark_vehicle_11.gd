extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Ref = preload("res://experimental/apex2/simulation_kernel.gd")
const Vehicle = preload("res://experimental/apex2/vehicle_kernel_11.gd")
const TICKS: int = 120
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rows: Array = []
	for row in [{"code":"GBR","weather":"Seco"},{"code":"BEL","weather":"Chuva intensa"},{"code":"ITA","weather":"Seco"},{"code":"SIN","weather":"Chuva intensa"}]:
		var scenario: Dictionary = Adapter.create_pair(row.code,row.weather,6701).scenario
		var a = Ref.new(); var b = Vehicle.new()
		assert(a.initialize(scenario) and b.initialize(scenario))
		var before: int = Time.get_ticks_usec()
		assert(a.step_ticks(TICKS) == TICKS)
		var ref_us: int = Time.get_ticks_usec() - before
		before = Time.get_ticks_usec()
		assert(b.step_ticks(TICKS) == TICKS)
		var physics_us: int = Time.get_ticks_usec() - before
		var record: Dictionary = {"track":row.code,"weather":row.weather,"seed":6701,"ticks":TICKS,
			"reference_us_per_tick":float(ref_us)/TICKS,"vehicle_11_us_per_tick":float(physics_us)/TICKS,
			"reference_events":a.state.events.size(),"vehicle_events":b.state.events.size(),
			"physics_parity":false,"supports_ai":false,"supports_full_pit":false,"gpu_fps_measured":false}
		rows.append(record)
		print("APEX2_BENCH_VEHICLE_11 ",JSON.stringify(record))
	var f: FileAccess = FileAccess.open("res://qa/APEX2_VEHICLE_11_BENCHMARK.json",FileAccess.WRITE)
	assert(f != null)
	f.store_string(JSON.stringify({"classification":"MICROBENCHMARK_NOT_EQUIVALENCE","notes":"Vehicle1.1 adds physics while reference integrates a constant lap fraction; neither replaces production Core2; headless CPU measurement only.","rows":rows},"  "))
	f.close()
	print("APEX2_VEHICLE_11_BENCHMARK_PASS scenarios=",rows.size())
	quit(0)
