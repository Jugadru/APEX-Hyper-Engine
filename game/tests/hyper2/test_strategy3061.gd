extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const P=preload("res://experimental/hyper2/pit_strategy_3061.gd")
const R=preload("res://experimental/hyper2/replay.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
var checks:int=0
var errors:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var scenario:Dictionary=S.create("GBR","Seco",2026);scenario.hyper3061_physics=true
	scenario.hyper_weather=[{"tick":600,"water":2200},{"tick":1200,"water":4400},{"tick":1800,"water":2600}]
	var k=K.new();ck(k.initialize(scenario) and int(k.state.hyper_evolution_revision)==12,"init")
	var car:Dictionary=k.state.cars[0].duplicate(true)
	var compounds:Array=k.state.compounds
	car.tire="Médio"
	var emergency:Dictionary=P.evaluate(car,compounds,4400,20,50,100)
	ck(emergency.stop and emergency.compound=="Chuva","urgent heavy rain")
	P.accepted(car[P.KEY]);ck(P.valid(car[P.KEY]),"accepted ledger")
	car.tire="Chuva";car.dynamics.wear_micro=0;car.dynamics.tire_temp_centi=6800
	ck(not P.evaluate(car,compounds,3400,20,100,100).stop,"hysteresis retains wet")
	car.tire="Intermediário";car.dynamics.tire_temp_centi=7300
	ck(not P.evaluate(car,compounds,3400,20,150,100).stop,"hysteresis retains intermediate")
	car.tire="Chuva";car.dynamics.tire_temp_centi=6800
	ck(not P.evaluate(car,compounds,0,20,200,100).stop,"drying persistence")
	var drying:Dictionary=P.evaluate(car,compounds,0,20,250,100)
	ck(drying.stop and drying.compound=="Médio","persistent dry crossover")
	car[P.KEY]=P.initial()
	ck(not P.evaluate(car,compounds,0,2,50,5000).stop,"wait first sample")
	var expensive:Dictionary=P.evaluate(car,compounds,0,2,100,5000)
	ck(not expensive.stop and expensive.reason=="no_payback","pit cost prevents unprofitable stop")
	car[P.KEY]=P.initial();car.tire="Médio";car.dynamics.tire_temp_centi=9000
	ck(not P.evaluate(car,["Médio"],4400,10,50,100).stop,"unavailable tyre protected")
	var replay=R.new();replay.attach(k)
	for i in range(2000):k.step_tick();replay.observed(k)
	ck(k.state.cars.all(func(row:Dictionary)->bool:return P.valid(row[P.KEY])),"all strategy ledgers valid")
	var copy=K.new();ck(copy.restore(k.checkpoint()),"restore")
	var sought=replay.seek(2000);ck(sought!=null and sought.sporting_hash()==k.sporting_hash(),"replay")
	k.step_ticks(50);copy.step_ticks(50);ck(k.sporting_hash()==copy.sporting_hash(),"continuation")
	var bad:Dictionary=k.checkpoint();bad.state.cars[0][P.KEY].streak=4
	ck(not copy.restore(bad),"reject malformed strategy")
	var legacy=K.new();var old:Dictionary=S.create("GBR","Seco",2026);old.hyper306_physics=true
	ck(legacy.initialize(old) and not legacy.state.cars[0].has(P.KEY),"legacy isolated")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.strategy_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==12 and ui.checkpoint_path==ui.SAVE3061,"separate UI mode")
	ck(ui.telemetry.text.contains("ganho"),"strategy telemetry")
	ui.queue_free();await process_frame
	print("HYPER3061_STRATEGY ",JSON.stringify({"checks":checks,"failures":errors,"status":"PASS" if errors.is_empty() else "FAIL"}))
	quit(0 if errors.is_empty() else 1)
