extends SceneTree
const Scenario = preload("res://experimental/hyper/scenario.gd")
const Kernel = preload("res://experimental/hyper2/kernel.gd")
const TICKS = 100
const SEED = 2026
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rows: Array = []
	for spec in [["ITA","Seco"],["GBR","Chuva intensa"]]:
		var s: Dictionary = Scenario.create(str(spec[0]),str(spec[1]),SEED)
		if s.is_empty(): quit(1); return
		s.hyper301_physics=true
		var k = Kernel.new()
		if not k.initialize(s): quit(1); return
		var start_ms: int = int(k.state.clock_ms)
		var initial: Array = []
		for car in k.state.cars:
			initial.append({"id":int(car.id),"name":str(car.name),"team":str(car.team),"grid":int(car.grid),"tire":str(car.tire),"progress_units":int(car.progress_units)})
		initial.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.id)<int(b.id))
		var start: int = Time.get_ticks_usec()
		if k.step_ticks(TICKS)!=TICKS: quit(1); return
		var elapsed: int = Time.get_ticks_usec()-start
		var final: Array = []
		for car in k.state.cars:
			final.append({"id":int(car.id),"progress_units":int(car.progress_units)})
		final.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.id)<int(b.id))
		rows.append({"track":str(spec[0]),"weather":str(spec[1]),"seed":SEED,"ticks":int(k.state.tick),
			"elapsed_sim_ms":int(k.state.clock_ms)-start_ms,"initial":initial,"length_mm":s.lap_length_mm,
			"final":final,"hash":k.sporting_hash(),"elapsed_cpu_usec":elapsed,"commands":[]})
	print("APEX_BRIDGE_RESULT ",JSON.stringify({"engine":"Hyper301","rows":rows}))
	quit(0)
