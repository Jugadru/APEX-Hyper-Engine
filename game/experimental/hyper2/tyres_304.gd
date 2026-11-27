extends RefCounted
## Rev9: quasi-static four-wheel load model with filtered transfer and
## axle-level friction budgets. Integer N/mm/ms; not multibody suspension.
const KEY:="tyres_304"
const WHEELBASE_MM:=3100
const CG_MM:=310
const TRACK_MM:=1500
const WHEELS:=["fl","fr","rl","rr"]

static func initial(spec:Dictionary={})->Dictionary:
	return {"brake_bias":clampi(int(spec.get("brake_bias",560)),480,660),"roll_front":clampi(int(spec.get("roll_front",480)),350,650),"response":clampi(int(spec.get("suspension_response",500)),250,800),"long_transfer_n":0,"lat_transfer_n":0,"fl":0,"fr":0,"rl":0,"rr":0,"normal_n":0,"front_grip_n":0,"rear_grip_n":0,"scale_permille":1000,"front_lateral_n":0,"rear_lateral_n":0,"front_reserve_n":0,"rear_reserve_n":0,"drive_limit_n":0,"brake_limit_n":0,"wear_factor":1000,"applied_drive_n":0,"applied_brake_n":0}

static func root(n:int)->int:
	if n<=0:return 0
	var x:int=int(sqrt(float(n)))
	while x*x>n:x-=1
	while (x+1)*(x+1)<=n:x+=1
	return x

static func valid(x:Variant)->bool:
	if not x is Dictionary or not x.has_all(initial().keys()):return false
	for key in initial():
		if typeof(x[key])!=TYPE_INT or absi(int(x[key]))>1000000:return false
		if key not in ["long_transfer_n","lat_transfer_n"] and int(x[key])<0:return false
	if int(x.brake_bias)<480 or int(x.brake_bias)>660 or int(x.roll_front)<350 or int(x.roll_front)>650 or int(x.response)<250 or int(x.response)>800:return false
	if int(x.scale_permille)<850 or int(x.scale_permille)>1000 or int(x.wear_factor)<1000 or int(x.wear_factor)>1200:return false
	if int(x.fl)+int(x.fr)+int(x.rl)+int(x.rr)!=int(x.normal_n):return false
	if int(x.front_lateral_n)*int(x.front_lateral_n)+int(x.front_reserve_n)*int(x.front_reserve_n)>int(x.front_grip_n)*int(x.front_grip_n):return false
	if int(x.rear_lateral_n)*int(x.rear_lateral_n)+int(x.rear_reserve_n)*int(x.rear_reserve_n)>int(x.rear_grip_n)*int(x.rear_grip_n):return false
	return int(x.applied_drive_n)<=int(x.drive_limit_n) and int(x.applied_brake_n)<=int(x.brake_limit_n)

static func wheel_capacity(load_n:int,mean_n:int,mu:int)->int:
	# A loaded tyre produces less grip per unit normal force; unloaded
	# wheels get no artificial bonus. Coefficients are gameplay estimates.
	var loss:int=clampi((load_n-mean_n)*90/maxi(1,mean_n),0,150)
	return int(load_n*mu*(1000-loss)/1000000)

static func prepare(previous:Dictionary,mass:int,aero:int,accel:int,signed_lateral:int,mu:int)->Dictionary:
	var x:Dictionary=previous.duplicate()
	var total:int=mass*981/100+maxi(0,aero)
	var static_front:int=total*460/1000
	var desired_long:int=clampi(mass*clampi(accel,-40000,40000)*CG_MM/(WHEELBASE_MM*1000),-total/3,total/3)
	x.long_transfer_n=clampi(int(x.long_transfer_n)+(desired_long-int(x.long_transfer_n))*int(x.response)/1000,-total/3,total/3)
	var front:int=clampi(static_front-int(x.long_transfer_n),0,total)
	var rear:int=total-front
	var desired_lat:int=clampi(signed_lateral*CG_MM/TRACK_MM,-total/2,total/2)
	x.lat_transfer_n=clampi(int(x.lat_transfer_n)+(desired_lat-int(x.lat_transfer_n))*int(x.response)/1000,-total/2,total/2)
	# Positive curvature loads the right-hand wheels in this convention.
	var front_shift:int=clampi(int(x.lat_transfer_n)*int(x.roll_front)/1000,-(front-front/2),front/2)
	var rear_shift:int=clampi(int(x.lat_transfer_n)*(1000-int(x.roll_front))/1000,-(rear-rear/2),rear/2)
	x.fl=front/2-front_shift;x.fr=front-int(x.fl)
	x.rl=rear/2-rear_shift;x.rr=rear-int(x.rl)
	x.normal_n=total
	var mean:int=maxi(1,total/4)
	x.front_grip_n=wheel_capacity(int(x.fl),mean,mu)+wheel_capacity(int(x.fr),mean,mu)
	x.rear_grip_n=wheel_capacity(int(x.rl),mean,mu)+wheel_capacity(int(x.rr),mean,mu)
	var raw:int=int(total*mu/1000)
	x.scale_permille=clampi(int((int(x.front_grip_n)+int(x.rear_grip_n))*1000/maxi(1,raw)),850,1000)
	x.applied_drive_n=0;x.applied_brake_n=0
	return x

static func allocate(x:Dictionary,lateral:int,aggregate_limit:int)->void:
	var front:int=int(x.front_grip_n);var rear:int=int(x.rear_grip_n)
	var sum:int=front+rear
	var requested:int=clampi(lateral,0,sum)
	x.front_lateral_n=mini(front,int(requested*front/maxi(1,sum)))
	x.rear_lateral_n=mini(rear,requested-int(x.front_lateral_n))
	x.front_reserve_n=root(front*front-int(x.front_lateral_n)*int(x.front_lateral_n))
	x.rear_reserve_n=root(rear*rear-int(x.rear_lateral_n)*int(x.rear_lateral_n))
	# RWD. Braking is constrained by both axles and the chosen bias.
	x.drive_limit_n=mini(aggregate_limit,int(x.rear_reserve_n))
	var bias:int=int(x.brake_bias)
	x.brake_limit_n=mini(aggregate_limit,mini(int(x.front_reserve_n)*1000/bias,int(x.rear_reserve_n)*1000/(1000-bias)))
	var imbalance:int=absi(int(x.fl)-int(x.fr))+absi(int(x.rl)-int(x.rr))
	x.wear_factor=1000+mini(200,imbalance*200/maxi(1,int(x.normal_n)))

