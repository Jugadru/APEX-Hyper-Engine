extends SubViewportContainer
## Adapter reusing the original procedural cars, scenery, cameras and visual solver.
## No writable reference to the kernel. Hyper pits use stationary loss, not pit geometry.
const Track=preload("res://scripts/track_3d.gd")
var viewport_3d: SubViewport
var track_3d: Node3D
var points: PackedVector2Array=[]
var lengths: PackedFloat64Array=[]
var total: float=0.0
var team_colors: Dictionary={}
var camera_style: String="aerial"
var previous: Dictionary={}
var targets: Dictionary={}
var selected_id: int=-1
var age: float=0.0
var duration: float=0.25
func _ready()->void:
	stretch=true
	viewport_3d=SubViewport.new(); viewport_3d.own_world_3d=true; viewport_3d.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE; add_child(viewport_3d)
	track_3d=Track.new(); viewport_3d.add_child(track_3d)
func configure(raw: Array,title_text: String,teams: Array,colors: Dictionary)->void:
	points.clear(); lengths.clear(); total=0; previous.clear(); targets.clear(); team_colors=colors.duplicate()
	for p in raw:
		if p is Array and p.size()==2:
			var v:=Vector2(float(p[0])*1100.0,float(p[1])*900.0)
			if points.is_empty() or points[-1]!=v: points.append(v)
	if points.size()>2 and points[0]==points[-1]: points.remove_at(points.size()-1)
	if points.size()<3: return
	# Core 2's closed Chaikin road construction, in its expected coordinate space.
	for iteration in range(3):
		var rounded: PackedVector2Array=[]
		for i in range(points.size()):
			var a: Vector2=points[i]; var b: Vector2=points[(i+1)%points.size()]
			rounded.append(a.lerp(b,0.25)); rounded.append(a.lerp(b,0.75))
		points=rounded
	for i in range(points.size()):
		lengths.append(total); total+=points[i].distance_to(points[(i+1)%points.size()])
	var route: PackedVector2Array=points.duplicate(); route.append(points[0]); track_3d.set_track_data(route,title_text,teams)
func point(progress: float)->Vector2:
	if total<=0: return Vector2.ZERO
	var target: float=fposmod(progress,1.0)*total
	var i: int=clampi(lengths.bsearch(target,true)-1,0,points.size()-1)
	var b: Vector2=points[(i+1)%points.size()]
	return points[i].lerp(b,clampf((target-lengths[i])/maxf(0.00001,points[i].distance_to(b)),0,1))
func feed(cars: Array,id: int,interval: float=0.25)->void:
	previous=targets; targets={}; age=0.0; duration=maxf(0.01,interval); selected_id=id
	for car in cars:
		if car.finished or car.pit_stage!="TRACK": continue
		var lane: float=float({"LEFT":-2.2,"RIGHT":2.2,"CENTER":0.0}.get(str(car.racecraft.lane),0.0))
		targets[int(car.id)]={"id":int(car.id),"team":str(car.team),"color":str(team_colors.get(str(car.team),"#bbbbbb")),"progress":float(car.progress_units)/1000000.0,"race_lane":lane,"grid":int(car.grid),"tire":str(car.tire),"drs_active":bool(car.hyper.drs_active),"combat_target_id":int(car.racecraft.target_id),"combat_state":str({"ATTACK":"attacking","SIDE_BY_SIDE":"duel","PREPARE":"preparing"}.get(str(car.racecraft.phase),"clear")),"finished":false}
func _process(delta:float)->void:
	if not is_visible_in_tree() or total<=0 or targets.is_empty(): return
	age+=delta
	var alpha: float=clampf(age/duration,0,1)
	var field: Array=[]; var selected: Dictionary={}; var rival: Variant=null
	for id in targets:
		var row: Dictionary=targets[id].duplicate(); var old: Dictionary=previous.get(id,row)
		# Interpolate only within the observed interval. No extrapolation across a pit/seek.
		if absf(float(row.progress)-float(old.progress))<0.20:
			row.progress=lerpf(float(old.progress),float(row.progress),alpha)
			row.race_lane=lerpf(float(old.race_lane),float(row.race_lane),alpha)
		row.route_point=point(float(row.progress)); row.route_direction=(point(float(row.progress)+0.0008)-point(float(row.progress)-0.0008)).normalized()
		field.append(row)
		if int(id)==selected_id: selected=row
	track_3d.set_race_cars(field,selected_id,delta)
	if selected.is_empty(): selected=field[0]
	if targets.has(int(selected.combat_target_id)) and str(selected.combat_state) in ["attacking","duel"]: rival=point(float(targets[int(selected.combat_target_id)].progress))
	var style: String=camera_style
	if style=="director": style="battle" if rival!=null else "aerial"
	track_3d.set_broadcast_view(selected.route_point,selected.route_direction,rival,style,delta,int(selected.id))
