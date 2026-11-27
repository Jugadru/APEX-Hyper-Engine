extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const T=preload("res://experimental/hyper2/tyres_304.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var x:Dictionary=T.prepare(T.initial(),800,4000,0,0,1800)
	T.allocate(x,0,int(x.front_grip_n)+int(x.rear_grip_n))
	ck(T.valid(x) and x.normal_n==11848,"static normal load")
	ck(x.drive_limit_n==x.rear_reserve_n,"RWD axle limit")
	var brake:Dictionary=T.prepare(x,800,4000,-10000,0,1800)
	var accel:Dictionary=T.prepare(x,800,4000,10000,0,1800)
	ck(int(brake.fl)+int(brake.fr)>int(accel.fl)+int(accel.fr),"longitudinal transfer")
	var left:Dictionary=T.prepare(x,800,4000,0,14000,1800)
	var right:Dictionary=T.prepare(x,800,4000,0,-14000,1800)
	ck(left.fr>left.fl and right.fl>right.fr and left.rr>left.rl,"signed lateral transfer")
	ck(int(left.front_grip_n)+int(left.rear_grip_n)<=int(x.front_grip_n)+int(x.rear_grip_n),"load sensitivity")
	T.allocate(left,9000,int(left.front_grip_n)+int(left.rear_grip_n))
	ck(T.valid(left) and left.drive_limit_n<x.drive_limit_n,"combined axle budget")
	var forward:Dictionary=T.prepare(T.initial({"brake_bias":660}),800,4000,-10000,0,1800)
	var balanced:Dictionary=T.prepare(T.initial({"brake_bias":480}),800,4000,-10000,0,1800)
	T.allocate(forward,0,50000);T.allocate(balanced,0,50000)
	ck(forward.brake_limit_n!=balanced.brake_limit_n,"brake bias affects limit")
	for weather in ["Seco","Chuva intensa"]:
		var k=K.new();var s:Dictionary=S.create("ITA",weather,2026);s.hyper304_physics=true
		ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==9,"init "+weather)
		var replay=R.new();replay.attach(k)
		var violations:int=0;var samples:int=0;var transfer_samples:int=0
		for i in range(1200):
			k.step_tick();replay.observed(k)
			for car in k.state.cars:
				var w:Dictionary=car.dynamics[T.KEY]
				var d:Dictionary=car.dynamics.dynamics_23
				if not T.valid(w) or int(d.long_used_n)>int(d.long_limit_n):violations+=1
				if int(w.normal_n)>0:samples+=1
				if absi(int(w.lat_transfer_n))>0:transfer_samples+=1
		ck(violations==0 and samples>0 and transfer_samples>0,"physical budgets "+weather)
		print("TYRE304_OBSERVED ",JSON.stringify({"weather":weather,"samples":samples,"transfer_samples":transfer_samples,"violations":violations}))
		var copy=K.new();ck(copy.restore(k.checkpoint()),"restore "+weather)
		var seek=replay.seek(1200);ck(seek!=null and seek.sporting_hash()==k.sporting_hash(),"replay "+weather)
		k.step_ticks(50);copy.step_ticks(50);ck(copy.sporting_hash()==k.sporting_hash(),"continuation "+weather)
		var broken:Dictionary=k.checkpoint();broken.state.cars[0].dynamics[T.KEY].fl=-1
		ck(not copy.restore(broken),"reject invalid load "+weather)
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.tyre_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==9 and ui.checkpoint_path==ui.SAVE304,"UI separate mode")
	ck(ui.telemetry.text.contains("cargas FL/FR/RL/RR"),"four wheel telemetry")
	ui.queue_free();await process_frame
	print("HYPER304_TYRES ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
