extends RefCounted
## Passive, bounded QA observer. It is not part of the sporting hash.
var last_tick: int=-1
var observed: int=0
var findings: Dictionary={}
var samples: Array=[]
var prior: Dictionary={}
func reset()->void:
	last_tick=-1; observed=0; findings.clear(); samples.clear(); prior.clear()
func _flag(kind: String,tick: int,id: int)->void:
	findings[kind]=int(findings.get(kind,0))+1
	if samples.size()<64: samples.append({"kind":kind,"tick":tick,"id":id})
func observe(state: Dictionary)->void:
	var tick: int=int(state.tick)
	if tick==last_tick: return
	if tick<last_tick: reset()
	var continuous: bool=tick==last_tick+1
	observed+=1; last_tick=tick
	var ids: Dictionary={}; var bays: Dictionary={}; var next: Dictionary={}
	for car in state.cars:
		var id: int=int(car.id); var d: Dictionary=car.dynamics
		if ids.has(id): _flag("duplicate_id",tick,id)
		ids[id]=true
		if int(d.speed_mm_s)<0 or int(d.speed_mm_s)>106000: _flag("speed_range",tick,id)
		if int(d.wear_micro)<0 or int(d.wear_micro)>1000000: _flag("wear_range",tick,id)
		if int(d.fuel_g)<0: _flag("negative_fuel",tick,id)
		if car.pit_stage=="PIT_SERVICE":
			if bays.has(str(car.team)): _flag("double_service",tick,id)
			bays[str(car.team)]=true
		if continuous and prior.has(id) and prior[id].stage=="TRACK" and car.pit_stage=="TRACK" and not car.finished and int(d.distance_mm)<int(prior[id].distance): _flag("backwards",tick,id)
		next[id]={"stage":str(car.pit_stage),"distance":int(d.distance_mm)}
	prior=next
func report()->Dictionary:
	return {"observed_ticks":observed,"last_tick":last_tick,"findings":findings.duplicate(true),"samples":samples.duplicate(true)}
