extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Kernel = preload("res://experimental/apex2/racecraft_kernel_13.gd")
const TICKS: int = 8000
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scenario: Dictionary = Adapter.create_pair("ITA", "Seco", 1303).scenario
	var k = Kernel.new()
	if not k.initialize(scenario):
		printerr("APEX2_RACECRAFT_LONG13_FAIL init")
		quit(1); return
	var before: int = Time.get_ticks_usec()
	var processed: int = k.step_ticks(TICKS)
	var elapsed_ms: float = float(Time.get_ticks_usec() - before) / 1000.0
	var checksum: String = k.sporting_hash()
	var checkpoint: Dictionary = k.checkpoint()
	var restored = Kernel.new()
	var repeatable: bool = restored.restore(checkpoint) and restored.sporting_hash() == checksum
	if repeatable:
		repeatable = restored.step_ticks(100) == 100 and k.step_ticks(100) == 100 and restored.sporting_hash() == k.sporting_hash()
	var credible_counts: bool = int(k.state.racecraft_passes) >= 0 and int(k.state.racecraft_passes) <= int(k.state.racecraft_attempts)
	var legal_events: bool = true
	for event in k.state.events:
		if str(event.type) == "racecraft_overtake_confirmed":
			if int(event.gap_mm) <= 0 or str(event.lane) == "CENTER":
				legal_events = false
	var ok: bool = processed == TICKS and repeatable and credible_counts and legal_events
	var result: Dictionary = {"status":"PASS" if ok else "FAIL", "circuit":"Monza", "weather":"Seco", "ticks":processed, "cars":k.state.cars.size(), "elapsed_ms":elapsed_ms, "passes":int(k.state.racecraft_passes), "attempts":int(k.state.racecraft_attempts), "aborts":int(k.state.racecraft_aborts), "event_count":k.state.events.size(), "replay_parity":repeatable, "valid_pass_events":legal_events, "hash_after_resume":k.sporting_hash()}
	var file := FileAccess.open("res://qa/apex2_racecraft_13/long_run.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"  "))
		file.close()
	print("APEX2_RACECRAFT_LONG_13_", result.status, " ", JSON.stringify(result))
	quit(0 if ok else 1)
