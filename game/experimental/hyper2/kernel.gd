extends "res://experimental/hyper/kernel.gd"
## Alpha 2. State additions are versioned independently of the legacy Alpha 1.
const Intelligence = preload("res://experimental/hyper2/race_intelligence.gd")
const EVOLUTION_REV := 2
const PHYSICS_REV := 3
const DYNAMICS_REV := 4
const MEGA_REV := 5
const ENERGY_REV := 6
const Energy = preload("res://experimental/hyper2/energy_301.gd")
const Mega = preload("res://experimental/hyper2/mega_30.gd")
const Dynamics = preload("res://experimental/hyper2/dynamics_23.gd")
const Powertrain = preload("res://experimental/hyper2/powertrain_22.gd")
func initialize(scenario: Dictionary) -> bool:
	if not super.initialize(scenario): return false
	state["hyper_evolution_revision"]=ENERGY_REV if bool(scenario.get("hyper301_physics",false)) else (MEGA_REV if bool(scenario.get("hyper30_physics",false)) else (DYNAMICS_REV if bool(scenario.get("hyper23_physics",false)) else (PHYSICS_REV if bool(scenario.get("hyper22_physics",false)) else EVOLUTION_REV)))
	if int(state.hyper_evolution_revision)>=MEGA_REV:state["mega_control"]=Mega.control()
	state["hyper_errors_enabled"]=bool(scenario.get("hyper_errors_enabled",true))
	var skill_by_name: Dictionary={}
	var historical: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	for t in historical.teams:
		for d in t.drivers: skill_by_name[str(d.name)]=int(d.skill)
	for car in state.cars:
		car["evolution"]=Intelligence.initial(int(state.seed),int(car.id),int(skill_by_name.get(str(car.name),80)))
		if int(state.hyper_evolution_revision)>=PHYSICS_REV: car.dynamics[Powertrain.KEY]=Powertrain.initial()
		if int(state.hyper_evolution_revision)>=DYNAMICS_REV: car.dynamics[Dynamics.KEY]=Dynamics.initial()
		if int(state.hyper_evolution_revision)>=MEGA_REV:
			var spec:Dictionary=scenario.get("hyper_specs",{}).get(str(car.id),{})
			car[Mega.KEY]=Mega.initial(int(spec.get("condition",100)))
		if int(state.hyper_evolution_revision)==ENERGY_REV:car.dynamics[Energy.KEY]=Energy.initial()
	return true
