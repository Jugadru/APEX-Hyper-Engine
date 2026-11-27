extends RefCounted
## Revision 14: evidence-led review of experimental VSC observations.
## No penalty, movement, classification, command or RNG changes.
const KEY:="race_stewards_3063"
const Sectors=preload("res://experimental/hyper2/sector_control_3062.gd")
const RaceControl=preload("res://experimental/hyper2/race_control_306.gd")
const MAX_CASES:=256
const MAX_PENDING:=300 # 24 pace cases + 276 distinct unordered pairs

static func initial()->Dictionary:
	return {"next_id":1,"closed_deployment":0,"pending":{},"history":[],"warnings":0,"insufficient":0,"evicted":0}

static func _key(deployment:int,car_id:int,other_id:int)->String:
	if other_id<0:return "%d:pace:%d"%[deployment,car_id]
	return "%d:order:%d:%d"%[deployment,mini(car_id,other_id),maxi(car_id,other_id)]

static func _event_row(kind:String,row:Dictionary)->Dictionary:
	return {"type":kind,"car_id":int(row.car_id),"case_id":int(row.id),"deployment":int(row.deployment),"decision":str(row.decision),"reason":str(row.reason)}

static func record(x:Dictionary,evidence:Dictionary,car_id:int,tick:int,deployment:int)->Array:
	if deployment<=int(x.closed_deployment) or car_id<0 or tick<1:return []
	var kind:String=str(evidence.get("type",""))
	var other:int=-1
	var crossing:String=""
	var elapsed:int=0;var reference:int=0;var boundary:int=0;var excess:int=0
	match kind:
		"race_control_sector_warning":
			for field in ["deployment","boundary_mm","elapsed_us","reference_us","delta_us"]:
				if typeof(evidence.get(field))!=TYPE_INT:return []
			elapsed=int(evidence.elapsed_us);reference=int(evidence.reference_us);boundary=int(evidence.boundary_mm)
			if int(evidence.deployment)!=deployment or elapsed<=0 or reference<=0 or reference>2000000 or int(evidence.delta_us)!=elapsed-reference or elapsed-reference>=-Sectors.TOLERANCE_US:return []
		"race_control_speed_warning":
			if typeof(evidence.get("delta_mm"))!=TYPE_INT:return []
			excess=int(evidence.delta_mm)
			if excess<=RaceControl.TOLERANCE_MM or excess>2000000:return []
		"race_control_order_warning":
			if typeof(evidence.get("other_id"))!=TYPE_INT:return []
			other=int(evidence.other_id);crossing=str(evidence.get("crossing_kind",""))
			if other<0 or other==car_id or crossing not in ["sporting_order","lapped_traffic"]:return []
		_:return []
	var key:String=_key(deployment,car_id,other)
	var fresh:bool=not x.pending.has(key)
	if fresh:
		if x.pending.size()>=MAX_PENDING:return []
		x.pending[key]={"id":int(x.next_id),"deployment":deployment,"car_id":car_id,"other_id":other,"opened_tick":tick,"last_tick":tick,"closed_tick":-1,"decision":"UNDER_REVIEW","reason":"collecting_evidence","sector_count":0,"last_boundary":0,"elapsed_us":0,"reference_us":0,"delta_us":0,"speed_delta_mm":0,"crossing_kind":crossing}
		x.next_id=int(x.next_id)+1
	var row:Dictionary=x.pending[key]
	if tick<int(row.last_tick):return []
	match kind:
		"race_control_sector_warning":
			if int(row.sector_count)>0 and boundary<=int(row.last_boundary):return []
			row.sector_count=int(row.sector_count)+1;row.last_boundary=boundary
			if elapsed-reference<int(row.delta_us):
				row.elapsed_us=elapsed;row.reference_us=reference;row.delta_us=elapsed-reference
		"race_control_speed_warning":
			if int(row.speed_delta_mm)>0:return []
			row.speed_delta_mm=excess
		"race_control_order_warning":
			if not fresh:return []
	row.last_tick=tick
	return [_event_row("stewards_case_opened",row)] if fresh else []

static func close_deployment(x:Dictionary,deployment:int,tick:int)->Array:
	if deployment<=int(x.closed_deployment):return []
	var events:Array=[]
	var keys:Array=x.pending.keys()
	keys.sort_custom(func(a:String,b:String)->bool:return int(x.pending[a].id)<int(x.pending[b].id))
	for key in keys:
		var row:Dictionary=x.pending[key]
		if int(row.deployment)>deployment:continue
		row.closed_tick=tick
		if int(row.other_id)<0 and int(row.sector_count)>0:
			row.decision="WARNING";row.reason="experimental_sector_delta"
			x.warnings=int(x.warnings)+1
		else:
			row.decision="INSUFFICIENT_EVIDENCE"
			row.reason="order_context_missing" if int(row.other_id)>=0 else "sector_corroboration_missing"
			x.insufficient=int(x.insufficient)+1
		events.append(_event_row("stewards_case_decided",row))
		x.history.append(row);x.pending.erase(key)
		while x.history.size()>MAX_CASES:
			x.history.pop_front();x.evicted=int(x.evicted)+1
	x.closed_deployment=deployment
	return events

