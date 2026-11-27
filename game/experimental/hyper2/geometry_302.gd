extends RefCounted
## Schematic, not surveyed. Fixed integer arc-length coordinate and signed
## curvature shared by sporting profile and presentation.
const MIN_R:=28000
const MAX_R:=1000000
const SCALE:=1000000000

static func segment_length(a:Vector2i,b:Vector2i)->int:
	var dx:int=b.x-a.x;var dy:int=b.y-a.y
	return int(sqrt(float(dx*dx+dy*dy)))

static func index(profile:Array,location:int)->int:
	var low:int=0;var high:int=profile.size()
	while low+1<high:
		var middle:int=(low+high)/2
		if int(profile[middle].start_mm)<=location:low=middle
		else:high=middle
	return low

static func build(raw:Array,lap:int)->Array:
	if lap<1000000 or lap>30000000 or raw.size()<8 or raw.size()>1000:return []
	var points:Array[Vector2i]=[]
	for item in raw:
		if not item is Array or item.size()!=2:return []
		if typeof(item[0]) not in [TYPE_FLOAT,TYPE_INT] or typeof(item[1]) not in [TYPE_FLOAT,TYPE_INT]:return []
		var x:float=float(item[0]);var y:float=float(item[1])
		if not is_finite(x) or not is_finite(y) or x< -1.0 or x>2.0 or y< -1.0 or y>2.0:return []
		var point:=Vector2i(roundi(x*1100000.0),roundi(y*900000.0))
		if points.is_empty() or points[-1]!=point:points.append(point)
	if points.size()>1 and points[0]==points[-1]:points.pop_back()
	if points.size()<8:return []
	for iteration in range(2):
		if points.size()*2>1000:break
		var smoothed:Array[Vector2i]=[]
		for i in range(points.size()):
			var a:Vector2i=points[i];var b:Vector2i=points[(i+1)%points.size()]
			for q in [Vector2i((3*a.x+b.x)/4,(3*a.y+b.y)/4),Vector2i((a.x+3*b.x)/4,(a.y+3*b.y)/4)]:
				if smoothed.is_empty() or smoothed[-1]!=q:smoothed.append(q)
		points=smoothed
		if points[0]==points[-1]:points.pop_back()
	var lengths:Array[int]=[];var total:int=0
	for i in range(points.size()):
		var length_mm:int=segment_length(points[i],points[(i+1)%points.size()])
		if length_mm<=0:return []
		lengths.append(length_mm);total+=length_mm
	if total<1000:return []
	var result:Array=[];var accumulated:int=0
	for i in range(points.size()):
		var a:Vector2i=points[posmod(i-1,points.size())];var b:Vector2i=points[i];var c:Vector2i=points[(i+1)%points.size()]
		var cross:int=(b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x)
		var radius:int=MAX_R
		if cross!=0:
			var r:float=float(lengths[posmod(i-1,points.size())])*float(lengths[i])*float(segment_length(a,c))*float(lap)/(2.0*float(absi(cross))*float(total))
			radius=roundi(clampf(r,float(MIN_R),float(MAX_R)))
		var curvature:int=0 if radius==MAX_R else (1 if cross>0 else -1)*int(SCALE/radius)
		result.append({"start_mm":int(accumulated*lap/total),"radius_mm":radius,"x":b.x,"y":b.y,"curvature":curvature})
		accumulated+=lengths[i]
	return result if valid(result,lap) else []

static func valid(profile:Variant,lap:int)->bool:
	if not profile is Array or profile.size()<8 or profile.size()>1000:return false
	var last:int=-1
	for p in profile:
		if not p is Dictionary or not p.has_all(["start_mm","radius_mm","x","y","curvature"]):return false
		for key in ["start_mm","radius_mm","x","y","curvature"]:
			if typeof(p[key])!=TYPE_INT:return false
		if int(p.start_mm)<=last or int(p.start_mm)>=lap or int(p.radius_mm)<MIN_R or int(p.radius_mm)>MAX_R:return false
		if last==-1 and int(p.start_mm)!=0:return false
		if absi(int(p.x))>2200000 or absi(int(p.y))>1800000:return false
		if absi(int(p.curvature))!=(0 if int(p.radius_mm)==MAX_R else int(SCALE/int(p.radius_mm))):return false
		last=int(p.start_mm)
	for i in range(profile.size()):
		var a:Dictionary=profile[i];var b:Dictionary=profile[(i+1)%profile.size()]
		if a.x==b.x and a.y==b.y:return false
	return true

static func curvature_at(profile:Array,lap:int,position:int)->int:
	var location:int=posmod(position,lap);var i:int=index(profile,location)
	var a:Dictionary=profile[i];var b:Dictionary=profile[(i+1)%profile.size()]
	var end_mm:int=lap if i==profile.size()-1 else int(b.start_mm)
	return int(a.curvature)+int((int(b.curvature)-int(a.curvature))*(location-int(a.start_mm))/maxi(1,end_mm-int(a.start_mm)))

static func radius_at(profile:Array,lap:int,position:int)->int:
	var c:int=absi(curvature_at(profile,lap,position))
	return MAX_R if c==0 else clampi(int(SCALE/c),MIN_R,MAX_R)
