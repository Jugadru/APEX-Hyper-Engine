extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const W=preload("res://experimental/hyper2/wet_racecraft_3064.gd")
const T=preload("res://experimental/hyper/traffic.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var s:Dictionary=S.create("GBR","Chuva intensa",2026);s.hyper3064_physics=true;s.hyper_errors_enabled=false
	var k=K.new();ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==15,"rev15 init")
	var car:Dictionary=k.state.cars[0].duplicate(true)
	var defender:Dictionary=k.state.cars[1].duplicate(true)
	for row in [car,defender]:
		row.finished=false;row.pit_stage="TRACK";row.pace="Normal";row.driver.fatigue=0;row.evolution.error_left=0;row.mega_30.neutral=false
		row.racecraft=T.initial_state()
	car.racecraft_305.initiative=850;car.wet_303.control=90;car.wet_303.confidence=1000;car.wet_303.observed_water=5000
	car.dynamics.fuel_g=50000;car.dynamics.wear_micro=0;car.dynamics.dynamics_23.reserve_permille=600;car.dynamics.dynamics_23.saturated=false
	car.dynamics.tyres_304.normal_n=8000;car.dynamics.tyres_304.front_grip_n=6000;car.dynamics.tyres_304.rear_grip_n=6000;car.dynamics.tyres_304.front_reserve_n=3000;car.dynamics.tyres_304.rear_reserve_n=3000
	car.dynamics.distance_mm=100000;defender.dynamics.distance_mm=110200;car.dynamics.speed_mm_s=40000;defender.dynamics.speed_mm_s=40000
	car.racecraft.phase="PREPARE";car.racecraft.target_id=int(defender.id);defender.pace="Conservar"
	var profile:Array=[{"start_mm":0,"radius_mm":1000000,"curvature":0},{"start_mm":500000,"radius_mm":1000000,"curvature":0}]
	var lap:int=1000000
	ck(W.window(car,defender,10200,0,5000),"matched speed at following floor")
	ck(not W.window(car,defender,9900,0,5000),"never below existing following floor")
	ck(not W.window(car,defender,34000,3000,5000),"rejected early extension")
	ck(not W.window(car,defender,10200,1200,5000),"excess closing blocked")
	ck(not W.window(car,defender,10200,-151,5000),"opening gap blocked")
	ck(not W.window(car,defender,10200,0,0),"dry unchanged")
	ck(W.reason(car,defender,profile,lap,100000,10200,0,5000)=="eligible","safe close-follow commitment")
	var roster:Array=[car,defender];var before:Array=roster.duplicate(true)
	var legacy:Dictionary=T.plan(roster,profile,lap,10,5000)
	var candidate:Dictionary=T.plan(roster,profile,lap,10,5000,true)
	ck(legacy.states[int(car.id)].phase=="PREPARE" and candidate.states[int(car.id)].phase=="ATTACK","actual resolver close-follow attack only when enabled")
	ck(candidate.transitions.any(func(e:Dictionary)->bool:return e.reason=="wet_follow_clear_corridor"),"causal event reason")
	var audit:Dictionary={"enabled":true}
	ck(T.plan(roster,profile,lap,10,5000,true,audit)==candidate,"audit does not change plan")
	ck(int(audit.get("follow_gate:eligible",0))==1 and int(audit.get("follow_reason:eligible",0))==1,"audit records real gate and reason")
	ck(W.gate_reason(car,defender,9900,0,5000)=="below_floor","explicit failed gate")
	ck(roster==before,"read-only resolver")
	roster.reverse();ck(T.plan(roster,profile,lap,10,5000,true)==candidate,"stable roster ordering")
	ck(T.plan(roster,profile,lap,10,0,true)==T.plan(roster,profile,lap,10,0),"dry parity")
	car.dynamics.tyres_304.rear_reserve_n=100
	ck(W.reason(car,defender,profile,lap,100000,10200,0,5000)=="reserve","rear axle protection")
	car.dynamics.tyres_304.rear_reserve_n=3000
	var tight:Array=[{"start_mm":0,"radius_mm":50000,"curvature":20000},{"start_mm":500000,"radius_mm":50000,"curvature":20000}]
	ck(W.reason(car,defender,tight,lap,100000,10200,0,5000)=="geometry","tight corner protection")
	car.wet_303.observed_water=3000;ck(not W.window(car,defender,10200,0,5000),"weather adaptation guard")
	car.wet_303.observed_water=5000;car.mega_30.neutral=true
	ck(not W.window(car,defender,10200,0,5000),"neutralization guard")
	car.mega_30.neutral=false
	defender.racecraft.lane="LEFT";ck(not W.window(car,defender,10200,0,5000),"not a same-lane following case");defender.racecraft.lane="CENTER"
	var left:Dictionary=k.state.cars[2].duplicate(true);var right:Dictionary=k.state.cars[3].duplicate(true)
	for blocker in [left,right]:
		blocker.finished=false;blocker.pit_stage="TRACK";blocker.pace="Conservar";blocker.racecraft=T.initial_state();blocker.dynamics.distance_mm=100000;blocker.dynamics.speed_mm_s=40000
	left.racecraft.lane="LEFT";right.racecraft.lane="RIGHT"
	ck(T.plan([car,defender,left,right],profile,lap,10,5000,true).states[int(car.id)].phase!="ATTACK","occupied corridors block close-follow attack")
	var mirror=K.new();ck(mirror.initialize(s),"audit parity mirror")
	k.wet_racecraft_audit={"enabled":true}
	var replay=R.new();replay.attach(k)
	for i in range(900):k.step_tick();replay.observed(k)
	mirror.step_ticks(900)
	ck(k.sporting_hash()==mirror.sporting_hash(),"audit excluded from sporting state")
	ck(int(k.wet_racecraft_audit.get("attempts",0))==int(k.state.racecraft_attempts) and int(k.wet_racecraft_audit.get("passes",0))==int(k.state.racecraft_passes),"audit reconciles sporting totals")
	var copy=K.new();ck(copy.restore(k.checkpoint()),"checkpoint")
	var sought=replay.seek(900);ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay")
	k.step_ticks(50);copy.step_ticks(50);ck(k.sporting_hash()==copy.sporting_hash(),"continuation")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.wet_racecraft_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==15 and ui.checkpoint_path==ui.SAVE3064,"independent UI mode")
	ui.queue_free();await process_frame
	print("HYPER3064_WET_RACECRAFT ",JSON.stringify({"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
