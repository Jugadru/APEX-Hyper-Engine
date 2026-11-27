extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const C=preload("res://experimental/hyper2/race_control_306.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Dictionary=S.create("ITA","Seco",2026);s.hyper306_physics=true;s.hyper_errors_enabled=false
	var k=K.new();ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==11,"init")
	var x:Dictionary=C.initial()
	var field:Array=k.state.cars.slice(0,2).duplicate(true)
	for car in field:car.finished=false;car.pit_stage="TRACK";car.evolution.error_left=0
	field[0].dynamics.distance_mm=100000;field[0].dynamics.speed_mm_s=50000
	field[1].dynamics.distance_mm=120000;field[1].dynamics.speed_mm_s=30000
	var before:Dictionary=C.begin(x,field,1000000)
	ck(x.phase=="VSC" and x.deployments==1 and before.caps[int(field[0].id)]==31600,"lane-independent following target")
	ck(before.caps[int(field[1].id)]==50000,"leader VSC target")
	var a:int=int(field[0].id);var b:int=int(field[1].id)
	x.cars[str(a)]={"samples":10,"delta_mm":0,"warned":false}
	var after:Dictionary=before.rows.duplicate(true)
	after[a].distance=125000;after[b].distance=124000
	var warnings:Array=C.settle(x,before.rows,after,false)
	ck(x.speed_warnings==1 and x.order_warnings==1 and warnings.size()==2,"actual distance excess and crossing detected")
	C.settle(x,before.rows,after,false)
	ck(x.speed_warnings==1 and x.order_warnings==1,"warning deduplication")
	var exempt:Dictionary=after.duplicate(true);exempt[b].eligible=false
	var y:Dictionary=C.initial();C.settle(y,before.rows,exempt,false)
	ck(y.order_warnings==0,"incident or pit exemption")
	ck(C.valid(x,field),"ledger valid")
	k.step_ticks(300)
	k.state.mega_control.remaining=100;k.state.mega_control.incidents=1;k.state.mega_control.deployments=1
	var replay=R.new();replay.attach(k)
	var attempts:int=int(k.state.racecraft_attempts)
	var bad_drs:int=0
	var bad_kers:int=0
	for i in range(50):
		k.step_tick();replay.observed(k)
		for car in k.state.cars:
			if car.hyper.drs_active:bad_drs+=1
			if car.pit_stage=="TRACK" and not car.finished and int(car.dynamics.powertrain_22.kers_used_j)>0:bad_kers+=1
	ck(k.state.race_control_306.phase=="VSC" and k.state.race_control_306.total_ticks==50,"actual neutralization")
	ck(bad_drs==0 and bad_kers==0 and int(k.state.racecraft_attempts)==attempts,"no DRS, KERS or new attacks")
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore mid VSC")
	for i in range(50):k.step_tick();copy.step_tick();replay.observed(k)
	ck(k.sporting_hash()==copy.sporting_hash(),"continuation through green")
	ck(k.state.race_control_306.phase=="GREEN" and k.state.mega_control.remaining==0 and k.state.race_control_306.total_ticks==100,"exact timer and green")
	var sought=replay.seek(int(k.state.tick))
	ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay across VSC")
	var invalid:Dictionary=k.checkpoint();invalid.state.race_control_306.total_ticks=-1
	ck(not copy.restore(invalid),"reject malformed control ledger")
	var legacy=K.new();var old:Dictionary=S.create("ITA","Seco",2026);old.hyper305_physics=true
	ck(legacy.initialize(old) and not legacy.state.has(C.KEY),"legacy isolated")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.control_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==11 and ui.checkpoint_path==ui.SAVE306,"UI independent mode")
	ck(ui.telemetry.text.contains("VSC"),"control telemetry")
	ui.queue_free();await process_frame
	print("HYPER306_CONTROL ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
