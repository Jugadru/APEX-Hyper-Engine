extends SceneTree
const Scenario = preload("res://experimental/hyper/scenario.gd")
const Kernel = preload("res://experimental/hyper2/kernel.gd")
const TICKS = 100
const SEED = 2026
func _initialize() -> void: call_deferred("run")
func fail(reason: String) -> void:
	printerr("LAB_BRIDGE_FAIL "+reason)
	quit(1)
func run() -> void:
	var rows: Array = []
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lab_bridge_grid.json"))
	for spec in [["ITA","Seco"],["GBR","Chuva intensa"]]:
		var s: Dictionary = Scenario.create(str(spec[0]),str(spec[1]),SEED)
		if s.is_empty(): fail("scenario unavailable"); return
		var native_initial: Array = s.cars.duplicate(true)
		var match_row: Dictionary = {}
		for row in fixture.rows:
			if str(row.track)==str(spec[0]) and str(row.weather)==str(spec[1]): match_row=row; break
		if match_row.is_empty() or int(match_row.seed)!=SEED or int(match_row.length_mm)!=int(s.lap_length_mm): fail("fixture scenario mismatch"); return
		var by_id: Dictionary = {}
		for row in match_row.initial: by_id[int(row.id)]=row
		for car in s.cars:
			var expected: Dictionary = by_id.get(int(car.id),{})
			if expected.is_empty(): fail("missing actor "+str(car.id)); return
			if int(car.grid)!=int(expected.grid): fail("grid rank mismatch "+str(car.id)); return
			for key in ["name","team","tire"]:
				if str(car[key])!=str(expected[key]): fail("actor mismatch "+str(car.id)+" "+key); return
			car.progress_units=int(expected.progress_units)
		s.hyper301_physics=true
		var k = Kernel.new()
		if not k.initialize(s): fail("kernel rejected matched scenario"); return
		var start_ms: int = int(k.state.clock_ms)
		var initial: Array = []
		for car in k.state.cars:
			initial.append({"id":int(car.id),"name":str(car.name),"team":str(car.team),"grid":int(car.grid),"tire":str(car.tire),"progress_units":int(car.progress_units)})
		initial.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.id)<int(b.id))
		var start: int = Time.get_ticks_usec()
		if k.step_ticks(TICKS)!=TICKS: fail("tick count"); return
		var elapsed: int = Time.get_ticks_usec()-start
		var final: Array = []
		for car in k.state.cars:
			final.append({"id":int(car.id),"progress_units":int(car.progress_units)})
		final.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.id)<int(b.id))
		rows.append({"track":str(spec[0]),"weather":str(spec[1]),"seed":SEED,"ticks":int(k.state.tick),
			"elapsed_sim_ms":int(k.state.clock_ms)-start_ms,"initial":initial,"native_initial":native_initial,"length_mm":s.lap_length_mm,
			"final":final,"hash":k.sporting_hash(),"elapsed_cpu_usec":elapsed,"commands":[]})
	print("APEX_BRIDGE_RESULT ",JSON.stringify({"engine":"Hyper301","rows":rows}))
	quit(0)
