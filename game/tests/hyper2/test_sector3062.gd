extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const C=preload("res://experimental/hyper2/sector_control_3062.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func sample(distance:int,eligible:bool=true)->Dictionary:return {"distance":distance,"eligible":eligible}
func run()->void:
	var lap:int=300001
	ck(C.count(lap)==4 and C.next_boundary(0,lap)==75000,"balanced arc-length sectors")
	ck(C.next_boundary(75000,lap)==150000 and C.next_boundary(300000,lap)==300001 and C.next_boundary(300001,lap)==375001,"exact and wrapped boundaries")
	ck(C.reference_us(300001,lap)==1500020 and C.reference_us(75000,lap)==1500000,"reference lengths including remainder")
	var x:Dictionary=C.initial()
	var distance:int=0
	for tick in range(1,41):
		var next:int=distance+10000
		var warnings:Array=C.observe(x,sample(distance),sample(next),300000,tick,1)
		ck(warnings.is_empty(),"legal reference speed tick "+str(tick))
		distance=next
	ck(int(x.samples)>0 and int(x.delta_us)==0 and C.valid(x,300000,40,1),"complete legal sectors")
	var fast:Dictionary=C.initial();distance=0
	var emitted:int=0
	for tick in range(1,41):
		var next:int=distance+12000
		emitted+=C.observe(fast,sample(distance),sample(next),300000,tick,1).size()
		distance=next
	ck(emitted>0 and emitted==int(fast.warnings) and int(fast.delta_us)<-200000,"excess measured after grace")
	var old_samples:int=int(fast.samples)
	C.observe(fast,sample(distance),sample(distance+12000,false),300000,41,1)
	ck(int(fast.last_cross_us)==-1 and int(fast.eligible_ticks)==0 and int(fast.samples)==old_samples,"pit or incident invalidates partial sector")
	C.observe(fast,sample(distance+12000),sample(distance+22000),300000,42,2)
	ck(int(fast.deployment)==2 and int(fast.eligible_ticks)==1 and int(fast.samples)==old_samples,"new deployment grace and retained cumulative totals")
	var s:Dictionary=S.create("ITA","Seco",2026);s.hyper3062_physics=true;s.hyper_errors_enabled=false
	var k=K.new();ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==13,"init")
	k.step_ticks(300)
	var incident:Dictionary=k.state.cars[0]
	incident.evolution.error_count+=1;incident.evolution.error_kind="SPIN";incident.evolution.error_total=40;incident.evolution.error_left=40;incident.evolution.error_ref_speed=int(incident.dynamics.speed_mm_s)
	k.step_tick()
	ck(int(k.state.mega_control.remaining)==100,"active incident VSC")
	var pre=K.new();ck(pre.restore(k.checkpoint()),"restore announced VSC")
	var replay=R.new();replay.attach(k)
	for i in range(50):k.step_tick();replay.observed(k)
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore mid VSC")
	for i in range(50):k.step_tick();copy.step_tick();replay.observed(k)
	ck(k.sporting_hash()==copy.sporting_hash(),"continuation through green")
	var samples:int=0
	for car in k.state.cars:
		var row:Dictionary=car[C.KEY]
		ck(C.valid(row,int(k.state.lap_length_mm),int(k.state.tick),1),"valid live ledger "+str(car.id))
		samples+=int(row.samples)
	ck(samples>0 and int(k.state.mega_control.remaining)==0,"real sector crossings during VSC")
	var sought=replay.seek(int(k.state.tick));ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay")
	var invalid:Dictionary=k.checkpoint();invalid.state.cars[0][C.KEY].next_mm+=1
	ck(not copy.restore(invalid),"reject malformed boundary")
	var legacy=K.new();var old:Dictionary=S.create("ITA","Seco",2026);old.hyper3061_physics=true
	ck(legacy.initialize(old) and not legacy.state.cars[0].has(C.KEY),"legacy isolated")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.sector_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==13 and ui.checkpoint_path==ui.SAVE3062,"independent UI mode")
	ck(ui.telemetry.text.contains("setor"),"sector telemetry")
	ui.queue_free();await process_frame
	print("HYPER3062_SECTOR ",JSON.stringify({"checks":checks,"failures":failures,"live_samples":samples,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
