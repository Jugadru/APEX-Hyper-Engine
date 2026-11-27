extends RefCounted
## Extracted from APEX-Simulation scripts/core/race_longitudinal_069.gd
## Blob d00459902664f80c3e24296fe00769ffe1911bad; only the four stateless functions below.
## No dependencies on the moving Core 2 main. Experimental coefficients.
const MAX_MPS := 100.0

static func rates(speed: float, traction: float) -> Dictionary:
	# High-speed acceleration tapers; braking grows with speed as a
	# simple downforce proxy. Detailed torque/load transfer follow later.
	return {"accel":maxf(2.2,10.0-0.075*speed)*traction,
		"brake":lerpf(12.0,25.0,clampf(speed/85.0,0.0,1.0))*traction}

static func braking_cap(future_speed: float, braking: float, distance_m: float) -> float:
	return sqrt(maxf(0.0,future_speed*future_speed+2.0*maxf(0.0,braking)*maxf(0.0,distance_m)))

static func integrate(speed: float, target: float, accel: float, brake: float, dt: float) -> Dictionary:
	var start := clampf(speed,0.0,MAX_MPS)
	var goal := clampf(target,0.0,MAX_MPS)
	var time := maxf(0.0,dt)
	var rate := maxf(0.000001,accel if goal>=start else brake)
	var ramp := minf(time,absf(goal-start)/rate)
	var end := move_toward(start,goal,rate*ramp)
	# Exact constant-rate ramp, then cruise for the rest of the tick.
	return {"speed_mps":end,"distance_m":(start+end)*0.5*ramp+end*(time-ramp)}

static func settle(proposal: Dictionary, actual_m: float, dt: float, driving_dt: float) -> float:
	# A collision-avoidance restriction or hesitation may require more
	# braking than the free-air model. Never restore lost progress.
	if dt<=0.0: return 0.0
	if actual_m+0.000001<float(proposal.distance_m) or driving_dt+0.000001<dt:
		return clampf(minf(float(proposal.speed_mps),actual_m/dt),0.0,MAX_MPS)
	return float(proposal.speed_mps)
