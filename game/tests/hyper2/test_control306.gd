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
	var tie:Dictionary=before.rows.duplicate(true)
	tie[a].distance=int(tie[b].distance)
	var tie_monitor:Dictionary=C.initial()
	var tie_warnings:Array=C.settle(tie_monitor,before.rows,tie,false)
	ck(tie_monitor.order_warnings==1 and tie_warnings[0].car_id==a,"exact tie uses classification order")
	C.settle(tie_monitor,tie,after,false)
	ck(tie_monitor.order_warnings==1,"crossing not double counted after tie")
	# Wrapped physical position, including lapped traffic and the finish line.
	var lapped_before:Dictionary=before.rows.duplicate(true)
	lapped_before[a].distance=1099000;lapped_before[b].distance=102000
	var lapped_after:Dictionary=lapped_before.duplicate(true)
	lapped_after[a].distance=1110000;lapped_after[b].distance=106000
	var lap_monitor:Dictionary=C.initial()
	var lap_warnings:Array=C.settle(lap_monitor,lapped_before,lapped_after,false,1000000)
	ck(lap_monitor.order_warnings==1 and lap_warnings[0].crossing_kind=="lapped_traffic" and lap_warnings[0].car_id==a,"lapped physical crossing detected")
	var seam_before:Dictionary=before.rows.duplicate(true)
	seam_before[a].distance=990000;seam_before[b].distance=1002000
	var seam_after:Dictionary=seam_before.duplicate(true)
	seam_after[a].distance=1001000;seam_after[b].distance=1013000
	var seam_monitor:Dictionary=C.initial()
	C.settle(seam_monitor,seam_before,seam_after,false,1000000)
	ck(seam_monitor.order_warnings==0,"finish line alone is not a crossing")
	var half_before:Dictionary=before.rows.duplicate(true)
	half_before[a].distance=499000;half_before[b].distance=0
	var half_after:Dictionary=half_before.duplicate(true)
	half_after[a].distance=501000
	var half_monitor:Dictionary=C.initial()
	C.settle(half_monitor,half_before,half_after,false,1000000)
	ck(half_monitor.order_warnings==0,"half lap seam does not manufacture pass")
	var tied_field:Array=field.duplicate(true)
	tied_field[0].dynamics.distance_mm=200000;tied_field[1].dynamics.distance_mm=200000
	tied_field[0].dynamics.speed_mm_s=30000;tied_field[1].dynamics.speed_mm_s=50000
	var tied_caps:Dictionary=C.begin(C.initial(),tied_field,1000000)
	ck(int(tied_caps.caps[b])==30000 and int(tied_caps.caps[a])==50000,"exact physical tie follows classification")
	k.step_ticks(300)
	# Trigger the normal incident → damage → neutralization path, not a
	# direct edit to the neutralization timer. Errors otherwise disabled.
	var incident:Dictionary=k.state.cars[0]
	incident.evolution.error_count+=1;incident.evolution.error_kind="SPIN"
	incident.evolution.error_total=40;incident.evolution.error_left=40;incident.evolution.error_ref_speed=int(incident.dynamics.speed_mm_s)
	k.step_tick()
	ck(int(incident.mega_30.damage)==85 and int(k.state.mega_control.remaining)==100 and int(incident.evolution.error_left)==39,"spin deploys control through kernel with active error")
	var pre=K.new();ck(pre.restore(k.checkpoint()),"restore announced deployment before first tick")
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
	var inconsistent:Dictionary=k.checkpoint();inconsistent.state.race_control_306.total_ticks+=1
	ck(not copy.restore(inconsistent),"reject inconsistent timer ledger")
	incident.evolution.error_count+=1;incident.evolution.error_kind="SPIN"
	k.step_tick()
	ck(int(k.state.mega_control.remaining)==100,"second deployment")
	k.step_ticks(100)
	ck(int(k.state.race_control_306.deployments)==2 and int(k.state.race_control_306.total_ticks)==200 and k.state.race_control_306.phase=="GREEN","second deployment ledger")
	ck(copy.restore(k.checkpoint()),"restore after repeated deployments")
	var legacy=K.new();var old:Dictionary=S.create("ITA","Seco",2026);old.hyper305_physics=true
	ck(legacy.initialize(old) and not legacy.state.has(C.KEY),"legacy isolated")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.control_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==11 and ui.checkpoint_path==ui.SAVE306,"UI independent mode")
	ck(ui.telemetry.text.contains("VSC"),"control telemetry")
	ui.queue_free();await process_frame
	print("HYPER306_CONTROL ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
