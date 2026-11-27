extends RefCounted
## Revision 5 services: fixed-tick condition, tactical lane interpolation,
## virtual race neutralization and read-only strategy. No second integrator.
const KEY := "mega_30"
const CONTROL_TICKS := 100
const CONTROL_CAP := 50000
const RADIO_COOLDOWN := 150
static func initial(condition:int=100)->Dictionary:
	return {"lateral_mm":0,"lateral_velocity_mm_s":0,"pitch_millirad":0,"roll_load_permille":0,"damage":0,"health":clampi(condition*10,0,1000),"wear_mm":0,"seen_errors":0,"seen_stops":0,"failure":false,"neutral":false,"radio_tick":-1000,"radio_kind":""}
static func valid(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()):return false
	for key in initial():
		if typeof(x[key])!=typeof(initial()[key]):return false
	return absi(int(x.lateral_mm))<=2200 and absi(int(x.lateral_velocity_mm_s))<=1400 and absi(int(x.pitch_millirad))<=60 and int(x.roll_load_permille)>=0 and int(x.roll_load_permille)<=1000 and int(x.damage)>=0 and int(x.damage)<=1000 and int(x.health)>=0 and int(x.health)<=1000 and int(x.wear_mm)>=0 and int(x.wear_mm)<1000000 and int(x.seen_errors)>=0 and int(x.seen_stops)>=0 and int(x.radio_tick)>=-1000 and x.radio_kind in ["","DAMAGE","RELIABILITY","TRAFFIC","TYRES","FUEL"]
static func control()->Dictionary:
	return {"remaining":0,"incidents":0,"deployments":0}
static func valid_control(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(control().keys()):return false
	for key in control():
		if typeof(x[key])!=TYPE_INT or int(x[key])<0:return false
	return int(x.remaining)<=CONTROL_TICKS and int(x.deployments)<=int(x.incidents)
static func lane(x:Dictionary,desired:String,accel:int,lateral:int,grip:int)->void:
	var target:int=int({"LEFT":-2200,"RIGHT":2200}.get(desired,0))
	var step:int=clampi(target-int(x.lateral_mm),-280,280)
	x.lateral_mm=int(x.lateral_mm)+step;x.lateral_velocity_mm_s=step*5
	x.pitch_millirad=clampi(-accel/1000,-60,60)
	x.roll_load_permille=clampi(lateral*1000/maxi(1,grip),0,1000)
static func condition_tick(x:Dictionary,distance:int,attacking:bool)->void:
	var total:int=int(x.wear_mm)+maxi(0,distance)
	var km:int=total/1000000
	x.wear_mm=total%1000000
	x.health=maxi(0,int(x.health)-km*(2 if attacking else 1))
	if int(x.health)==0:x.failure=true
static func incident(x:Dictionary,kind:String)->int:
	var severity:int=int({"SPIN":85,"RUNNING_WIDE":25,"OVERSTEER":10}.get(kind,0))
	x.damage=mini(1000,int(x.damage)+severity)
	return severity
static func radio_kind(car:Dictionary)->String:
	var x:Dictionary=car[KEY]
	if int(x.health)<250:return "RELIABILITY"
	if int(x.damage)>=60:return "DAMAGE"
	if int(car.dynamics.fuel_g)<12000:return "FUEL"
	if int(car.dynamics.wear_micro)>450000:return "TYRES"
	if int(car.evolution.traffic_ticks)>50:return "TRAFFIC"
	return ""
static func strategy(car:Dictionary,cases:Array)->Array:
	var ranked:Array=[]
	for item in cases:
		var row:Dictionary=item.duplicate(true)
		var wait:int=maxi(0,int(row.lap)-int(car.laps_done)-1)
		var wear:int=int(car.dynamics.wear_micro)
		# Unitless penalty; current observation only, no future weather access.
		row.score=int(row.position)*100+int(row.nearby)*20+wait*(10+wear/15000+int(car[KEY].damage)/10)
		ranked.append(row)
	ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.lap)<int(b.lap) if int(a.score)==int(b.score) else int(a.score)<int(b.score))
	return ranked
