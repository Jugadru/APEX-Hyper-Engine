extends RefCounted
## Offline prototypes. No sporting mutations or automatic penalties.
const STEP_US:=200000
static func sector_session(distance:int,lap:int,ends:Array,speeds:Array)->Dictionary:
	if lap<=0 or ends.is_empty() or ends.size()!=speeds.size() or int(ends[-1])!=lap:return {}
	var prev:int=0
	for i in range(ends.size()):
		if typeof(ends[i])!=TYPE_INT or typeof(speeds[i])!=TYPE_INT or int(ends[i])<=prev or int(speeds[i])<25000 or int(speeds[i])>50000:return {}
		prev=int(ends[i])
	var offset:int=posmod(distance,lap)
	var idx:int=0
	while idx<ends.size()-1 and int(ends[idx])<=offset:idx+=1
	return {"lap":lap,"ends":ends.duplicate(),"speeds":speeds.duplicate(),"idx":idx,"next":distance-offset+int(ends[idx]),"last_us":-1,"last_distance":distance,"fast_streak":0}
static func sector_tick(x:Dictionary,before:int,after:int,tick:int,eligible:bool)->Array:
	var evidence:Array=[]
	if x.is_empty():return evidence
	if not eligible or after<before or before!=int(x.last_distance):
		var reset:Dictionary=sector_session(after,int(x.lap),x.ends,x.speeds)
		x.clear();x.merge(reset);return evidence
	x.last_distance=after
	if after<=before:return evidence
	while int(x.next)<=after:
		var boundary:int=int(x.next)
		var idx:int=int(x.idx)
		var crossing_us:int=tick*STEP_US+int((boundary-before)*STEP_US/(after-before))
		var start:int=0 if idx==0 else int(x.ends[idx-1])
		var target_us:int=int((int(x.ends[idx])-start)*1000000/int(x.speeds[idx]))
		if int(x.last_us)>=0:
			var elapsed:int=crossing_us-int(x.last_us)
			var delta:int=elapsed-target_us
			x.fast_streak=int(x.fast_streak)+1 if delta < -200000 else 0
			evidence.append({"kind":"sector_time","continuous":true,"exempt":false,"sector":idx,"elapsed_us":elapsed,"reference_us":target_us,"delta_us":delta,"fast_streak":int(x.fast_streak)})
		x.last_us=crossing_us
		var next_idx:int=(idx+1)%x.ends.size()
		var length:int=int(x.ends[next_idx])-(0 if next_idx==0 else int(x.ends[next_idx-1]))
		x.idx=next_idx;x.next=boundary+length
	return evidence
static func review(e:Dictionary)->Dictionary:
	if bool(e.get("exempt",false)):return {"status":"DISMISSED","reason":"documented_exemption","penalty_ms":0}
	if str(e.get("kind",""))=="sector_time" and bool(e.get("continuous",false)) and e.has_all(["elapsed_us","reference_us","delta_us","fast_streak"]):
		if int(e.elapsed_us)<0 or int(e.reference_us)<=0 or int(e.delta_us)!=int(e.elapsed_us)-int(e.reference_us):return {"status":"INCONCLUSIVE","reason":"inconsistent_measurement","penalty_ms":0}
		if int(e.delta_us)>=-200000:return {"status":"DISMISSED","reason":"within_tolerance","penalty_ms":0}
		if int(e.fast_streak)>=2:return {"status":"CONFIRMED","reason":"repeated_early_sector_crossing_lab_rule","penalty_ms":0}
		return {"status":"REVIEW","reason":"single_early_crossing","penalty_ms":0}
	return {"status":"INCONCLUSIVE","reason":"insufficient_evidence","penalty_ms":0}
static func axis_interval(p:float,v:float,extent:float)->Vector2:
	if absf(v)<0.000000001:return Vector2(0,1) if absf(p)<=extent else Vector2(1,0)
	var a:float=(-extent-p)/v;var b:float=(extent-p)/v
	return Vector2(maxf(0,minf(a,b)),minf(1,maxf(a,b)))
static func swept_contact(a:Dictionary,b:Dictionary,lap:int)->Dictionary:
	if lap<=20000:return {"contact":false,"reason":"invalid_lap"}
	for row in [a,b]:
		if not row.has_all(["s0","s1","d0","d1","length","width"]) or int(row.length)<=0 or int(row.width)<=0:return {"contact":false,"reason":"invalid_body"}
	var longitudinal:int=posmod(int(a.s0)-int(b.s0)+lap/2,lap)-lap/2
	var long_v:int=(int(a.s1)-int(a.s0))-(int(b.s1)-int(b.s0))
	var lateral:int=int(a.d0)-int(b.d0)
	var lat_v:int=(int(a.d1)-int(a.d0))-(int(b.d1)-int(b.d0))
	var u:Vector2=axis_interval(float(longitudinal),float(long_v),float(int(a.length)+int(b.length))/2.0)
	var v:Vector2=axis_interval(float(lateral),float(lat_v),float(int(a.width)+int(b.width))/2.0)
	var first:float=maxf(u.x,v.x);var last:float=minf(u.y,v.y)
	return {"contact":first<=last,"first_fraction":first if first<=last else -1.0,"reason":"swept_overlap" if first<=last else "clear"}
