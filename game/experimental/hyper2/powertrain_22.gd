extends RefCounted
## Hyper 2.2 — deterministic integer V8 reference model. Gameplay
## estimates, not measured supplier curves. Ratios include final drive.
const KEY := "powertrain_22"
const RATIOS := [17000,13000,10800,9200,8000,7000,6000]
const RPM_POINTS := [6500,10000,13000,16000,18000]
const TORQUE_POINTS := [215,275,310,320,295]
const IDLE := 6500
const LIMIT := 18000
const UP := 17300
const DOWN := 10500
const SHIFT_MS := 60
const REFERENCE_POWER_W := 510000
const WHEEL_RADIUS_MM := 330

static func raw_rpm(speed_mm_s: int, gear: int) -> int:
	return int(maxi(0,speed_mm_s)*int(RATIOS[clampi(gear,1,7)-1])*60000/(WHEEL_RADIUS_MM*6283185))

static func torque_nm(rpm: int) -> int:
	if rpm>LIMIT: return 0
	var x: int=clampi(rpm,IDLE,LIMIT)
	for i in range(RPM_POINTS.size()-1):
		if x<=int(RPM_POINTS[i+1]):
			return int(TORQUE_POINTS[i])+int((int(TORQUE_POINTS[i+1])-int(TORQUE_POINTS[i]))*(x-int(RPM_POINTS[i]))/(int(RPM_POINTS[i+1])-int(RPM_POINTS[i])))
	return int(TORQUE_POINTS[-1])

static func initial() -> Dictionary:
	return {"gear":1,"rpm":IDLE,"shift_left_ms":0,"shift_cut_ms":0,"engine_force_n":0,"kers_used_j":0,"v8_wheel_w":0,"drag_n":0,"rolling_n":0,"mass_g":0}

static func valid(p: Variant) -> bool:
	if not p is Dictionary or not p.has_all(initial().keys()): return false
	for key in initial():
		if typeof(p[key])!=TYPE_INT or int(p[key])<0: return false
	return int(p.gear)>=1 and int(p.gear)<=7 and int(p.rpm)>=IDLE and int(p.rpm)<=LIMIT and int(p.shift_left_ms)<=SHIFT_MS and int(p.shift_cut_ms)<=SHIFT_MS and int(p.kers_used_j)<=12000 and int(p.engine_force_n)<=100000 and int(p.v8_wheel_w)<=600000 and int(p.drag_n)<=100000 and int(p.rolling_n)<=1000 and int(p.mass_g)<=1000000

## Average tractive force for one fixed tick, including torque ceiling
## and traction interruption during shifts. KERS is the already allocated
## offer, not a second reservoir. No state mutation.
static func evaluate(previous: Dictionary, speed: int, throttle: int, base_power: int, kers_offer_w: int, grip_n: int, braking: bool, dt: int, energy_settlement:bool=false) -> Dictionary:
	var out: Dictionary=previous.duplicate()
	var gear: int=int(previous.gear)
	var left: int=int(previous.shift_left_ms)
	if speed==0:
		gear=1;left=0
	elif left==0:
		var before: int=raw_rpm(speed,gear)
		if gear<7 and before>=UP:
			gear+=1;left=SHIFT_MS
		elif gear>1 and before<DOWN and raw_rpm(speed,gear-1)<UP:
			gear-=1;left=SHIFT_MS
	var cut: int=mini(left,dt)
	var raw: int=raw_rpm(speed,gear)
	var rpm: int=clampi(raw,IDLE,LIMIT)
	var usable: int=dt-cut
	var ratio: int=int(RATIOS[gear-1])
	var torque: int=int(torque_nm(raw)*maxi(0,base_power)/REFERENCE_POWER_W)
	var torque_force: int=int(torque*ratio*930/(WHEEL_RADIUS_MM*1000))
	var v8_request: int=int(maxi(0,base_power)*throttle/1000)
	var kers_request: int=int(clampi(kers_offer_w,0,60000)*throttle/1000)
	var v8_force: int=mini(int(v8_request*1000/maxi(14000,speed)),int(torque_force*throttle/1000))
	var kers_force: int=int(kers_request*1000/maxi(14000,speed)) if raw<=LIMIT else 0
	var total: int=v8_force+kers_force
	var drive: int=0 if braking else int(mini(grip_n,total)*usable/maxi(1,dt))
	var wheel_w: int=int(drive*speed/1000)
	var kers_w: int=mini(kers_request,int(wheel_w*kers_force/maxi(1,total)))
	out.gear=gear;out.rpm=rpm;out.shift_left_ms=left-cut;out.shift_cut_ms=cut
	out.engine_force_n=drive;out.kers_used_j=int(kers_w*dt/1000);out.v8_wheel_w=mini(v8_request,maxi(0,wheel_w-kers_w))
	if energy_settlement:
		out["energy_share"]=int(kers_force*1000/maxi(1,total))
		out["energy_v8_budget"]=int(v8_request*usable/1000)
		out["energy_kers_budget"]=int(kers_request*usable/1000)
	return out
