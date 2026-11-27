extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const M=preload("res://experimental/hyper2/mega_30.gd")
const C=preload("res://experimental/hyper2/career.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var m:Dictionary=M.initial()
	M.lane(m,"RIGHT",10000,5000,10000)
	ck(m.lateral_mm==280 and m.pitch_millirad==-10 and m.roll_load_permille==500,"bounded lane and load proxies")
	M.condition_tick(m,1000000,true);ck(m.health==998,"wear by distance")
	ck(M.incident(m,"SPIN")==85 and m.damage==85,"incident damage")
	var k=K.new();var s:Dictionary=S.create("ITA","Seco",2026);s.hyper30_physics=true;s.hyper_errors_enabled=false
	ck(k.initialize(s) and k.state.hyper_evolution_revision==5,"revision 5")
	var r=R.new();r.attach(k);k.step_ticks(300);r.observed(k)
	var first:Dictionary=k.state.cars[0];var id:int=int(first.id)
	first.evolution.error_count=1;first.evolution.error_kind="SPIN"
	k.step_tick();ck(first.mega_30.damage==85 and k.state.mega_control.remaining==100,"spin triggers virtual control")
	k.step_tick();ck(k.state.cars.all(func(car:Dictionary)->bool:return not car.hyper.drs_active),"DRS disabled during control")
	ck(first.mega_30.neutral,"neutral state")
	var before:String=k.sporting_hash();var report:Dictionary=k.strategy_report(id)
	ck(report.has("ranked") and not report.ranked.is_empty() and k.sporting_hash()==before,"VSE read only")
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore rev5")
	k.step_ticks(110);copy.step_ticks(110)
	ck(k.sporting_hash()==copy.sporting_hash() and k.state.mega_control.remaining==0,"control expiry and continuation")
	var bad:Dictionary=k.checkpoint();bad.state.cars[0].mega_30.health=-1
	ck(not copy.restore(bad),"invalid health rejected")
	var probe=K.new();ck(probe.initialize(s),"replay init");var replay=R.new();replay.attach(probe)
	for i in range(350):probe.step_tick();replay.observed(probe)
	var seek=replay.seek(350);ck(seek!=null and seek.sporting_hash()==probe.sporting_hash(),"replay")
	ck(probe.state.cars.all(func(car:Dictionary)->bool:return M.valid(car.mega_30)),"24 valid states")
	var path:String="user://hyper30_qa_career.bin"
	for ext in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))
	var career=C.new(path,true);var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	ck(career.create("Ferrari",2026,data),"factory season")
	ck(career.factory_report().installed==6 and career.factory_report().spares==3,"inventory")
	var scenario:Dictionary=career.prepare("Seco",true,0)
	ck(scenario.get("hyper30_physics",false) and str(scenario.hyper_career_token).begins_with("H30:"),"career selects rev5")
	var saved=C.new(path,true);ck(saved.locked() and saved.state.active_scenario==scenario,"career save isolation")
	ck(C.new(path).state.is_empty(),"legacy rejects 3.0 career")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.mega_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(ui.k.state.hyper_evolution_revision==5 and ui.checkpoint_path==ui.SAVE30,"UI and save path")
	ck(ui.telemetry.text.contains("condição"),"condition telemetry")
	ui.queue_free();await process_frame
	print("HYPER30_GAME ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
