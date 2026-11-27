extends RefCounted
## Revision 6: post-solver wheel work in integer SI units. Uses the
## existing single longitudinal integrator. Constant force per tick,
## trapezoidal displacement and finite precision; not a BSFC model.
const KEY := "energy_301"
static func initial()->Dictionary:
	return {"proposed_n":0,"applied_n":0,"v8_j":0,"kers_j":0,"v8_budget_j":0,"kers_budget_j":0,"resistance_j":0,"brake_j":0,"delta_ke_j":0,"residual_j":0,"distance_mm":0,"power_limited":false,"target_limited":false}
static func valid(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()):return false
	for key in initial():
		if typeof(x[key])!=typeof(initial()[key]):return false
		if typeof(x[key])==TYPE_INT and (absi(int(x[key]))>10000000 or (key not in ["delta_ke_j","residual_j"] and int(x[key])<0)):return false
	return int(x.applied_n)<=int(x.proposed_n) and int(x.v8_j)<=int(x.v8_budget_j) and int(x.kers_j)<=int(x.kers_budget_j) and int(x.kers_budget_j)<=12000 and int(x.v8_budget_j)<=110000 and int(x.distance_mm)<=22000
static func limit(proposed:int,share:int,v8_budget:int,kers_budget:int,distance_upper:int)->int:
	var distance:int=maxi(1,distance_upper)
	var force:int=maxi(0,proposed)
	if share<1000:force=mini(force,int(v8_budget*1000000/(distance*(1000-share))))
	if share>0:force=mini(force,int(kers_budget*1000000/(distance*share)))
	return maxi(0,force)
static func settle(proposed:int,drive:int,brake:int,resist:int,mass:int,v0:int,v1:int,dt:int,distance:int,share:int,v8_budget:int,kers_budget:int,target_limited:bool)->Dictionary:
	var applied:int=drive
	if target_limited:
		applied=clampi(int((v1-v0)*mass/maxi(1,dt))+resist,0,drive)
	var work:int=int(applied*distance/1000)
	var kers:int=int(work*share/1000)
	# Budgets were applied to an upper bound on displacement before motion.
	# Rounding of the source split can add one joule to the V8 share.
	var v8:int=work-kers
	var resistance:int=int(resist*distance/1000)
	var brake_work:int=int(brake*distance/1000)
	var delta_ke:int=int(mass*(v1*v1-v0*v0)/2000000)
	return {"proposed_n":proposed,"applied_n":applied,"v8_j":v8,"kers_j":kers,"v8_budget_j":v8_budget,"kers_budget_j":kers_budget,"resistance_j":resistance,"brake_j":brake_work,"delta_ke_j":delta_ke,"residual_j":work-resistance-brake_work-delta_ke,"distance_mm":distance,"power_limited":drive<proposed,"target_limited":target_limited}
