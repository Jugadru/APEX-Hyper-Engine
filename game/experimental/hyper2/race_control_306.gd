extends RefCounted
## Revision 11: monitored virtual neutralization. The existing mega timer
## remains the sole authority. Warnings are observations, not penalties.
const KEY:="race_control_306"
const Mega=preload("res://experimental/hyper2/mega_30.gd")
const CAP_MM_S:=Mega.CONTROL_CAP
const STEP_MS:=200
const GRACE_TICKS:=10
const TOLERANCE_MM:=2000

static func initial()->Dictionary:
	return {"phase":"GREEN","deployments":0,"total_ticks":0,"speed_warnings":0,"order_warnings":0,"cars":{},"reported_pairs":{}}

static func valid(x:Variant,roster:Array)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()) or x.phase not in ["GREEN","VSC"]:return false
	for key in ["deployments","total_ticks","speed_warnings","order_warnings"]:
		if typeof(x[key])!=TYPE_INT or int(x[key])<0 or int(x[key])>10000000:return false
	if not x.cars is Dictionary or not x.reported_pairs is Dictionary or x.cars.size()>roster.size() or x.reported_pairs.size()>276:return false
	var ids:Dictionary={}
	for car in roster:
		if not car is Dictionary or not car.has("id"):return false
		ids[str(car.id)]=true
	for id in x.cars:
		if not id is String or not ids.has(id):return false
		var row:Variant=x.cars[id]
		if not row is Dictionary or not row.has_all(["samples","delta_mm","warned"]):return false
		if typeof(row.samples)!=TYPE_INT or int(row.samples)<0 or int(row.samples)>Mega.CONTROL_TICKS:return false
		if typeof(row.delta_mm)!=TYPE_INT or absi(int(row.delta_mm))>2000000 or typeof(row.warned)!=TYPE_BOOL:return false
	for pair in x.reported_pairs:
		if not pair is String or x.reported_pairs[pair]!=true:return false
		var parts:PackedStringArray=pair.split(":")
		if parts.size()!=2 or not ids.has(parts[0]) or not ids.has(parts[1]) or int(parts[0])>=int(parts[1]):return false
	return true

static func eligible(car:Dictionary)->bool:
	return not bool(car.finished) and str(car.pit_stage)=="TRACK" and not bool(car.hyper.retired) and not bool(car.mega_30.failure) and int(car.evolution.error_left)==0

static func snapshot(roster:Array)->Dictionary:
	var rows:Dictionary={}
	for car in roster:
		rows[int(car.id)]={"distance":int(car.dynamics.distance_mm),"speed":int(car.dynamics.speed_mm_s),"eligible":eligible(car)}
	return rows

static func begin(x:Dictionary,roster:Array,lap:int)->Dictionary:
	if x.phase=="GREEN":
		x.phase="VSC";x.deployments=int(x.deployments)+1;x.cars={};x.reported_pairs={}
	var rows:Dictionary=snapshot(roster)
	var field:Array=[]
	for id in rows:
		if bool(rows[id].eligible):field.append([posmod(int(rows[id].distance),lap),int(id)])
	field.sort_custom(func(a:Array,b:Array)->bool:return int(a[1])<int(b[1]) if int(a[0])==int(b[0]) else int(a[0])<int(b[0]))
	var caps:Dictionary={}
	for i in range(field.size()):
		var id:int=int(field[i][1])
		caps[id]=CAP_MM_S
		if field.size()<2:continue
		var ahead:Array=field[(i+1)%field.size()]
		var gap:int=posmod(int(ahead[0])-int(field[i][0]),lap)
		# Lane-independent following target. No direct distance correction.
		if gap>0 and gap<=40000:
			caps[id]=mini(CAP_MM_S,int(rows[int(ahead[1])].speed)+maxi(0,gap-12000)/5)
	return {"rows":rows,"caps":caps}

static func settle(x:Dictionary,before:Dictionary,after:Dictionary,last_tick:bool)->Array:
	x.total_ticks=int(x.total_ticks)+1
	var warnings:Array=[]
	var ids:Array=before.keys();ids.sort()
	for id in ids:
		if not after.has(id) or not bool(before[id].eligible) or not bool(after[id].eligible):continue
		var key:String=str(id)
		if not x.cars.has(key):x.cars[key]={"samples":0,"delta_mm":0,"warned":false}
		var row:Dictionary=x.cars[key]
		row.samples=int(row.samples)+1
		# Initial deceleration grace, measured actual distance thereafter.
		if int(row.samples)>GRACE_TICKS:
			row.delta_mm=int(row.delta_mm)+maxi(0,int(after[id].distance)-int(before[id].distance))-CAP_MM_S*STEP_MS/1000
			if int(row.delta_mm)>TOLERANCE_MM and not bool(row.warned):
				row.warned=true;x.speed_warnings=int(x.speed_warnings)+1
				warnings.append({"type":"race_control_speed_warning","car_id":int(id),"delta_mm":int(row.delta_mm)})
	for i in range(ids.size()):
		var a:int=int(ids[i])
		if not after.has(a) or not bool(before[a].eligible) or not bool(after[a].eligible):continue
		for j in range(i+1,ids.size()):
			var b:int=int(ids[j])
			if not after.has(b) or not bool(before[b].eligible) or not bool(after[b].eligible):continue
			var old:int=int(before[a].distance)-int(before[b].distance)
			var now:int=int(after[a].distance)-int(after[b].distance)
			if absi(old)>50000 or now==0:continue
			var crossing:bool=(old<0 and now>0) or (old>0 and now<0) or (old==0 and now<0)
			var pair:String="%d:%d"%[a,b]
			if crossing and not x.reported_pairs.has(pair):
				x.reported_pairs[pair]=true;x.order_warnings=int(x.order_warnings)+1
				warnings.append({"type":"race_control_order_warning","car_id":a if now>0 else b,"other_id":b if now>0 else a})
	if last_tick:x.phase="GREEN"
	return warnings
