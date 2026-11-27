extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const Q=preload("res://experimental/hyper2/quality.gd")
const T=preload("res://experimental/hyper/traffic.gd")
var n:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 n+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var k=K.new();ck(k.initialize(S.create("ITA","Seco",2026,"Ferrari",true)),"init")
 var r=R.new();r.attach(k);var id:int=int(k.state.cars[0].id);var hashes:Dictionary={}
 for t in range(3101):
  var cmd:Dictionary={}
  if t==10:cmd={"type":"schedule_pit","source":"Manual","car_id":id,"requested_lap":21,"compound":"Chuva","allow_double_stack":true}
  if t==100:cmd={"type":"set_pace","source":"Manual","car_id":id,"pace":"Atacar"}
  if t==120:cmd={"type":"set_auto","source":"Manual","car_id":id}
  if not cmd.is_empty():
   var accepted:bool=bool(k.submit(cmd).accepted);ck(accepted,"submit %s"%cmd.type)
   if accepted:r.record(cmd,t)
  if t in [10,120,2500,3100]:hashes[t]=k.sporting_hash()
  if t<3100:k.step_tick();r.observed(k)
 ck(r.anchors.size()==9 and r.anchors[0].tick==0,"nine anchors first retained")
 var live:String=k.sporting_hash()
 for t in hashes:
  var probe=r.seek(t);ck(probe!=null and probe.sporting_hash()==hashes[t],"seek %s"%t)
 ck(k.sporting_hash()==live,"seek read only")
 var old=preload("res://experimental/hyper/kernel.gd").new();ck(not old.restore(k.checkpoint()),"legacy rejects newer revision")
 var q=Q.new();var state:Dictionary=k.state.duplicate(true);state.cars[1].id=state.cars[0].id;state.cars[0].dynamics.wear_micro=1000001
 q.observe(state);q.observe(state);ck(q.report().observed_ticks==1,"dedup")
 ck(q.findings.get("duplicate_id",0)==1 and q.findings.get("wear_range",0)==1,"injected faults")
 ck(k.sporting_hash()==live,"observer read only")
 var own:Dictionary=k.state.cars[0].duplicate(true);var other:Dictionary=k.state.cars[1].duplicate(true);var lap:int=int(k.state.lap_length_mm)
 own.finished=false;other.finished=false;own.pit_stage="TRACK";other.pit_stage="TRACK";own.dynamics.distance_mm=lap+100000;other.dynamics.distance_mm=120000;own.dynamics.speed_mm_s=65000;other.dynamics.speed_mm_s=40000
 own.racecraft.phase="CRUISE";own.racecraft.cooldown_until=0;own.racecraft.target_id=-1;own.racecraft.lane="CENTER";other.racecraft.phase="CRUISE";other.racecraft.target_id=-1;other.racecraft.lane="CENTER"
 var profile:Array=[{"start_mm":0,"radius_mm":1000000}]
 var p:Dictionary=T.plan([own,other],profile,lap,3000)
 ck(bool(p.states[int(own.id)].get("lapping",false)) and int(p.states[int(own.id)].target_id)==int(other.id),"wrapped lapping target")
 own.racecraft=p.states[int(own.id)];own.racecraft.phase="ATTACK";own.racecraft.lane="LEFT";own.racecraft.phase_tick=3000;own.dynamics.distance_mm=lap+130000
 p=T.plan([own,other],profile,lap,3001)
 ck(p.transitions.any(func(e:Dictionary)->bool:return e.type=="hyper_lap_pass_confirmed"),"lapping event separated")
 print("REPLAY_QUALITY ",JSON.stringify({"checks":n,"failures":failures}));quit(0 if failures.is_empty() else 1)