static func valid(x:Variant,roster:Array,tick:int,deployments:int)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()):return false
	for field in ["next_id","closed_deployment","warnings","insufficient","evicted"]:
		if typeof(x[field])!=TYPE_INT or int(x[field])<0:return false
	if int(x.next_id)<1 or int(x.closed_deployment)>deployments:return false
	if not x.pending is Dictionary or not x.history is Array or x.pending.size()>MAX_PENDING or x.history.size()>MAX_CASES:return false
	if int(x.warnings)+int(x.insufficient)!=x.history.size()+int(x.evicted) or int(x.next_id)!=1+int(x.warnings)+int(x.insufficient)+x.pending.size():return false
	var roster_ids:Dictionary={}
	for car in roster:
		if not car is Dictionary or typeof(car.get("id"))!=TYPE_INT:return false
		roster_ids[int(car.id)]=true
	var seen:Dictionary={}
	var rows:Array=x.history+x.pending.values()
	var previous:int=0
	for row in x.history:
		if not row is Dictionary or typeof(row.get("id"))!=TYPE_INT or int(row.id)<=previous:return false
		previous=int(row.id)
	for row in rows:
		if not row is Dictionary:return false
		for field in ["id","deployment","car_id","other_id","opened_tick","last_tick","closed_tick","sector_count","last_boundary","elapsed_us","reference_us","delta_us","speed_delta_mm"]:
			if typeof(row.get(field))!=TYPE_INT:return false
		for field in ["decision","reason","crossing_kind"]:
			if typeof(row.get(field))!=TYPE_STRING:return false
		var id:int=int(row.id)
		if id<1 or id>=int(x.next_id) or seen.has(id):return false
		seen[id]=true
		if not roster_ids.has(int(row.car_id)) or int(row.other_id)<-1 or int(row.other_id)==int(row.car_id) or (int(row.other_id)>=0 and not roster_ids.has(int(row.other_id))):return false
		if int(row.deployment)<1 or int(row.deployment)>deployments or int(row.opened_tick)<1 or int(row.last_tick)<int(row.opened_tick) or int(row.last_tick)>tick:return false
		if int(row.sector_count)<0 or int(row.sector_count)>tick or int(row.speed_delta_mm)<0 or int(row.speed_delta_mm)>2000000:return false
		if int(row.speed_delta_mm)>0 and int(row.speed_delta_mm)<=RaceControl.TOLERANCE_MM:return false
		if int(row.sector_count)>0:
			if int(row.elapsed_us)<=0 or int(row.reference_us)<=0 or int(row.reference_us)>2000000 or int(row.delta_us)!=int(row.elapsed_us)-int(row.reference_us) or int(row.delta_us)>=-Sectors.TOLERANCE_US:return false
		elif int(row.delta_us)!=0 or int(row.elapsed_us)!=0 or int(row.reference_us)!=0 or int(row.last_boundary)!=0:return false
		if int(row.other_id)>=0:
			if row.crossing_kind not in ["sporting_order","lapped_traffic"] or int(row.sector_count)!=0 or int(row.speed_delta_mm)!=0:return false
		elif row.crossing_kind!="" or (int(row.sector_count)==0 and int(row.speed_delta_mm)==0):return false
		var key:String=_key(int(row.deployment),int(row.car_id),int(row.other_id))
		if row.decision=="UNDER_REVIEW":
			if int(row.closed_tick)!=-1 or int(row.deployment)<=int(x.closed_deployment) or row.reason!="collecting_evidence" or not x.pending.has(key) or x.pending[key]!=row:return false
		else:
			if int(row.closed_tick)<int(row.last_tick) or int(row.closed_tick)>tick or int(row.deployment)>int(x.closed_deployment):return false
			if int(row.other_id)<0 and int(row.sector_count)>0:
				if row.decision!="WARNING" or row.reason!="experimental_sector_delta":return false
			else:
				if row.decision!="INSUFFICIENT_EVIDENCE" or row.reason!=("order_context_missing" if int(row.other_id)>=0 else "sector_corroboration_missing"):return false
	for key in x.pending:
		var row:Dictionary=x.pending[key]
		if row.decision!="UNDER_REVIEW" or key!=_key(int(row.deployment),int(row.car_id),int(row.other_id)):return false
	return true
