extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const VehicleKernel = preload("res://experimental/apex2/vehicle_kernel_11.gd")
const DriverKernel = preload("res://experimental/apex2/driver_kernel_12.gd")
func _initialize() -> void: call_deferred("run")
func measure(scenario: Dictionary, with_brain: bool) -> Dictionary:
	var k = DriverKernel.new() if with_brain else VehicleKernel.new()
	if not k.initialize(scenario): return {"failed": "initialize"}
	k.step_ticks(20) # same warm-up, sporting ticks not excluded from coverage
	var began: int = Time.get_ticks_usec()
	var count: int = k.step_ticks(180)
	var elapsed: int = Time.get_ticks_usec() - began
	return {"ticks": count, "us_per_tick": snappedf(float(elapsed) / float(maxi(1, count)), 0.01), "hash": k.sporting_hash(), "events": k.state.events.size()}
func run() -> void:
	var rows: Array = []
	for spec in [{"track":"GBR", "weather":"Seco"}, {"track":"BEL", "weather":"Chuva intensa"}, {"track":"ITA", "weather":"Seco"}, {"track":"SIN", "weather":"Chuva intensa"}]:
		var scenario: Dictionary = Adapter.create_pair(spec.track, spec.weather, 1202).scenario
		var baseline_runs: Array = []
		var brain_runs: Array = []
		for repetition in range(3):
			baseline_runs.append(measure(scenario, false))
			brain_runs.append(measure(scenario, true))
		var baseline_times: Array = []
		var brain_times: Array = []
		for r in baseline_runs: baseline_times.append(float(r.us_per_tick))
		for r in brain_runs: brain_times.append(float(r.us_per_tick))
		baseline_times.sort(); brain_times.sort()
		var baseline_median: float = baseline_times[1]
		var brain_median: float = brain_times[1]
		rows.append({"track": spec.track, "weather": spec.weather, "vehicle_11_median_us_per_tick":baseline_median, "driver_12_median_us_per_tick":brain_median, "overhead_percent":snappedf(100.0 * (brain_median / baseline_median - 1.0), 0.01), "vehicle_11_samples":baseline_runs, "driver_12_samples":brain_runs, "rules_parity":false})
		print("APEX2_DRIVER_BENCH ", spec.track, " vehicle11_median_us=", baseline_median, " driver12_median_us=", brain_median)
	var report: Dictionary = {"label":"Experimental only — 24 cars, median of three runs each, 180 timed ticks after 20 warmup", "hardware":"current host Godot headless", "not_fps":true, "not_core2_comparison":true, "scenarios":rows}
	var file: FileAccess = FileAccess.open("res://qa/apex2_driver_12/benchmark_driver_12.json", FileAccess.WRITE)
	if file == null: printerr("APEX2_DRIVER_BENCH_FAIL open file"); quit(1); return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("APEX2_DRIVER_BENCHMARK_12_PASS scenarios=", rows.size())
	quit(0)
