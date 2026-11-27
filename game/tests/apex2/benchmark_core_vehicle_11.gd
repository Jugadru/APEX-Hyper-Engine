extends SceneTree
## Same 2012 grid/seed/track and tick count, DIFFERENT physics/rule coverage.
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Replay = preload("res://scripts/core/race_replay_0660.gd")
const Vehicle = preload("res://experimental/apex2/vehicle_kernel_11.gd")
const COUNT: int = 120
func _initialize() -> void: call_deferred("run")
func _rss_kb() -> int:
	for line in FileAccess.get_file_as_string("/proc/self/status").split("\n"):
		if line.begins_with("VmRSS:"):
			return int(line.replace("VmRSS:","").replace("kB","").strip_edges())
	return -1
func run() -> void:
	var rows: Array = []
	for item in [{"track":"GBR","weather":"Seco"},{"track":"BEL","weather":"Chuva intensa"},{"track":"ITA","weather":"Seco"},{"track":"SIN","weather":"Chuva intensa"}]:
		var pair: Dictionary = Adapter.create_pair(item.track,item.weather,6701)
		var core = Replay.new(); core.attach(pair.core)
		var veh = Vehicle.new(); assert(veh.initialize(pair.scenario))
		var initial_rss: int = _rss_kb()
		var started: int = Time.get_ticks_usec()
		for i in range(COUNT): assert(core.step_tick())
		var core_us: int = Time.get_ticks_usec() - started
		var core_rss: int = _rss_kb()
		started = Time.get_ticks_usec()
		assert(veh.step_ticks(COUNT) == COUNT)
		var vehicle_us: int = Time.get_ticks_usec() - started
		var vehicle_rss: int = _rss_kb()
		var comparability: Dictionary = Adapter.side_by_side(pair.core,veh.snapshot())
		assert(comparability.missing_or_mismatched_ids.is_empty())
		var row: Dictionary = {"track":item.track,"weather":item.weather,"seed":6701,"ticks":COUNT,
			"core2_us_per_tick":float(core_us)/COUNT,"vehicle_11_us_per_tick":float(vehicle_us)/COUNT,
			"core2_events":pair.core.events.size(),"vehicle_11_events":veh.state.events.size(),
			"core2_hash":core.hashes[-1],"vehicle_11_hash":veh.sporting_hash(),
			"rss_initial_kb":initial_rss,"rss_after_core_kb":core_rss,"rss_after_vehicle_kb":vehicle_rss,
			"same_model":false,"rule_coverage_equivalent":false,"fps_measured":false}
		rows.append(row)
		print("APEX2_CORE_VEHICLE_11 ",JSON.stringify(row))
	var f: FileAccess = FileAccess.open("res://qa/APEX2_VEHICLE_11_CORE_AB.json", FileAccess.WRITE)
	assert(f != null)
	f.store_string(JSON.stringify({"status":"PASS","comparison":"NOT_EQUIVALENT_RULE_COVERAGE","rows":rows},"  "))
	f.close()
	print("APEX2_VEHICLE_11_CORE_AB_PASS scenarios=",rows.size())
	quit(0)
