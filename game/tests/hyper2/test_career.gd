extends SceneTree
const C = preload("res://experimental/hyper2/career.gd")
const K = preload("res://experimental/hyper2/kernel.gd")
const E = preload("res://experimental/hyper/environment.gd")
const Q = preload("res://experimental/hyper/indexed_queue.gd")
const LegacyQ = preload("res://experimental/apex2/command_queue.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mega:bool="hyper30" in OS.get_cmdline_user_args()
	var path: String = "user://hyper30_qa_full_career.bin" if mega else "user://hyper2_qa_career.bin"
	for name in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(name): DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	var c = C.new(path,mega)
	check(c.create("Ferrari",2026,data),"new 2012 career")
	check(c.state.slots.size()==6 and c.state.parts.size()==9,"unique initial physical components")
	check(not c.create("Ferrari",2027,data),"active career protected")
	var money: int = int(c.state.budget)
	check(c.hire("Chefe de Mecânica","mec_c").contains("contratado"),"staff hire")
	check(int(c.state.budget)<money,"signing debited")
	check(c.start_project("Motor","desempenho").begins_with("Projeto RD"),"project started")
	var id: String = str(c.state.projects.keys()[0])
	check(not c.install(id),"cannot install unbuilt project")
	check(c.advance_days(11),"advance design/prototype/test/manufacture")
	check(int(c.state.projects[id].stage)==4 and c.state.parts.size()==11,"two manufactured components")
	check(c.install(id) and not c.install(id),"install once, unique slots")
	check(not c.advance_days(4),"calendar time bounded")
	var scenario: Dictionary = c.prepare("Seco",true,0)
	check(not scenario.is_empty() and c.locked(),"round reservation persisted")
	check(not c.advance_days(1),"factory locked during GP")
	var saved = C.new(path,mega)
	check(saved.locked() and saved.state.active_scenario==scenario,"career load preserves frozen scenario")
	var k = K.new(); check(k.initialize(scenario),"career kernel init")
	if mega:check(int(k.state.hyper_evolution_revision)==5,"mega career sporting revision")
	var player: Dictionary = {}
	for car in k.state.cars:
		if str(car.team)=="Ferrari": player = car; break
	check(int(player.hyper.service_ticks)==12 and int(player.dynamics.wheel_power_w)>int(scenario.hyper_specs[str(player.id)].power)-1,"staff and installed engine affect racing inputs")
	check(not c.commit(k),"no partial result")
	k.step_ticks(100)
	check(k.state.has("hyper_career_token"),"career token in sporting checkpoint")
	var restored = K.new(); check(restored.restore(k.checkpoint()),"career checkpoint restores")
	# Controlled DRS detection fixture, not an official race outcome.
	var car: Dictionary = player.duplicate(true); car.laps_done = 2; car.progress_units = 2100000; car.hyper.drs_prev_progress = 2070000; car.hyper.drs_armed_lap = 2; car.dynamics.speed_mm_s = 60000
	var zones: Array = [{"detect":80000,"start":120000,"end":290000}]
	E.drs_update(car,zones,50000,0); car.progress_units=2150000; E.drs_update(car,zones,50000,0)
	check(car.hyper.drs_active,"dry DRS after detection and two laps")
	E.drs_update(car,zones,50000,5000); check(not car.hyper.drs_active,"wet DRS disabled")
	# Full race through actual career kernel; no fixture result injection.
	var start: int = Time.get_ticks_msec()
	while not bool(k.state.finished) and int(k.state.tick)<100000: k.step_ticks(500)
	check(bool(k.state.finished),"career GP completed")
	check(c.commit(k),"finish recorded")
	check(not c.commit(k),"duplicate result rejected")
	check(int(c.state.round)==1 and c.state.results.size()==1,"round progressed once")
	check(int(c.state.staff_roster["Chefe de Mecânica"].remaining_gps)==7,"staff payroll and contract duration")
	var sum: int = 0
	for row in c.standings(false): sum += int(row.points)
	check(sum==101,"2012 points distribution")
	for slot in c.state.slots: check(int(c.state.parts[c.state.slots[slot]].km)>0,"installed part mileage persisted")
	var reloaded = C.new(path,mega)
	check(reloaded.state==c.state,"atomic career save reload")
	if mega:
		for finisher in k.state.cars:
			if str(finisher.team)=="Ferrari":
				var installed:Dictionary=c.state.parts[c.state.slots[str(finisher.name)+":Motor"]]
				check(int(installed.condition)<=int(finisher.mega_30.health)/10,"race mechanical condition persisted")
	print("HYPER_CAREER ",JSON.stringify({"checks":checks,"failures":failures,"ticks":k.state.tick,"elapsed_ms":Time.get_ticks_msec()-start,"round":c.state.round,"points":sum,"winner":k.classification()[0].name,"hash":k.sporting_hash()}))
	quit(0 if failures.is_empty() else 1)
