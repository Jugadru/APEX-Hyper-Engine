extends RefCounted
## Rev15 candidate B: reconcile PREPARE gap with the existing following floor.
## Only a narrow already-following case; no speed, grip or position bonus.
const Style=preload("res://experimental/hyper2/racecraft_305.gd")
const Geometry=preload("res://experimental/hyper2/geometry_302.gd")
const FOLLOW_FLOOR_MM:=10000
const WATER_MIN:=4001
static func window(car:Dictionary,defender:Dictionary,gap:int,closing:int,water:int)->bool:
	if water<WATER_MIN or gap<FOLLOW_FLOOR_MM or gap>=8000+water/2:return false
	if closing< -150 or closing>1000 or Style.protected(car):return false
	if bool(defender.finished) or str(defender.pit_stage)!="TRACK" or str(car.racecraft.lane)!=str(defender.racecraft.lane):return false
	var wet:Dictionary=car.wet_303
	return int(car.racecraft_305.initiative)>=500 and int(wet.control)>=65 and int(wet.confidence)>=750 and absi(water-int(wet.observed_water))<=500
static func reason(car:Dictionary,defender:Dictionary,profile:Array,lap:int,distance:int,gap:int,closing:int,water:int)->String:
	if not window(car,defender,gap,closing,water):return "gap"
	# Keep an additional generous corridor constraint in this close band.
	if mini(Geometry.radius_at(profile,lap,distance),Geometry.radius_at(profile,lap,distance+15000))<350000:return "geometry"
	return Style.reason(car,profile,lap,distance,gap,closing,water,FOLLOW_FLOOR_MM)