func step_tick() -> bool:
	if not initialized or bool(state.finished) or int(state.tick)>=MAX_TICKS: return false
	var mega:bool=int(state.hyper_evolution_revision)>=MEGA_REV
	var old_distances:Dictionary={}
	if mega:
		var control:Dictionary=state.mega_control
		for car in state.cars:
			car[Mega.KEY].neutral=int(control.remaining)>0
			old_distances[int(car.id)]=int(car.dynamics.distance_mm)
	# Frozen physical roster; track neighbours are independent of race classification.
	var old_laps: Dictionary={}; var physical: Array=[]
	for car in state.cars:
		old_laps[int(car.id)]=int(car.laps_done)
		if not car.finished and car.pit_stage=="TRACK": physical.append([posmod(int(car.dynamics.distance_mm),int(state.lap_length_mm)),int(car.id),int(car.dynamics.distance_mm),car])
	physical.sort_custom(func(a: Array,b: Array)->bool: return int(a[1])<int(b[1]) if a[0]==b[0] else int(a[0])<int(b[0]))
	for i in range(physical.size()):
		var own: Array=physical[i]; var car: Dictionary=own[3]; var e: Dictionary=car.evolution
		var front_gap: int=int(state.lap_length_mm); var blue: bool=false
		if physical.size()>1:
			var front: Array=physical[(i+1)%physical.size()]
			front_gap=posmod(int(front[0])-int(own[0]),int(state.lap_length_mm))
			blue=front_gap<50000 and int(own[2])-int(front[2])>int(state.lap_length_mm)/2
		e.traffic_ticks=int(e.traffic_ticks)+1 if front_gap<45000 else 0
		e.blue_ticks=int(e.blue_ticks)+1 if blue else 0
		e.cooldown=maxi(0,int(e.cooldown)-1)
		if int(e.error_left)>0: continue
		if int(e.recovery_ticks)>0: e.recovery_ticks=int(e.recovery_ticks)-1; continue
		if not bool(state.hyper_errors_enabled) or int(state.tick)<120 or int(e.cooldown)>0 or car.progress_units<0: continue
		var radius: int=int(state.track_profile[Vehicle._profile_index(state.track_profile,int(own[0]))].radius_mm)
		var probability: float=Intelligence.risk(car,int(state.water_microns),radius,front_gap)*0.2
		var next_tick: int=int(state.tick)+1
		if probability>0.0 and Intelligence.sample(int(state.seed),int(car.id),next_tick,1,1)<probability:
			e.error_kind=Intelligence.choose_kind(radius,int(state.water_microns),Intelligence.sample(int(state.seed),int(car.id),next_tick,1,2))
			var severity: float=Intelligence.sample(int(state.seed),int(car.id),next_tick,1,3)
			e.error_total=10+int(severity*18.0)+(25 if e.error_kind=="SPIN" else 0); e.error_left=e.error_total; e.error_ref_speed=int(car.dynamics.speed_mm_s); e.error_count=int(e.error_count)+1; e.cooldown=100
			car.driver.confidence=maxi(0,int(car.driver.confidence)-40)
			_event("hyper_driver_error",int(car.id),{"kind":str(e.error_kind)})
	var advanced: bool=super.step_tick()
	if not advanced: return false
	for car in state.cars:
		var e: Dictionary=car.evolution
		if int(car.laps_done)>int(old_laps[int(car.id)]):
			var duration: int=int(state.tick)-int(e.last_cross_tick)
			e.last_cross_tick=int(state.tick); e.last_lap_ticks=duration
			if int(e.best_lap_ticks)==0 or duration<int(e.best_lap_ticks): e.best_lap_ticks=duration
			e.lap_times.append(duration)
		if int(e.error_left)>0:
			if car.pit_stage!="TRACK" or car.finished:
				e.error_left=0; e.recovery_ticks=0; _event("hyper_error_interrupted",int(car.id),{"kind":str(e.error_kind)})
			else:
				e.error_left=int(e.error_left)-1
				if int(e.error_left)==0:
					e.recovery_ticks=25; _event("hyper_error_recovered",int(car.id),{"kind":str(e.error_kind)})
	if mega:
		if int(state.mega_control.remaining)>0:
			state.mega_control.remaining=int(state.mega_control.remaining)-1
			if int(state.mega_control.remaining)==0:_event("mega_green",-1)
		for car in state.cars:
			var x:Dictionary=car[Mega.KEY]
			var evo:Dictionary=car.evolution
			var d:Dictionary=car.dynamics
			if int(evo.error_count)>int(x.seen_errors):
				x.seen_errors=int(evo.error_count)
				var severity:int=Mega.incident(x,str(evo.error_kind))
				if severity>0:
					_event("mega_damage",int(car.id),{"damage":int(x.damage),"kind":str(evo.error_kind)})
					state.mega_control.incidents=int(state.mega_control.incidents)+1
					if severity>=85 and int(state.mega_control.remaining)==0:
						state.mega_control.remaining=Mega.CONTROL_TICKS;state.mega_control.deployments=int(state.mega_control.deployments)+1
						_event("mega_virtual_sc",-1)
			if int(car.hyper.pit_count)>int(x.seen_stops):
				x.seen_stops=int(car.hyper.pit_count)
				if int(x.damage)>0:
					x.damage=maxi(0,int(x.damage)-40)
					_event("mega_repair",int(car.id),{"damage":int(x.damage)})
			if not car.finished and car.pit_stage=="TRACK":
				Mega.condition_tick(x,int(d.distance_mm)-int(old_distances[int(car.id)]),str(car.pace)=="Atacar")
				var grip:Dictionary=d[Dynamics.KEY]
				Mega.lane(x,str(car.racecraft.lane),int(grip.accel_mm_s2),int(grip.lateral_demand_n),int(grip.grip_n))
				if bool(x.failure) and int(d.speed_mm_s)<=1000:
					car.finished=true;car.hyper.retired=true;car.hyper.finish_tick=int(state.tick)
					car.hyper.drs_active=false;car.hyper.drs_armed=[]
					_event("mega_mechanical_retirement",int(car.id))
					continue
				var radio:String=Mega.radio_kind(car)
				if not radio.is_empty() and radio!=str(x.radio_kind) and int(state.tick)-int(x.radio_tick)>=Mega.RADIO_COOLDOWN:
					x.radio_kind=radio;x.radio_tick=int(state.tick)
					_event("mega_radio",int(car.id),{"kind":radio})
				elif radio.is_empty():x.radio_kind=""
		if not bool(state.finished) and state.cars.all(func(actor:Dictionary)->bool:return bool(actor.finished)):
			state.finished=true;_event("race_finished",-1)
	return true
