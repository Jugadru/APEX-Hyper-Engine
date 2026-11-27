extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const E=preload("res://experimental/hyper2/energy_301.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	ck(E.limit(10000,0,10000,0,2000)==5000,"power work ceiling")
	ck(E.limit(10000,200,8000,2000,2000)==5000,"split energy ceiling")
	var cap:Dictionary=E.settle(10000,10000,0,1000,800,40000,40000,200,8000,0,80000,0,true)
	ck(cap.applied_n==1000 and cap.v8_j==8000 and cap.residual_j==0,"target cap settlement")
	var launch:Dictionary=E.settle(8000,8000,0,100,800,0,1975,200,197,0,100000,0,false)
	ck(launch.v8_j>0 and E.valid(launch),"launch work nonzero")
	var brake:Dictionary=E.settle(0,0,8000,1000,800,40000,37750,200,7775,0,100000,0,false)
	ck(brake.v8_j==0 and brake.kers_j==0 and brake.brake_j>0,"braking no propulsion")
	for climate in ["Seco","Chuva intensa"]:
		var scenario:Dictionary=S.create("ITA",climate,2026);scenario.hyper301_physics=true
		var k=K.new();ck(k.initialize(scenario) and int(k.state.hyper_evolution_revision)==6,"init "+climate)
		var replay=R.new();replay.attach(k)
		var violations:int=0;var propulsion:int=0;var capped:int=0;var max_residual:int=0
		for i in range(1200):
			k.step_tick();replay.observed(k)
			for car in k.state.cars:
				var x:Dictionary=car.dynamics[E.KEY]
				if not E.valid(x):violations+=1
				if int(x.v8_j)>0:propulsion+=1
				if x.target_limited:capped+=1
				max_residual=maxi(max_residual,absi(int(x.residual_j)))
		ck(violations==0 and propulsion>0 and capped>0,"force/work budgets "+climate)
		print("ENERGY_OBSERVED ",JSON.stringify({"climate":climate,"violations":violations,"propulsion_samples":propulsion,"capped_samples":capped,"max_abs_residual_j":max_residual}))
		var copy=K.new();ck(copy.restore(k.checkpoint()),"restore "+climate)
		var sought=replay.seek(1200);ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay "+climate)
		k.step_ticks(50);copy.step_ticks(50);ck(copy.sporting_hash()==k.sporting_hash(),"continuation "+climate)
		var bad:Dictionary=k.checkpoint();bad.state.cars[0].dynamics[E.KEY].kers_j=12001
		ck(not copy.restore(bad),"reject impossible energy "+climate)
	var old=K.new();var old_s:Dictionary=S.create("ITA","Seco",2026);old_s.hyper30_physics=true
	ck(old.initialize(old_s) and not old.state.cars[0].dynamics.has(E.KEY),"legacy no ledger")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.energy_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==6 and ui.checkpoint_path==ui.SAVE301,"UI independent checkpoint")
	ck(ui.telemetry.text.contains("trabalho"),"energy telemetry")
	ui.queue_free();await process_frame
	print("HYPER301_ENERGY ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
