extends RefCounted
## Rev15: early wet attack opportunity. No force, pace or grip bonuses.
## Existing geometry, reserve, protected-driver and lane checks still apply.
const Geometry=preload("res://experimental/hyper2/geometry_302.gd")
const Style=preload("res://experimental/hyper2/racecraft_305.gd")
const BASE_MM:=29000
const MAX_MM:=39000
const MIN_CLOSING:=2500
const WATER_MIN:=2000
static func window(car:Dictionary,gap:int,closing:int,water:int)->bool:
	# Only real closing, bounded by a six-second projected approach to
	# the normal 22m following zone. Do not extend for a matched-speed car.
	if water<WATER_MIN or gap<=BASE_MM or gap>MAX_MM or closing<MIN_CLOSING:return false
	if gap>22000+closing*6:return false
	if Style.protected(car):return false
	var wet:Dictionary=car.wet_303
	# Uncertain grip immediately after weather change is not an opportunity.
	return int(wet.confidence)>=750 and absi(water-int(wet.observed_water))<=500
static func reason(car:Dictionary,profile:Array,lap:int,distance:int,gap:int,closing:int,water:int)->String:
	if not window(car,gap,closing,water):return "gap"
	# Preserve the existing centreline corridor constraint at 15m and
	# inspect the approach to the other car before early commitment.
	for offset in [gap/2,gap]:
		if Geometry.radius_at(profile,lap,distance+int(offset))<125000:return "geometry"
	return Style.reason(car,profile,lap,distance,gap,closing,water,MAX_MM)
