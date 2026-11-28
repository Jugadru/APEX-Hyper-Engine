extends RefCounted
## Rev15 candidate B: reconcile PREPARE gap with the existing following floor.
## Only a narrow already-following case; no speed, grip or position bonus.
const Style=preload("res://experimental/hyper2/racecraft_305.gd")
const Geometry=preload("res://experimental/hyper2/geometry_302.gd")
const FOLLOW_FLOOR_MM:=10000
const WATER_MIN:=4001
static func window(car:Dictionary,defender:Dictionary,gap:int,closing:int,water:int)->bool:
	return gate_reason(car,defender,gap,closing,water)=="eligible"

static func gate_reason(car:Dictionary,defender:Dictionary,gap:int,closing:int,water:int)->String:
	if water<WATER_MIN:return "water"
	if gap<FOLLOW_FLOOR_MM:return "below_floor"
	if gap>=8000+water/2:return "above_band"
	if closing< -150:return "opening_gap"
	if closing>1000:return "closing_fast"
	if Style.protected(car):return "driver_protected"
	if bool(defender.finished) or str(defender.pit_stage)!="TRACK":return "target_unavailable"
	if str(car.racecraft.lane)!=str(defender.racecraft.lane):return "different_lane"
	var wet:Dictionary=car.wet_303
	if int(car.racecraft_305.initiative)<500:return "initiative"
	if int(wet.control)<65:return "control"
	if int(wet.confidence)<750:return "confidence"
	if absi(water-int(wet.observed_water))>500:return "adaptation"
	return "eligible"

static func count_sample(audit:Dictionary,key:String)->void:
	if not audit.has("enabled"):return
	audit[key]=int(audit.get(key,0))+1

static func climate(water:int)->String:
	if water<=700:return "dry"
	if water<=4000:return "wet"
	return "deep"
static func reason(car:Dictionary,defender:Dictionary,profile:Array,lap:int,distance:int,gap:int,closing:int,water:int)->String:
	if not window(car,defender,gap,closing,water):return "gap"
	# Keep an additional generous corridor constraint in this close band.
	if mini(Geometry.radius_at(profile,lap,distance),Geometry.radius_at(profile,lap,distance+15000))<350000:return "geometry"
	return Style.reason(car,profile,lap,distance,gap,closing,water,FOLLOW_FLOOR_MM)
