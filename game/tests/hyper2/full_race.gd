extends SceneTree
const K = preload("res://experimental/hyper2/kernel.gd")
const S = preload("res://experimental/hyper/scenario.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var code: String = args[0] if args.size() > 0 else "ITA"
	var weather: String = args[1] if args.size() > 1 else "Seco"
	var k = K.new()
	var scenario: Dictionary = S.create(code, "Seco" if weather=="Variável" else weather, 2026)
	if weather=="Variável":scenario.hyper_weather=[{"tick":600,"water":2200},{"tick":1800,"water":4400},{"tick":4500,"water":2600},{"tick":7000,"water":500},{"tick":12000,"water":4600},{"tick":15000,"water":2500},{"tick":19000,"water":0}]
	if "hyper22" in args: scenario.hyper22_physics=true
	if "hyper23" in args: scenario.hyper23_physics=true
	if "hyper30" in args: scenario.hyper30_physics=true
	if "hyper301" in args: scenario.hyper301_physics=true
	if "hyper302" in args: scenario.hyper302_physics=true
	if "hyper303" in args: scenario.hyper303_physics=true
	if "hyper304" in args: scenario.hyper304_physics=true
	if "hyper305" in args: scenario.hyper305_physics=true
	if "hyper306" in args: scenario.hyper306_physics=true
	if "hyper3061" in args: scenario.hyper3061_physics=true
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
	if k.state.has("wet_attack_reasons"):print("WET_ATTACK_REASONS ",JSON.stringify(k.state.wet_attack_reasons))
	if k.state.has("race_control_306"):print("RACE_CONTROL_SUMMARY ",JSON.stringify(k.state.race_control_306))
	var reason_counts:Dictionary={}
	for event in k.state.events:
		if event.type=="hyper_strategy_order":
			var reason:String=str(event.get("reason","unknown"))
			reason_counts[reason]=int(reason_counts.get(reason,0))+1
	print("PIT_REASON_COUNTS ",JSON.stringify(reason_counts))
	quit(0 if ok else 1)
