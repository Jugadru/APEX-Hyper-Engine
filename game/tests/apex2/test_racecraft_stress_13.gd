extends SceneTree
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Kernel = preload("res://experimental/apex2/racecraft_kernel_13.gd")
const TICKS: int = 2200
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scenario: Dictionary = Adapter.create_pair("ITA", "Seco", 1303).scenario
	var race = Kernel.new()
	if not race.initialize(scenario):
		printerr("APEX2_RACECRAFT_STRESS13_FAIL initialization")
		quit(1); return
	var begin: int = Time.get_ticks_usec()
	var reached: int = race.step_ticks(TICKS)
	var elapsed: int = Time.get_ticks_usec() - begin
	var event_ids_ok: bool = true
	var previous: int = 0
	for ev in race.state.events:
		if int(ev.id) <= previous:
			event_ids_ok = false
		previous = int(ev.id)
	var counts: Dictionary = {}
	for car in race.state.cars:
		var phase: String = str(car.racecraft.phase)
		counts[phase] = int(counts.get(phase, 0)) + 1
	var cp: Dictionary = race.checkpoint()
	var duplicate = Kernel.new()
	var restored: bool = duplicate.restore(cp)
	var repeated: bool = restored and duplicate.step_ticks(80) == 80 and race.step_ticks(80) == 80 and duplicate.sporting_hash() == race.sporting_hash()
	var success: bool = reached == TICKS and event_ids_ok and repeated and race.state.cars.size() == 24
	var summary: Dictionary = {"status":"PASS" if success else "FAIL", "ticks":reached, "cars":race.state.cars.size(), "events":race.state.events.size(), "attempts":int(race.state.racecraft_attempts), "confirmed_passes":int(race.state.racecraft_passes), "aborts":int(race.state.racecraft_aborts), "phases_final":counts, "elapsed_ms":float(elapsed) / 1000.0, "deterministic_resume":repeated, "event_ids_ok":event_ids_ok}
	var out := FileAccess.open("res://qa/apex2_racecraft_13/stress.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(summary, "  "))
		out.close()
	print("APEX2_RACECRAFT_STRESS_13_", summary.status, " ", JSON.stringify(summary))
	quit(0 if success else 1)
