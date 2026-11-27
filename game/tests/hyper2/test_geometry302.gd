extends SceneTree
const K=preload("res://experimental/hyper2/kernel.gd")
const S=preload("res://experimental/hyper/scenario.gd")
const G=preload("res://experimental/hyper2/geometry_302.gd")
const UI=preload("res://experimental/hyper2/console.tscn")
const R=preload("res://experimental/hyper2/replay.gd")
const View=preload("res://experimental/hyper2/view_3d.gd")
const V=preload("res://experimental/apex2/vehicle_dynamics.gd")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
# Unoptimized revision 7 preview, kept in QA only as the reference oracle.
func reference_preview(profile:Array,lap:int,pos:int,mass:int,mu:int,downforce:int,speed:int,margin:int)->int:
	var idx:int=G.index(profile,pos)
	var current:int=G.radius_at(profile,lap,pos)
	var cap:int=V.MAX_V_MM_S
	for ahead in range(mini(128,profile.size())):
		var sample:Dictionary=profile[(idx+ahead)%profile.size()]
		var distance:int=0 if ahead==0 else posmod(int(sample.start_mm)-pos,lap)
		if distance>850000:break
		var radius:int=current if ahead==0 else int(sample.radius_mm)
		var limit:int=V._corner_cap_mm_s(radius,mass,mu,downforce)
		if radius<V.MAX_RADIUS_MM:limit=int(limit*margin/1000)
		var decel:int=maxi(2500,int(V._grip_force_n(mass,mini(speed,limit),mu,downforce)*1000/mass))
		decel=maxi(1500,int(decel*800/1000))
		cap=mini(cap,mini(V.MAX_V_MM_S,V.integer_sqrt(limit*limit+2*decel*distance)))
	return cap

func run()->void:
	var root_ok:bool=true
	for n in [0,1,2,106000,4503599627370496,4503599627370495,1000000000000000]:
		if V.exact_root_fast(n)!=V.integer_sqrt(n):root_ok=false
	for n in range(1,100000,97):
		for delta in [-1,0,1]:
			var value:int=n*n+delta
			if V.exact_root_fast(value)!=V.integer_sqrt(value):root_ok=false
	ck(root_ok,"exact integer root boundaries")
	var preview_cases:int=0
	var preview_errors:int=0
	var reference_us:int=0
	var optimized_us:int=0
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
		# Both implementations measured in the same process with identical
		# geometry, mass, grip, aero, speed and margin. No timing gate.
		for j in range(32):
			var position:int=int(j*lap/32)
			for grip in [650,1400,2050]:
				var mass:int=650+j*4
				var speed:int=15000+j*2800
				var margin:int=880+j%8*10
				var begin:int=Time.get_ticks_usec()
				var expected:int=reference_preview(p,lap,position,mass,grip,2650,speed,margin)
				reference_us+=Time.get_ticks_usec()-begin
				begin=Time.get_ticks_usec()
				var actual:int=V.canonical_preview(p,lap,position,G.index(p,position),G.radius_at(p,lap,position),mass,grip,2650,speed,margin)
				optimized_us+=Time.get_ticks_usec()-begin
				preview_cases+=1
				if actual!=expected:preview_errors+=1
		ck(k.step_ticks(100)==100 and k.state.cars.size()==24,"motion "+code)
		var copy=K.new();ck(copy.restore(k.checkpoint()),"restore "+code)
		k.step_ticks(10);copy.step_ticks(10);ck(k.sporting_hash()==copy.sporting_hash(),"parity "+code)
		print("GEOMETRY_TRACK ",JSON.stringify({"code":code,"samples":p.size(),"lap_mm":lap}))
	ck(preview_cases==1920 and preview_errors==0,"exact preview equivalence across 20 tracks")
	print("GEOMETRY_PREVIEW_BENCH ",JSON.stringify({"cases":preview_cases,"mismatches":preview_errors,"reference_us":reference_us,"optimized_us":optimized_us}))
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
