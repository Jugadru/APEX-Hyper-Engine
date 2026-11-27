extends RefCounted
## Revision 4. Integer force budget and quasi-static axle load proxy.
## Geometry remains a schematic centreline; lateral demand is estimated,
## not integrated steering. The solver retains its corridor authority.
const KEY := "dynamics_23"
const WHEELBASE_MM := 3100
const CG_HEIGHT_MM := 310
const STRAIGHT_RADIUS_MM := 1000000

static func initial() -> Dictionary:
	return {"front_n":0,"rear_n":0,"transfer_n":0,"grip_n":0,"lateral_demand_n":0,"lateral_alloc_n":0,"long_limit_n":0,"long_used_n":0,"reserve_permille":1000,"accel_mm_s2":0,"margin_permille":940,"phase":"STRAIGHT","target_mm_s":0,"saturated":false}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(initial().keys()): return false
	for key in initial():
		if typeof(value[key])!=typeof(initial()[key]): return false
		if typeof(value[key])==TYPE_INT and absi(int(value[key]))>1000000: return false
		if typeof(value[key])==TYPE_INT and key not in ["transfer_n","accel_mm_s2"] and int(value[key])<0: return false
	return value.phase in ["STRAIGHT","ENTRY","APEX","EXIT"] and int(value.reserve_permille)<=1000 and int(value.margin_permille) in range(850,981) and int(value.target_mm_s)<=106000 and int(value.long_used_n)<=int(value.long_limit_n)

static func isqrt(n: int) -> int:
	if n<=0:return 0
	var x:int=n;var y:int=(x+1)/2
	while y<x:
		x=y;y=(x+n/x)/2
	return x

static func loads(mass_kg:int,aero_n:int,previous_accel:int) -> Dictionary:
	var total:int=mass_kg*981/100+maxi(0,aero_n)
	var static_front:int=total*460/1000
	var transfer:int=clampi(mass_kg*clampi(previous_accel,-40000,40000)*CG_HEIGHT_MM/(WHEELBASE_MM*1000),-total/3,total/3)
	var front:int=clampi(static_front-transfer,0,total)
	var rear:int=total-front
	# Modest effective load sensitivity, not a measured tyre curve.
	var imbalance:int=absi(front-static_front)
	var scale:int=1000-mini(60,imbalance*180/maxi(1,total))
	return {"front_n":front,"rear_n":rear,"transfer_n":transfer,"scale":scale}

static func margin(car:Dictionary,water:int) -> int:
	var skill:int=clampi(int(car.evolution.skill),0,100)
	var aggression:int=clampi(int(car.driver.aggression),0,1000)
	var pace:int=20 if str(car.pace)=="Atacar" else (-25 if str(car.pace)=="Conservar" else 0)
	var corridor:int=20 if str(car.racecraft.lane)!="CENTER" else 0
	return clampi(920+(skill-80)/2+(aggression-500)/50+pace-water/180-corridor,850,980)

static func budget(grip:int,lateral:int) -> Dictionary:
	# In saturation prioritize a limited longitudinal recovery margin;
	# unmet lateral demand is exposed, not claimed as achievable cornering.
	var allocated:int=mini(maxi(0,lateral),grip*960/1000)
	var remaining:int=isqrt(maxi(0,grip*grip-allocated*allocated))
	return {"lateral_alloc_n":allocated,"long_limit_n":remaining,"reserve_permille":remaining*1000/maxi(1,grip),"saturated":lateral>allocated}

static func brake_force(speed:int,target:int,mass:int,drag:int,limit:int,dt:int) -> int:
	if speed<=target:return 0
	var demand:int=(speed-target)*mass/maxi(1,dt)
	return clampi(demand-drag,0,limit)

static func phase(current_radius:int,next_radius:int,previous_radius:int) -> String:
	if current_radius<350000:return "APEX"
	if next_radius<350000:return "ENTRY"
	if previous_radius<350000:return "EXIT"
	return "STRAIGHT"

static func attack_allowed(car:Dictionary,radius:int,gap:int,water:int)->bool:
	# No new lane changes: only restrict the existing commitment gate.
	if radius>=350000:return true
	var d:Dictionary=car.dynamics.get(KEY,{})
	var reserve:int=int(d.get("reserve_permille",1000))
	return reserve>=200 and gap>=15000+water/2 and not bool(d.get("saturated",false))
