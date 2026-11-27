extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const W=preload("res://experimental/hyper2/wet_303.gd")
const V=preload("res://experimental/apex2/vehicle_dynamics.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var low:Dictionary=W.initial(50,{"awareness":500,"patience":500})
	var high:Dictionary=W.initial(98,{"awareness":980,"patience":980})
	ck(W.margin(920,low,0)==920 and W.margin(920,high,0)==920,"dry identical")
	ck(W.throttle(910,low,0)==910 and W.throttle(910,high,0)==910,"dry throttle identical")
	low.observed_water=4000;high.observed_water=4000
	ck(W.margin(900,high,4000)>W.margin(900,low,4000),"skill wet margin")
	ck(W.risk_multiplier(high,4000)<W.risk_multiplier(low,4000),"skill wet risk")
	ck(W.throttle(1000,high,4000)>W.throttle(1000,low,4000),"throttle control")
	var a:Dictionary=W.initial(50,{"awareness":500,"patience":500})
	var b:Dictionary=W.initial(98,{"awareness":980,"patience":980})
	W.update(a,4000);W.update(b,4000)
	ck(int(b.observed_water)>int(a.observed_water) and int(a.confidence)<1000,"adaptation and confidence")
	var s:Dictionary=S.create("GBR","Chuva intensa",2026);s.hyper303_physics=true
	s.hyper_weather=[{"tick":100,"water":2400},{"tick":300,"water":0},{"tick":600,"water":4500}]
	var k=K.new();ck(k.initialize(s) and int(k.state.hyper_evolution_revision)==8,"init")
	var car:Dictionary=k.state.cars[0].duplicate(true)
	car.wet_303=high.duplicate();car.dynamics.dynamics_23.reserve_permille=600;car.dynamics.dynamics_23.saturated=false
	ck(W.attack_reason(car,200000,16000,2500,4000)=="eligible","safe wet opportunity")
	ck(W.attack_reason(car,50000,16000,2500,4000)=="geometry","tight corner blocked")
	ck(W.attack_reason(car,200000,2000,2500,4000)=="gap","unsafe gap blocked")
	car.mega_30.neutral=true;ck(W.attack_reason(car,200000,16000,2500,4000)=="neutral","neutralization blocked")
	car.mega_30.neutral=false
	# Equal car and environment, only wet ratings swapped.
	var profile:Array=k.state.track_profile;var lap:int=int(k.state.lap_length_mm)
	var x:Dictionary=car.duplicate(true);var y:Dictionary=car.duplicate(true)
	x.wet_303=low.duplicate();y.wet_303=high.duplicate()
	x.dynamics.speed_mm_s=30000;y.dynamics.speed_mm_s=30000
	x.tire="Chuva";y.tire="Chuva"
	for i in range(100):V.advance(x,profile,lap,4000,2000);V.advance(y,profile,lap,4000,2000)
	ck(int(y.dynamics.distance_mm)>int(x.dynamics.distance_mm),"equal car wet skill effect")
	var replay=R.new();replay.attach(k)
	for tick in range(900):k.step_tick();replay.observed(k)
	ck(k.state.cars.all(func(row:Dictionary)->bool:return W.valid(row.wet_303)),"24 valid driver profiles")
	ck(W.valid_counters(k.state.wet_attack_reasons),"diagnostics")
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore")
	var seek=replay.seek(900);ck(seek!=null and seek.sporting_hash()==k.sporting_hash(),"replay")
	k.step_ticks(50);copy.step_ticks(50);ck(k.sporting_hash()==copy.sporting_hash(),"continuation")
	var bad:Dictionary=k.checkpoint();bad.state.cars[0].wet_303.control=101;ck(not copy.restore(bad),"reject invalid skill")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.wet_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==8 and ui.checkpoint_path==ui.SAVE303,"UI isolated mode")
	ck(ui.telemetry.text.contains("confiança"),"wet telemetry")
	ui.queue_free();await process_frame
	print("HYPER303_WET ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