func _advance_reference_car(car: Dictionary,previous: int) -> void:
	var e: Dictionary=car.evolution
	if int(state.tick)<=int(e.reaction_ticks) and int(car.progress_units)<=0: return
	var old_cap: int=int(car.traffic_speed_cap_mm_s)
	var wet_setup:int=int(car.hyper.setup_wet);var old_drag:int=int(car.dynamics.drag_milli)
	var water:int=int(state.water_microns)
	car.dynamics.drag_milli=old_drag+int(25*wet_setup/1000)
	car["hyper_setup_grip_permille"]=1000+int(wet_setup*(50*water/6000-20)/1000)
	if int(e.error_left)>0:
		# Apply a target-speed constraint, not a teleport or direct progress change.
		var target: int=maxi(12000,int(float(e.error_ref_speed)*Intelligence.speed_fraction(e)))
		car.traffic_speed_cap_mm_s=mini(old_cap,target)
	var original_power:int=int(car.dynamics.wheel_power_w)
	var original_downforce:int=int(car.dynamics.downforce_milli)
	if car.has(Mega.KEY):
		var x:Dictionary=car[Mega.KEY]
		car.dynamics.wheel_power_w=original_power*(1000-int(x.damage)/4)/1000
		car.dynamics.downforce_milli=original_downforce*(1000-int(x.damage)/3)/1000
		if bool(x.neutral):car.traffic_speed_cap_mm_s=mini(int(car.traffic_speed_cap_mm_s),Mega.CONTROL_CAP)
		if bool(x.failure):
			car.dynamics.wheel_power_w=0;car.hyper.kers_j=0;car.traffic_speed_cap_mm_s=0
	super._advance_reference_car(car,previous)
	car.dynamics.wheel_power_w=original_power;car.dynamics.downforce_milli=original_downforce
	car.traffic_speed_cap_mm_s=old_cap
	car.dynamics.drag_milli=old_drag;car.erase("hyper_setup_grip_permille")
func _apply_command(command:Dictionary)->Dictionary:
	if str(command.type)=="set_auto":
		var car:Dictionary=_lookup_car(int(command.car_id))
		if str(command.source)!="Manual" or car.is_empty() or car.finished:return {"ok":false,"reason":"control_unavailable"}
		car.driver.control_mode="AUTO"
		_event("hyper_auto_restored",int(car.id))
		return {"ok":true,"reason":"automatic_pace_restored"}
	return super._apply_command(command)
