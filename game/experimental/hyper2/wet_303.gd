extends RefCounted
## Revision 8: gameplay driver ability, not historical driver telemetry.
## Does not change the tyre friction coefficient, engine or force budget.
const KEY:="wet_303"
const REASONS:=["geometry","gap","reserve","closing","visibility","neutral","error","claim","lane","eligible","committed"]
static func initial(skill:int,driver:Dictionary)->Dictionary:
	return {"wet_skill":clampi(skill,0,100),"control":clampi((skill+int(driver.awareness)/10)/2,0,100),"adaptability":clampi((skill+int(driver.patience)/10)/2,0,100),"observed_water":0,"confidence":1000,"last_water":0}
static func counters()->Dictionary:
	var result:Dictionary={}
	for reason in REASONS:result[reason]=0
	return result
static func valid(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(["wet_skill","control","adaptability","observed_water","confidence","last_water"]):return false
	for key in ["wet_skill","control","adaptability","observed_water","confidence","last_water"]:
		if typeof(x[key])!=TYPE_INT or int(x[key])<0:return false
	return int(x.wet_skill)<=100 and int(x.control)<=100 and int(x.adaptability)<=100 and int(x.observed_water)<=6000 and int(x.last_water)<=6000 and int(x.confidence)<=1000
static func valid_counters(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(REASONS):return false
	for reason in REASONS:
		if typeof(x[reason])!=TYPE_INT or int(x[reason])<0 or int(x[reason])>10000000:return false
	return true
static func update(x:Dictionary,water:int)->void:
	var change:int=absi(water-int(x.last_water))
	if change>0:x.confidence=maxi(300,int(x.confidence)-change/8)
	x.last_water=water
	var rate:int=10+int(x.adaptability)*2
	x.observed_water=int(x.observed_water)+clampi(water-int(x.observed_water),-rate,rate)
	x.confidence=mini(1000,int(x.confidence)+1+int(x.adaptability)/25)
static func blend(water:int)->int:
	return clampi((water-700)*1000/3200,0,1000)
static func margin(base:int,x:Dictionary,water:int)->int:
	var w:int=blend(water)
	var ability:int=(int(x.wet_skill)*6+int(x.control)*4)/10
	var target:int=clampi(850+(ability-45)*130/55-absi(water-int(x.observed_water))/90-(1000-int(x.confidence))/35,850,980)
	return clampi(base+(target-base)*w/1000,850,980)
static func throttle(base:int,x:Dictionary,water:int)->int:
	var utilization:int=clampi(790+int(x.control)*210/100-absi(water-int(x.observed_water))/100,700,1000)
	return int(base*(1000-(1000-utilization)*blend(water)/1000)/1000)
static func risk_multiplier(x:Dictionary,water:int)->float:
	var wet:float=float(blend(water))/1000.0
	var ability:float=float(int(x.wet_skill)+int(x.control))/200.0
	return 1.0+wet*(0.9-1.4*ability+float(absi(water-int(x.observed_water)))/6000.0)
static func attack_reason(car:Dictionary,radius:int,gap:int,closing:int,water:int)->String:
	if bool(car.get("mega_30",{}).get("neutral",false)):return "neutral"
	if int(car.evolution.error_left)>0:return "error"
	if radius<125000:return "geometry"
	var x:Dictionary=car[KEY];var d:Dictionary=car.dynamics.dynamics_23
	if bool(d.saturated) or int(d.reserve_permille)<300:return "reserve"
	if gap<7000+water/2:return "gap"
	if closing<700:return "closing"
	if water>=4500 and (int(x.control)<65 or gap<10000):return "visibility"
	return "eligible"
