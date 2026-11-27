extends RefCounted
## Rev13: fixed-point sector-time observer, never changes car motion.
## Balanced arc-length microsectors (~100m), using the existing VSC cap.
## These are game reference sectors, not surveyed FIA timing loops.
const KEY:="sector_control_3062"
const Mega=preload("res://experimental/hyper2/mega_30.gd")
const RaceControl=preload("res://experimental/hyper2/race_control_306.gd")
const STEP_US:=200000
const TARGET_MM:=100000
const TOLERANCE_US:=200000

static func initial()->Dictionary:
	return {"deployment":0,"last_tick":-1,"eligible_ticks":0,"last_distance":0,"next_mm":0,"last_cross_us":-1,"samples":0,"warnings":0,"elapsed_us":0,"reference_us":0,"delta_us":0}

static func count(lap:int)->int:
	return maxi(1,(lap+TARGET_MM-1)/TARGET_MM)

static func next_boundary(distance:int,lap:int)->int:
	var n:int=count(lap)
	var p:int=posmod(distance,lap)
	var i:int=mini(n-1,((p+1)*n-1)/lap)
	return distance-p+(i+1)*lap/n

static func reference_us(boundary:int,lap:int)->int:
	var n:int=count(lap)
	var p:int=posmod(boundary,lap)
	var end_index:int=n if p==0 else ((p+1)*n-1)/lap
	# boundary is an exact floor-divided end: recover its 1-based index.
	var length:int=end_index*lap/n-(end_index-1)*lap/n
	return length*1000000/Mega.CONTROL_CAP

static func reset_segment(x:Dictionary,distance:int,tick:int,lap:int)->void:
	x.last_tick=tick;x.last_distance=distance;x.eligible_ticks=0
	x.next_mm=next_boundary(distance,lap);x.last_cross_us=-1

static func valid(x:Variant,lap:int,tick:int,deployments:int)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()) or lap<100000:return false
	for key in initial():
		if typeof(x[key])!=TYPE_INT:return false
	if int(x.deployment)<0 or int(x.deployment)>deployments or int(x.last_tick)<-1 or int(x.last_tick)>tick:return false
	if int(x.eligible_ticks)<0 or int(x.eligible_ticks)>Mega.CONTROL_TICKS or int(x.samples)<0 or int(x.samples)>tick or int(x.warnings)<0 or int(x.warnings)>int(x.samples):return false
	if int(x.deployment)==0:return x==initial()
	if int(x.last_tick)<0 or int(x.last_cross_us)<-1 or int(x.last_cross_us)>tick*STEP_US:return false
	if int(x.next_mm)!=next_boundary(int(x.last_distance),lap):return false
	if int(x.last_cross_us)>=0 and int(x.eligible_ticks)<=RaceControl.GRACE_TICKS:return false
	if int(x.samples)==0:return int(x.elapsed_us)==0 and int(x.reference_us)==0 and int(x.delta_us)==0
	return int(x.elapsed_us)>0 and int(x.elapsed_us)<=Mega.CONTROL_TICKS*STEP_US and int(x.reference_us)>0 and int(x.reference_us)<=TARGET_MM*1000000/Mega.CONTROL_CAP and int(x.delta_us)==int(x.elapsed_us)-int(x.reference_us)

static func observe(x:Dictionary,before:Dictionary,after:Dictionary,lap:int,tick:int,deployment:int)->Array:
	var evidence:Array=[]
	var start:int=int(before.distance);var end:int=int(after.distance)
	if int(x.deployment)!=deployment:
		x.deployment=deployment;reset_segment(x,start,tick-1,lap)
	if not bool(before.eligible) or not bool(after.eligible) or end<start:
		reset_segment(x,end,tick,lap);return evidence
	if int(x.last_tick)!=tick-1 or int(x.last_distance)!=start:
		reset_segment(x,start,tick-1,lap)
	x.last_tick=tick;x.last_distance=end
	x.eligible_ticks=mini(Mega.CONTROL_TICKS,int(x.eligible_ticks)+1)
	# Exclude deceleration grace and the first partial microsector after it.
	if int(x.eligible_ticks)<=RaceControl.GRACE_TICKS:
		x.next_mm=next_boundary(end,lap);x.last_cross_us=-1;return evidence
	if end==start:return evidence
	while int(x.next_mm)<=end:
		var boundary:int=int(x.next_mm)
		var cross:int=(tick-1)*STEP_US+(boundary-start)*STEP_US/(end-start)
		if int(x.last_cross_us)>=0:
			var elapsed:int=cross-int(x.last_cross_us)
			var reference:int=reference_us(boundary,lap)
			x.samples=int(x.samples)+1;x.elapsed_us=elapsed;x.reference_us=reference;x.delta_us=elapsed-reference
			if int(x.delta_us)<-TOLERANCE_US:
				x.warnings=int(x.warnings)+1
				evidence.append({"type":"race_control_sector_warning","deployment":deployment,"boundary_mm":boundary,"elapsed_us":elapsed,"reference_us":reference,"delta_us":int(x.delta_us)})
		x.last_cross_us=cross;x.next_mm=next_boundary(boundary,lap)
	return evidence
