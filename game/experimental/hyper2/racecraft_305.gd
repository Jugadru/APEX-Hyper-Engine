extends RefCounted
## Rev10: stable named-driver tactical identity. Traits are fictional
## gameplay estimates, not claims about historical drivers.
const KEY:="racecraft_305"
const Geometry=preload("res://experimental/hyper2/geometry_302.gd")
static func fingerprint(name:String,salt:int)->int:
	var value:int=173+salt*7919
	for i in range(name.length()):value=(value*131+name.unicode_at(i))%104729
	return value
static func initial(name:String,skill:int)->Dictionary:
	return {"initiative":350+fingerprint(name,1)%501,"patience":350+fingerprint(name,2)%501,"defense":350+fingerprint(name,3)%501,"precision":clampi(skill*7+fingerprint(name,4)%301,350,980),"outside":fingerprint(name,5)%1000}
static func valid(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(initial("",80).keys()):return false
	for key in initial("",80):
		if typeof(x[key])!=TYPE_INT or int(x[key])<0 or int(x[key])>1000:return false
	return true
static func style(x:Dictionary)->String:
	if int(x.initiative)>700 and int(x.initiative)>int(x.patience):return "Atacante"
	if int(x.defense)>720:return "Defensivo"
	if int(x.patience)>700:return "Calculista"
	return "Equilibrado"
static func protected(car:Dictionary)->bool:
	return bool(car.get("mega_30",{}).get("neutral",false)) or int(car.evolution.error_left)>0 or str(car.pace)=="Conservar" or int(car.dynamics.fuel_g)<=8000 or int(car.dynamics.wear_micro)>=700000 or int(car.driver.fatigue)>=850
static func approach(car:Dictionary,gap:int,closing:int,water:int)->bool:
	if protected(car) or gap<=0 or gap>90000:return false
	var x:Dictionary=car[KEY]
	var threshold:int=clampi(1450-int(x.initiative)+water/20,550,1550)
	# Following cap can erase relative speed before a lane is chosen.
	# A matched-speed follower may investigate a clear lane, not gain speed.
	return closing>=threshold or (gap>=10000 and gap<=24000 and closing>=-150 and int(x.initiative)>=500)
static func prepare(car:Dictionary,gap:int,closing:int,water:int)->bool:
	if protected(car) or gap<=0 or gap>48000:return false
	var x:Dictionary=car[KEY]
	if str(car.driver.intent)=="PREPARE_ATTACK":return closing>=-200
	return approach(car,gap,closing,water) and (int(x.initiative)>=550 or closing>=1200)
static func reason(car:Dictionary,profile:Array,lap:int,distance:int,gap:int,closing:int,water:int)->String:
	if bool(car.get("mega_30",{}).get("neutral",false)):return "neutral"
	if protected(car):return "error"
	var x:Dictionary=car[KEY]
	var radius:int=mini(Geometry.radius_at(profile,lap,distance),Geometry.radius_at(profile,lap,distance+15000))
	if radius<125000:return "geometry"
	var d:Dictionary=car.dynamics.dynamics_23;var t:Dictionary=car.dynamics.tyres_304
	# Require both axles to retain a reserve, not merely the aggregate.
	if bool(d.saturated) or int(d.reserve_permille)<300 or int(t.front_reserve_n)*1000<300*int(t.front_grip_n) or int(t.rear_reserve_n)*1000<300*int(t.rear_grip_n) or int(t.normal_n)<=0:return "reserve"
	if gap<8000+water/2 or gap>29000:return "gap"
	var threshold:int=clampi(1100-int(x.initiative),250,1000)
	if closing<threshold and not (gap<=22000 and closing>=-150 and int(x.initiative)>=500):return "closing"
	if water>=4500 and (int(car.wet_303.control)<65 or gap<10000):return "visibility"
	return "eligible"
static func preferred_lane(x:Dictionary,curvature:int)->String:
	var inside:String="LEFT" if curvature>=0 else "RIGHT"
	return inside if int(x.outside)<500 else ("RIGHT" if inside=="LEFT" else "LEFT")
static func defense_allowed(car:Dictionary,gap:int,closing:int)->bool:
	if protected(car) or gap<11000 or closing<0:return false
	return str(car.driver.intent)=="COVER_THREAT" or (int(car[KEY].defense)>=720 and closing>=700)
static func cooldown(x:Dictionary)->int:
	return 25+int(x.patience)/20
