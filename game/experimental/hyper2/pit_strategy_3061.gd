extends RefCounted
## Revision 12. Observable conditions only; no future weather or imposed stop quota.
## Estimated payback is a gameplay heuristic, not a race forecast.
const KEY:="pit_strategy_3061"
const Vehicle=preload("res://experimental/apex2/vehicle_dynamics.gd")
const Env=preload("res://experimental/hyper/environment.gd")
const REASONS:=["stay_out","heavy_rain","wet_track","drying_track","tire_wear","dry_compound_change","stable_wait","no_payback","compound_unavailable"]
static func initial()->Dictionary:
	return {"candidate":"","streak":0,"last_tick":-1,"evaluations":0,"orders":0,"holds":0,"reason":"stay_out","gain_ms":0,"cost_ms":0}
static func valid(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()):return false
	for key in initial():
		if typeof(x[key])!=typeof(initial()[key]):return false
	if x.candidate!="" and not x.candidate in Vehicle.TYRES:return false
	return int(x.streak)>=0 and int(x.streak)<=3 and int(x.last_tick)>=-1 and int(x.evaluations)>=0 and int(x.evaluations)<=400000 and int(x.orders)>=0 and int(x.holds)>=0 and int(x.orders)+int(x.holds)<=int(x.evaluations) and x.reason in REASONS and absi(int(x.gain_ms))<=1000000 and int(x.cost_ms)>=0 and int(x.cost_ms)<=1000000
static func wet_target(current:String,water:int,available:Array)->String:
	# Hysteresis: existing wet compound can remain in crossover band.
	if water>=3900:return "Chuva"
	if current=="Chuva" and water>3000:return "Chuva"
	if water>=1900:return "Intermediário"
	if current in ["Chuva","Intermediário"] and water>700:return "Intermediário" if current=="Intermediário" else "Chuva"
	if current in ["Chuva","Intermediário"]:
		for dry in ["Médio","Duro","Macio"]:
			if dry in available:return dry
	return current
static func evaluate(car:Dictionary,available:Array,water:int,remaining:int,tick:int,pit_ticks:int)->Dictionary:
	var x:Dictionary=car[KEY]
	var current:String=str(car.tire)
	var target:String=wet_target(current,water,available)
	var wear:int=int(car.dynamics.wear_micro)
	var reason:String="stay_out"
	var urgent:bool=false
	var dry:bool=current not in ["Chuva","Intermediário"]
	if target!=current:
		reason="heavy_rain" if target=="Chuva" else ("wet_track" if target=="Intermediário" else "drying_track")
		urgent=(dry and water>=1900) or (current=="Intermediário" and water>=3900)
	elif dry and water<=700:
		var old:Dictionary=Env.pit_advice(car,available,water,remaining)
		if bool(old.stop):
			target=str(old.compound);reason=str(old.reason)
	elif wear>=500000 and remaining>=3:
		reason="tire_wear"
	if not target in available:
		reason="compound_unavailable";target=current;urgent=false
	var gain:int=0
	var cost:int=maxi(0,pit_ticks)*200
	if reason not in ["stay_out","compound_unavailable"]:
		var current_mu:int=Vehicle.friction_mu(current,water,int(car.dynamics.tire_temp_centi),wear)
		var fresh_mu:int=Vehicle.friction_mu(target,water,int(Vehicle.TYRES[target].optimal_centi),0)
		# Assume only half a lap is grip limited and discount fresh-tyre benefit.
		var ratio:float=sqrt(float(maxi(1,current_mu))/float(maxi(1,fresh_mu)))
		gain=int(float(car.reference_lap_ms)*0.45*(1.0-ratio))*mini(3,maxi(0,remaining))
		gain=clampi(gain,-1000000,1000000)
	var actual_reason:String=reason
	var stop:bool=false
	if tick!=int(x.last_tick):
		x.evaluations=int(x.evaluations)+1
		if reason not in ["stay_out","compound_unavailable"]:
			x.streak=mini(3,int(x.streak)+1) if target==str(x.candidate) and tick-int(x.last_tick)<=150 else 1
			x.candidate=target
		else:x.candidate="";x.streak=0
		x.last_tick=tick
		if urgent or reason=="dry_compound_change":stop=true
		elif reason not in ["stay_out","compound_unavailable"]:
			if int(x.streak)<2:actual_reason="stable_wait"
			elif gain<=cost+3000 and wear<850000:actual_reason="no_payback"
			else:stop=true
		if not stop:x.holds=int(x.holds)+1
	else:actual_reason="stable_wait"
	x.reason=actual_reason;x.gain_ms=gain;x.cost_ms=cost
	return {"stop":stop,"compound":target,"reason":actual_reason}
static func accepted(x:Dictionary)->void:
	x.orders=int(x.orders)+1;x.streak=0;x.candidate=""
