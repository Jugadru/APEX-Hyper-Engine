extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const D=preload("res://experimental/hyper2/dynamics_23.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok: errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var b:Dictionary=D.budget(10000,6000)
	ck(int(b.long_limit_n)==8000,"3-4-5 circle")
	ck(int(D.budget(10000,0).long_limit_n)==10000,"straight")
	ck(bool(D.budget(10000,15000).saturated),"unmet lateral demand exposed")
	var brake:Dictionary=D.loads(800,3000,-10000)
	var accel:Dictionary=D.loads(800,3000,10000)
	ck(int(brake.front_n)>int(accel.front_n),"load transfer direction")
	ck(int(brake.front_n)+int(brake.rear_n)==10848,"normal load conservation")
	ck(D.brake_force(40000,39000,800,200,10000,200)==3800,"proportional brake")
	ck(D.phase(1000000,200000,1000000)=="ENTRY" and D.phase(200000,1000000,1000000)=="APEX","track phases")
	var k=K.new();var s:Dictionary=S.create("ITA","Seco",2026);s.hyper23_physics=true
	ck(k.initialize(s),"init")
	ck(k.state.hyper_evolution_revision==4 and k.state.cars.size()==24,"revision")
	var r=R.new();r.attach(k)
	var old:Dictionary={};var hashes:Dictionary={};var violations:int=0
	for i in range(701):
		if i in [0,350,700]:hashes[i]=k.sporting_hash()
		if i==700:break
		k.step_tick();r.observed(k)
		for car in k.state.cars:
			var d:Dictionary=car.dynamics;var x:Dictionary=d[D.KEY];var id:int=int(car.id)
			if not D.valid(x) or int(x.long_used_n)*int(x.long_used_n)+int(x.lateral_alloc_n)*int(x.lateral_alloc_n)>int(x.grip_n)*int(x.grip_n):violations+=1
			if old.has(id) and int(d.distance_mm)<int(old[id]):violations+=1
			old[id]=int(d.distance_mm)
	ck(violations==0,"force budget and monotonic progress")
	ck(k.state.cars.any(func(c:Dictionary)->bool:return int(c.dynamics[D.KEY].front_n)>0),"physical load observed")
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore")
	k.step_ticks(50);copy.step_ticks(50);ck(k.sporting_hash()==copy.sporting_hash(),"continuation parity")
	for tick in hashes:
		var seek=r.seek(tick);ck(seek!=null and seek.sporting_hash()==hashes[tick],"replay "+str(tick))
	var bad:Dictionary=k.checkpoint();bad.state.cars[0].dynamics[D.KEY].long_limit_n=-1
	ck(not copy.restore(bad),"reject malformed budget")
	for rev in [2,3]:
		var previous=K.new();var scenario:Dictionary=S.create("ITA","Seco",2026);scenario.hyper22_physics=rev==3
		ck(previous.initialize(scenario) and copy.restore(previous.checkpoint()) and not copy.state.cars[0].dynamics.has(D.KEY),"legacy "+str(rev))
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.dynamics_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==4 and ui.checkpoint_path==ui.SAVE23,"UI opt-in and separate checkpoint")
	ck(ui.telemetry.text.contains("reserva"),"telemetry")
	ui.queue_free();await process_frame
	print("HYPER23_GAME ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
