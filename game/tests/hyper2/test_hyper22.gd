extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const P=preload("res://experimental/hyper2/powertrain_22.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok: errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	ck(P.torque_nm(13000)==310 and P.torque_nm(18001)==0,"curve")
	ck(P.raw_rpm(70000,7)>12000 and P.raw_rpm(70000,7)<12200,"rpm units")
	var shift:Dictionary=P.evaluate(P.initial(),36000,1000,510000,60000,30000,false,200)
	ck(int(shift.gear)==2 and int(shift.shift_cut_ms)==60,"shift cut")
	ck(int(shift.kers_used_j)<=12000 and int(shift.kers_used_j)>0,"bounded KERS")
	ck(P.evaluate(P.initial(),36000,1000,510000,60000,30000,true,200).engine_force_n==0,"brake no drive")
	var legacy=K.new()
	var scenario:Dictionary=S.create("ITA","Seco",2026)
	ck(legacy.initialize(scenario),"legacy")
	ck(int(legacy.state.hyper_evolution_revision)==2 and not legacy.state.cars[0].dynamics.has(P.KEY),"legacy default")
	var k=K.new();scenario.hyper22_physics=true
	ck(k.initialize(scenario),"advanced init")
	ck(int(k.state.hyper_evolution_revision)==3 and k.state.cars.size()==24,"revision and roster")
	var r=R.new();r.attach(k)
	var hashes:Dictionary={}
	var id:int=int(k.state.cars[0].id)
	var previous:Dictionary={}
	for t in range(701):
		if t==10:
			var cmd:Dictionary={"type":"set_pace","source":"Manual","car_id":id,"pace":"Atacar"}
			ck(bool(k.submit(cmd).accepted),"manual pace");r.record(cmd,t)
		if t in [10,350,700]:hashes[t]=k.sporting_hash()
		if t==700:break
		k.step_tick();r.observed(k)
		for car in k.state.cars:
			var d:Dictionary=car.dynamics
			var key:int=int(car.id)
			if previous.has(key) and int(d.distance_mm)<int(previous[key]):
				ck(false,"reverse motion")
			previous[key]=int(d.distance_mm)
	ck(k.state.cars.all(func(car:Dictionary)->bool:return P.valid(car.dynamics[P.KEY])),"24 powertrain states")
	ck(k.state.cars.any(func(car:Dictionary)->bool:return int(car.dynamics[P.KEY].gear)>1),"gears used")
	ck(k.state.cars.all(func(car:Dictionary)->bool:return int(car.hyper.kers_j)>=0 and int(car.hyper.kers_j)<=400000),"KERS reservoir")
	var hash_value:String=k.sporting_hash()
	var restored=K.new();ck(restored.restore(k.checkpoint()),"checkpoint")
	k.step_ticks(50);restored.step_ticks(50);ck(restored.sporting_hash()==k.sporting_hash(),"checkpoint parity")
	for t in hashes:
		var seek=r.seek(t);ck(seek!=null and seek.sporting_hash()==hashes[t],"replay "+str(t))
	ck(hash_value==hashes[700],"live hash at 700")
	var broken:Dictionary=k.checkpoint();broken.state.cars[0].dynamics[P.KEY].gear=8
	ck(not restored.restore(broken),"bad gear rejected")
	legacy.step_ticks(50);ck(restored.restore(legacy.checkpoint()),"old checkpoint accepted")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.physics_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==3 and ui.checkpoint_path==ui.SAVE22,"UI opt in & separate save")
	ck(ui.telemetry.text.contains("rpm"),"read-only telemetry")
	ui.queue_free();await process_frame
	print("HYPER22_GAME ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
