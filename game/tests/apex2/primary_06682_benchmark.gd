extends SceneTree
## Comparable CPU microbenchmark: both use the exact SAME Core2 physics.
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Factory = preload("res://experimental/apex2/session_factory.gd")
const Legacy = preload("res://scripts/core/race_replay_0660.gd")
const TICKS: int = 160
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rows: Array = []
	for test in [{"track":"GBR","weather":"Seco"},{"track":"BEL","weather":"Chuva intensa"},{"track":"ITA","weather":"Seco"},{"track":"SIN","weather":"Chuva intensa"}]:
		var before: Dictionary = Adapter.create_pair(test.track, test.weather, 6701)
		var after: Dictionary = Adapter.create_pair(test.track, test.weather, 6701)
		var legacy = Legacy.new()
		legacy.attach(before.core)
		var primary = Factory.create(after.core)
		var start_us: int = Time.get_ticks_usec()
		for i in range(TICKS): assert(legacy.step_tick())
		var legacy_us: int = Time.get_ticks_usec() - start_us
		start_us = Time.get_ticks_usec()
		for i in range(TICKS): assert(primary.step_tick())
		var primary_us: int = Time.get_ticks_usec() - start_us
		assert(primary.hashes == legacy.hashes)
		var row: Dictionary = {"track":test.track,"weather":test.weather,"seed":6701,"ticks":TICKS,"legacy_us_per_tick":float(legacy_us)/TICKS,"primary_us_per_tick":float(primary_us)/TICKS,"same_physics":true,"identical_hashes":true,"fps_test":false}
		rows.append(row)
		print("APEX2_06682_BENCH_ROW ",JSON.stringify(row))
	var dest: String = "res://qa/apex2_primary_06682/benchmark.json"
	var file: FileAccess = FileAccess.open(dest,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status":"PASS","notes":"Same Core2 sports physics and rules in both; measured headless CPU test with fixed ticks, not FPS", "rows":rows},"  "))
	file.close()
	print("APEX2_06682_BENCHMARK_PASS scenarios=",rows.size())
	quit(0)
