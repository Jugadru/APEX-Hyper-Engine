extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const J=preload("res://experimental/hyper2/race_stewards_3063.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func sector(deployment:int,boundary:int,elapsed:int=1700000)->Dictionary:
	return {"type":"race_control_sector_warning","deployment":deployment,"boundary_mm":boundary,"elapsed_us":elapsed,"reference_us":2000000,"delta_us":elapsed-2000000}
func run()->void:
	var x:Dictionary=J.initial()
	var roster:Array=[{"id":1},{"id":2},{"id":3}]
	ck(J.valid(x,roster,0,0),"empty ledger")
	ck(J.record(x,sector(1,100000,1800000),1,20,1).is_empty() and x.pending.is_empty(),"exact tolerance is not a case")
	var bad:Dictionary=sector(1,100000);bad.delta_us=-400000
	ck(J.record(x,bad,1,20,1).is_empty(),"inconsistent measurement rejected")
	ck(J.record(x,sector(1,100000),1,20,1).size()==1,"first sector opens investigation")
	ck(J.record(x,sector(1,100000),1,20,1).is_empty(),"duplicate boundary suppressed")
	J.record(x,sector(1,200000,1600000),1,30,1)
	J.record(x,{"type":"race_control_speed_warning","delta_mm":4000},1,30,1)
	ck(x.pending.size()==1 and x.pending["1:pace:1"].sector_count==2 and x.pending["1:pace:1"].delta_us==-400000,"pace evidence consolidated")
	J.record(x,{"type":"race_control_order_warning","other_id":1,"crossing_kind":"lapped_traffic"},2,31,1)
	J.record(x,{"type":"race_control_order_warning","other_id":2,"crossing_kind":"lapped_traffic"},1,32,1)
	J.record(x,{"type":"race_control_speed_warning","delta_mm":4000},3,32,1)
	ck(x.pending.size()==3 and J.valid(x,roster,32,1),"pair dedup and valid pending state")
	ck(J.close_deployment(x,1,40).size()==3 and x.pending.is_empty(),"close investigations on green")
	ck(x.warnings==1 and x.insufficient==2 and J.valid(x,roster,40,1),"warning without punishment, insufficient evidence for order or speed-only")
	ck(J.close_deployment(x,1,41).is_empty() and J.record(x,sector(1,300000),1,41,1).is_empty(),"closed deployment idempotent")
	ck(J.record(x,sector(2,300000),1,45,2).size()==1,"new deployment independent")
	J.close_deployment(x,2,46)
	var invalid:Dictionary=x.duplicate(true);invalid.history[0].delta_us=123
	ck(not J.valid(invalid,roster,46,2),"malformed evidence rejected on restore")
	var bounded:Dictionary=J.initial()
	for i in range(1,J.MAX_CASES+3):
		J.record(bounded,sector(i,100000),1,i,i)
		J.close_deployment(bounded,i,i)
	ck(bounded.history.size()==J.MAX_CASES and bounded.evicted==2 and J.valid(bounded,roster,J.MAX_CASES+2,J.MAX_CASES+2),"bounded history and cumulative totals")
	var s:Dictionary=S.create("ITA","Seco",2026);s.hyper3063_physics=true;s.hyper_errors_enabled=false
	var k=K.new();ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==14,"revision14 initialization")
	var old:Dictionary=S.create("ITA","Seco",2026);old.hyper3062_physics=true;old.hyper_errors_enabled=false
	var legacy=K.new();ck(legacy.initialize(old) and not legacy.state.has(J.KEY),"legacy isolated")
	k.step_ticks(300);legacy.step_ticks(300)
	ck(k.classification()==legacy.classification(),"nominal classification parity")
	for engine in [k,legacy]:
		var incident:Dictionary=engine.state.cars[0]
		incident.evolution.error_count+=1;incident.evolution.error_kind="SPIN";incident.evolution.error_total=40;incident.evolution.error_left=40;incident.evolution.error_ref_speed=int(incident.dynamics.speed_mm_s)
		engine.step_tick()
	ck(int(k.state.mega_control.remaining)==100,"incident VSC")
	# Directed synthetic evidence traverses the production event adapter;
	# no claim that normal speed caps produce this violation.
	var id:int=int(k.state.cars[1].id)
	k._record_steward_evidence(sector(1,100000),id)
	ck(k.state[J.KEY].pending.size()==1,"production evidence adapter")
	var replay=R.new();replay.attach(k)
	var copy=K.new();ck(copy.restore(k.checkpoint()),"checkpoint with pending investigation")
	for i in range(100):
		k.step_tick();legacy.step_tick();copy.step_tick();replay.observed(k)
	ck(k.state[J.KEY].pending.is_empty() and k.state[J.KEY].warnings>=1,"automatic closure on green")
	ck(k.state[J.KEY]==copy.state[J.KEY] and k.sporting_hash()==copy.sporting_hash(),"deterministic decision after restore")
	ck(k.classification()==legacy.classification(),"investigation cannot change sporting positions or speed")
	var sought=replay.seek(int(k.state.tick))
	ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay with decisions")
	var broken:Dictionary=k.checkpoint();broken.state[J.KEY].next_id+=1
	ck(not copy.restore(broken),"reject corrupted case sequence")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.stewards_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==14 and ui.checkpoint_path==ui.SAVE3063,"independent UI mode")
	ck(ui.telemetry.text.contains("comissários"),"steward telemetry")
	ui.queue_free();await process_frame
	print("HYPER3063_STEWARDS ",JSON.stringify({"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
