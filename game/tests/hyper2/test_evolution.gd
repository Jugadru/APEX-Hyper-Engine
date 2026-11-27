extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const I=preload("res://experimental/hyper2/race_intelligence.gd")
var n:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	n+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var k=K.new(); ck(k.initialize(S.create("ITA","Seco",2026)),"initialize")
	ck(k.state.cars.size()==24,"roster")
	ck(I.sample(1,2,3,4,5)==I.sample(1,2,3,4,5),"seed reproducible")
	ck(I.sample(1,2,3,4,5)!=I.sample(1,2,3,4,6),"channel separation")
	ck(I.sample(1,2,3,4,5)!=I.sample(4294967297,2,3,4,5),"high seed bits")
	k.step_ticks(700)
	var c:Dictionary=k.state.cars[0]
	ck(c.evolution.lap_times.size()==int(c.laps_done),"lap timings")
	var before:String=k.sporting_hash(); var report:Dictionary=k.strategy_report(int(c.id))
	ck(report.cases.size()==3,"three windows")
	ck(k.sporting_hash()==before,"engineer read only")
	var cp:Dictionary=k.checkpoint(); var r=K.new(); ck(r.restore(cp),"checkpoint")
	k.step_ticks(200); for i in range(200): r.step_tick()
	ck(r.sporting_hash()==k.sporting_hash(),"tick parity")
	var old=preload("res://experimental/hyper/kernel.gd").new(); old.initialize(S.create("ITA","Seco",2026)); ck(not r.restore(old.checkpoint()),"revision gate")
	var broken:Dictionary=k.checkpoint(); broken.state.cars[0].evolution.error_left=999; ck(not r.restore(broken),"invalid recovery rejected")
	var f=K.new(); var scenario:Dictionary=S.create("ITA","Seco",42); scenario.hyper_errors_enabled=false; f.initialize(scenario); f.step_ticks(300)
	var actor:Dictionary=f.state.cars[0]; actor.evolution.error_kind="LOCK_UP"; actor.evolution.error_left=12; actor.evolution.error_total=12; actor.evolution.error_ref_speed=int(actor.dynamics.speed_mm_s)
	var d0:int=int(actor.dynamics.distance_mm); f.step_ticks(12)
	ck(int(actor.dynamics.distance_mm)>=d0,"no backwards motion")
	ck(int(actor.evolution.error_left)==0,"recovery completion")
	ck(f.state.events.any(func(e:Dictionary)->bool:return e.type=="hyper_error_recovered"),"recovery event")
	print("EVOLUTION ",JSON.stringify({"checks":n,"failures":failures})); quit(0 if failures.is_empty() else 1)
