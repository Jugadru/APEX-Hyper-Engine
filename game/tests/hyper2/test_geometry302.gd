extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const G=preload("res://experimental/hyper2/geometry_302.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
const R=preload("res://experimental/hyper2/replay.gd")
const View=preload("res://experimental/hyper2/view_3d.gd")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	for track in data.tracks:
		var code:String=str(track.code)
		var s:Dictionary=S.create(code,"Seco",2026);s.hyper302_physics=true
		var k=K.new()
		if not k.initialize(s):
			ck(false,"init "+code);continue
		var p:Array=k.state.track_profile;var lap:int=int(k.state.lap_length_mm)
		ck(G.valid(p,lap) and p==G.build(s.geometry_points,lap),"canonical profile "+code)
		ck(G.curvature_at(p,lap,0)==G.curvature_at(p,lap,lap) and G.curvature_at(p,lap,-1)==G.curvature_at(p,lap,lap-1),"wrap "+code)
		ck(k.step_ticks(100)==100 and k.state.cars.size()==24,"motion "+code)
		var copy=K.new();ck(copy.restore(k.checkpoint()),"restore "+code)
		k.step_ticks(10);copy.step_ticks(10);ck(k.sporting_hash()==copy.sporting_hash(),"parity "+code)
		print("GEOMETRY_TRACK ",JSON.stringify({"code":code,"samples":p.size(),"lap_mm":lap}))
	var scenario:Dictionary=S.create("ITA","Chuva intensa",2026);scenario.hyper302_physics=true
	var probe=K.new();ck(probe.initialize(scenario),"wet init")
	var replay=R.new();replay.attach(probe)
	for tick in range(600):probe.step_tick();replay.observed(probe)
	var seek=replay.seek(600);ck(seek!=null and seek.sporting_hash()==probe.sporting_hash(),"wet replay")
	var broken:Dictionary=probe.checkpoint();broken.state.track_profile[0].curvature=999999
	ck(not probe.restore(broken),"reject malformed curvature")
	var ui=UI.instantiate();root.add_child(ui);await process_frame
	ui.geometry_choice.button_pressed=true;ui._start();ui.running=false;ui.k.step_ticks(100);ui._redraw()
	ck(int(ui.k.state.hyper_evolution_revision)==7 and ui.checkpoint_path==ui.SAVE302,"UI independent save")
	var profile:Array=ui.k.state.track_profile;var ui_lap:int=int(ui.k.state.lap_length_mm)
	ck(ui.map_view.points.size()==profile.size() and int(ui.map_view.total)==ui_lap,"map canonical route")
	# Pure projection adapter test: no renderer or GPU required.
	var view=View.new()
	view.total=float(ui_lap)
	for sample in profile:
		view.points.append(Vector2(float(sample.x)/1000.0,float(sample.y)/1000.0));view.lengths.append(float(sample.start_mm))
	var before:String=ui.k.sporting_hash()
	var exact:bool=true
	for sample in profile:
		var target:=Vector2(float(sample.x)/1000.0,float(sample.y)/1000.0)
		if view.point(float(sample.start_mm)/float(ui_lap)).distance_to(target)>0.01:exact=false
	ck(exact and view.point(0.0).distance_to(view.point(1.0))<0.01,"3D sample positions and seam")
	ck(ui.k.sporting_hash()==before,"presentation read only")
	view.free();ui.queue_free();await process_frame
	print("HYPER302_GEOMETRY ",JSON.stringify({"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
