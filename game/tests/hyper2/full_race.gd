extends SceneTree
const K = preload("res://experimental/hyper2/kernel.gd")
const S = preload("res://experimental/hyper/scenario.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var code: String = args[0] if args.size() > 0 else "ITA"
	var weather: String = args[1] if args.size() > 1 else "Seco"
	var k = K.new()
	var scenario: Dictionary = S.create(code, weather, 2026)
	if "hyper22" in args: scenario.hyper22_physics=true
	if "hyper23" in args: scenario.hyper23_physics=true
	if not k.initialize(scenario): quit(1); return
	var begin: int = Time.get_ticks_msec()
	var resume_checked: bool = false
	var last_report: int = 0
	while not bool(k.state.finished) and int(k.state.tick) < 100000:
		k.step_ticks(500)
		if int(k.state.tick) - last_report >= 5000:
			last_report = int(k.state.tick)
			var rows: Array = k.classification()
			print("PROGRESS ", code," ",k.state.tick," leader laps=", rows[0].laps, " fuel=",k.state.cars[0].dynamics.fuel_g)
		if not resume_checked and int(k.state.tick) >= 2500:
			var copy = K.new()
			if not copy.restore(k.checkpoint()): printerr("restore failed"); quit(1); return
			k.step_ticks(50); copy.step_ticks(50)
			if k.sporting_hash() != copy.sporting_hash(): printerr("replay failed"); quit(1); return
			resume_checked = true
	var retired: int = 0
	var stops: int = 0
	var complete: int = 0
	for row in k.classification():
		if row.retired: retired += 1
		if row.finished and not row.retired and row.laps == k.state.race_laps: complete += 1
		stops += int(row.stops)
	var ok: bool = bool(k.state.finished) and complete > 0 and complete + retired == 24 and resume_checked and stops > 0
	print("HYPER_FULL ", JSON.stringify({"status":"PASS" if ok else "FAIL","track":code,"weather":weather,"ticks":k.state.tick,"clock_s":float(k.state.clock_ms)/1000.0,"elapsed_ms":Time.get_ticks_msec()-begin,"complete":complete,"retired":retired,"stops":stops,"passes":k.state.racecraft_passes,"attempts":k.state.racecraft_attempts,"hash":k.sporting_hash(),"checkpoint_parity":resume_checked,"winner":k.classification()[0].name}))
	quit(0 if ok else 1)
