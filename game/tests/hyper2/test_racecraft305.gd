extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const A=preload("res://experimental/hyper2/racecraft_305.gd")
const T=preload("res://experimental/hyper/traffic.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Dictionary=S.create("ITA","Chuva intensa",2026);s.hyper305_physics=true
	var k=K.new();ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==10,"init")
	var identities:Dictionary={}
	for row in k.state.cars:identities[str(row.racecraft_305)]=true
	ck(identities.size()>=20,"distinct named profiles")
	var other:Dictionary=S.create("ITA","Seco",2027);other.hyper305_physics=true
	var second=K.new();ck(second.initialize(other),"second seed")
	for row in k.state.cars:
		var matching:Array=second.state.cars.filter(func(c:Dictionary)->bool:return c.name==row.name)
		ck(matching.size()==1 and matching[0].racecraft_305==row.racecraft_305,"stable identity "+str(row.name))
	var car:Dictionary=k.state.cars[0].duplicate(true)
	car.pace="Normal";car.driver.fatigue=0;car.driver.intent="HOLD";car.evolution.error_left=0
	car.racecraft_305.initiative=850
	ck(A.approach(car,18000,0,4000),"matched-speed opportunity")
	var patient:Dictionary=car.duplicate(true);patient.racecraft_305.initiative=350
	ck(not A.approach(patient,18000,0,4000),"patient driver different decision")
	car.pace="Conservar";ck(not A.approach(car,18000,3000,4000),"conserve protects pace")
	car.pace="Normal";car.mega_30.neutral=true;ck(not A.approach(car,18000,3000,4000),"neutral blocks attack")
	car.mega_30.neutral=false
	var profile:Array=[{"start_mm":0,"radius_mm":1000000,"curvature":0},{"start_mm":500000,"radius_mm":1000000,"curvature":0}]
	var lap:int=1000000
	car.dynamics.tyres_304.normal_n=8000;car.dynamics.tyres_304.front_grip_n=6000;car.dynamics.tyres_304.rear_grip_n=6000;car.dynamics.tyres_304.front_reserve_n=3000;car.dynamics.tyres_304.rear_reserve_n=3000
	car.dynamics.dynamics_23.saturated=false;car.dynamics.dynamics_23.reserve_permille=600;car.wet_303.control=90
	ck(A.reason(car,profile,lap,100000,18000,0,5000)=="eligible","safe matched-speed commitment")
	car.dynamics.tyres_304.rear_reserve_n=100
	ck(A.reason(car,profile,lap,100000,18000,1500,5000)=="reserve","rear axle constraint")
	car.dynamics.tyres_304.rear_reserve_n=3000
	var defender:Dictionary=k.state.cars[1].duplicate(true)
	car.finished=false;defender.finished=false;car.pit_stage="TRACK";defender.pit_stage="TRACK"
	car.dynamics.distance_mm=100000;defender.dynamics.distance_mm=118000;car.dynamics.speed_mm_s=40000;defender.dynamics.speed_mm_s=40000
	car.racecraft=T.initial_state();car.racecraft.phase="PREPARE";car.racecraft.target_id=int(defender.id)
	defender.racecraft=T.initial_state();defender.pace="Conservar"
	var roster:Array=[car,defender];var original:Array=roster.duplicate(true)
	var plan:Dictionary=T.plan(roster,profile,lap,10,5000)
	ck(plan.states[int(car.id)].phase=="ATTACK","actual resolver attack")
	ck(roster==original,"resolver read only")
	roster.reverse();ck(T.plan(roster,profile,lap,10,5000)==plan,"roster permutation")
	car.dynamics.tyres_304.rear_reserve_n=100
	ck(T.plan(roster,profile,lap,10,5000).states[int(car.id)].phase!="ATTACK","resolver respects axle reserve")
	car.dynamics.tyres_304.rear_reserve_n=3000
	defender.pace="Normal";defender.driver.fatigue=0;defender.driver.intent="COVER_THREAT";defender.evolution.error_left=0
	# Both alternatives occupied at the attacker, but clear at the defender:
	# no ghost defensive move or event without a committed attack.
	var left:Dictionary=k.state.cars[2].duplicate(true);var right:Dictionary=k.state.cars[3].duplicate(true)
	for blocker in [left,right]:
		blocker.finished=false;blocker.pit_stage="TRACK";blocker.pace="Conservar"
		blocker.dynamics.distance_mm=100000;blocker.dynamics.speed_mm_s=40000;blocker.racecraft=T.initial_state()
	left.racecraft.lane="LEFT";right.racecraft.lane="RIGHT"
	var blocked:Dictionary=T.plan([car,defender,left,right],profile,lap,10,5000)
	ck(blocked.states[int(car.id)].phase!="ATTACK" and blocked.states[int(defender.id)].phase!="DEFEND","no orphan defense when both lanes blocked")
	ck(not blocked.transitions.any(func(e:Dictionary)->bool:return str(e.phase)=="DEFEND"),"no phantom defense event")
	var replay=R.new();replay.attach(k)
	for i in range(900):k.step_tick();replay.observed(k)
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore")
	var sought=replay.seek(900);ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay")
	k.step_ticks(50);copy.step_ticks(50);ck(k.sporting_hash()==copy.sporting_hash(),"continuation")
	var bad:Dictionary=k.checkpoint();bad.state.cars[0].racecraft_305.initiative=1001
	ck(not copy.restore(bad),"invalid identity")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.racecraft_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==10 and ui.checkpoint_path==ui.SAVE305,"independent UI mode")
	ck(ui.telemetry.text.contains("estilo"),"style telemetry")
	ui.queue_free();await process_frame
	print("HYPER305_RACECRAFT ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
