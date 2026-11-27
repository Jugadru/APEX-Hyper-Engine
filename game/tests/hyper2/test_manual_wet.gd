extends SceneTree
const K = preload("res://experimental/hyper2/kernel.gd")
const S = preload("res://experimental/hyper/scenario.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scenario: Dictionary = S.create("ITA","Seco",2026,"Ferrari",true)
	if "hyper22" in OS.get_cmdline_user_args(): scenario.hyper22_physics=true
	if "hyper23" in OS.get_cmdline_user_args(): scenario.hyper23_physics=true
	if "hyper30" in OS.get_cmdline_user_args(): scenario.hyper30_physics=true
	if "hyper301" in OS.get_cmdline_user_args(): scenario.hyper301_physics=true
	if "hyper302" in OS.get_cmdline_user_args(): scenario.hyper302_physics=true
	if "hyper303" in OS.get_cmdline_user_args(): scenario.hyper303_physics=true
	if "hyper304" in OS.get_cmdline_user_args(): scenario.hyper304_physics=true
	if "hyper305" in OS.get_cmdline_user_args(): scenario.hyper305_physics=true
	if "hyper306" in OS.get_cmdline_user_args(): scenario.hyper306_physics=true
	if "hyper3061" in OS.get_cmdline_user_args(): scenario.hyper3061_physics=true
	scenario.hyper_weather = [{"tick":1500,"water":5000}]
	var k = K.new()
	if not k.initialize(scenario): quit(1); return
	var player: Dictionary = {}
	for car in k.state.cars:
		if str(car.team)=="Ferrari": player = car; break
	var id: int = int(player.id)
	var accepted: bool = bool(k.submit({"type":"schedule_pit","source":"Manual","car_id":id,"requested_lap":21,"compound":"Chuva","allow_double_stack":true}).accepted)
	var protected: bool = true
	var wet_drs: bool = false
	var first_service_lap: int = -1
	var first_entry: int = -1
	while not bool(k.state.finished) and int(k.state.tick)<40000:
		k.step_tick()
		if int(k.state.tick)>1500 and bool(player.hyper.drs_active): wet_drs = true
		if int(player.hyper.pit_count)==0 and int(player.laps_done)<20 and str(player.pit_stage)!="TRACK": protected = false
		if int(player.hyper.pit_count)>0: first_service_lap = int(player.hyper.last_pit_lap); break
	for ev in k.state.events:
		if str(ev.type)=="pit_entry_boundary" and int(ev.car_id)==id: first_entry = int(ev.requested_lap); break
	var ok: bool = accepted and protected and not wet_drs and first_service_lap==21 and first_entry==21 and int(k.state.water_microns)==5000
	print("HYPER_MANUAL_WET ",JSON.stringify({"status":"PASS" if ok else "FAIL","tick":k.state.tick,"entry_lap":first_entry,"service_lap":first_service_lap,"no_early_pit":protected,"wet_drs_active":wet_drs,"driver":player.name,"weather_microns":k.state.water_microns}))
	quit(0 if ok else 1)