func strategy_report(id: int) -> Dictionary:
	var car: Dictionary=_lookup_car(id)
	if car.is_empty(): return {}
	var report:Dictionary={"diagnosis":Intelligence.diagnosis(car,int(state.water_microns)),"protected":int(car.pit_requested_lap)>0,"cases":Intelligence.rejoin(car,state.cars,int(car.reference_lap_ms)/STEP_MS,int(state.hyper_pit_transit)+SERVICE_TICKS,int(state.race_laps))}
	if car.has(Mega.KEY):report["ranked"]=Mega.strategy(car,report.cases)
	return report
func restore(data: Dictionary) -> bool:
	var candidate: Variant=data.get("state",null)
	if not candidate is Dictionary or int(candidate.get("hyper_evolution_revision",0)) not in [EVOLUTION_REV,PHYSICS_REV,DYNAMICS_REV,MEGA_REV,ENERGY_REV] or typeof(candidate.get("hyper_errors_enabled"))!=TYPE_BOOL: return false
	if int(candidate.hyper_evolution_revision)>=MEGA_REV:
		if not Mega.valid_control(candidate.get("mega_control")):return false
	elif candidate.has("mega_control"):return false
	for car in candidate.get("cars",[]):
		if not car is Dictionary or not car.get("evolution") is Dictionary: return false
		if not car.get("dynamics") is Dictionary: return false
		if int(candidate.hyper_evolution_revision)>=PHYSICS_REV:
			if not Powertrain.valid(car.dynamics.get(Powertrain.KEY)): return false
		elif car.dynamics.has(Powertrain.KEY): return false
		if int(candidate.hyper_evolution_revision)>=DYNAMICS_REV:
			if not Dynamics.valid(car.dynamics.get(Dynamics.KEY)): return false
		elif car.dynamics.has(Dynamics.KEY): return false
		if int(candidate.hyper_evolution_revision)>=MEGA_REV:
			if not Mega.valid(car.get(Mega.KEY)):return false
			var condition:Dictionary=car[Mega.KEY]
			if not car.get("hyper") is Dictionary:return false
			if int(condition.seen_errors)!=int(car.evolution.get("error_count",-1)) or int(condition.seen_stops)!=int(car.hyper.get("pit_count",-1)) or int(condition.radio_tick)>int(candidate.get("tick",-1)):return false
			if bool(condition.failure)!=(int(condition.health)==0):return false
		elif car.has(Mega.KEY):return false
		if int(candidate.hyper_evolution_revision)==ENERGY_REV:
			if not Energy.valid(car.dynamics.get(Energy.KEY)):return false
		elif car.dynamics.has(Energy.KEY):return false
		var e: Dictionary=car.evolution
		if not e.has_all(["skill","reaction_ticks","error_kind","error_left","error_total","error_ref_speed","error_count","recovery_ticks","cooldown","last_cross_tick","last_lap_ticks","best_lap_ticks","lap_times","traffic_ticks","blue_ticks","last_radio_tick"]): return false
		for key in ["skill","reaction_ticks","error_left","error_total","error_ref_speed","error_count","recovery_ticks","cooldown","last_cross_tick","last_lap_ticks","best_lap_ticks","traffic_ticks","blue_ticks"]:
			if typeof(e[key])!=TYPE_INT or int(e[key])<0: return false
		if int(e.skill)>100 or int(e.reaction_ticks)>3 or int(e.error_left)>int(e.error_total) or int(e.error_total)>60 or int(e.last_cross_tick)>int(candidate.tick) or not e.lap_times is Array or e.lap_times.size()!=int(car.laps_done): return false
		if str(e.error_kind)!="" and not str(e.error_kind) in Intelligence.KINDS: return false
		if int(e.error_left)>0 and str(e.error_kind)=="": return false
		for time in e.lap_times:
			if typeof(time)!=TYPE_INT or int(time)<=0: return false
	return super.restore(data)
