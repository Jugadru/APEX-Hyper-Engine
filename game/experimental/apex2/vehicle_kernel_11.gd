extends "res://experimental/apex2/simulation_kernel.gd"
## Experimental car motion only. The Core2 primary race session is unchanged.
const Vehicle = preload("res://experimental/apex2/vehicle_dynamics.gd")
const MODEL_TAG: String = "APEX2_VEHICLE_1.1_SYNTHETIC_GEOMETRY"

func initialize(scenario: Dictionary) -> bool:
	if not scenario.get("geometry_points", null) is Array:
		return false
	var geometry: Array = Vehicle.track_profile(scenario.geometry_points, int(scenario.get("lap_length_mm", 0)))
	if geometry.is_empty():
		return false
	if not super.initialize(scenario):
		return false
	var water: int = clampi(roundi(float(scenario.get("weather_observed", {}).get("wetness_factor", 0.0)) * 6000.0), 0, 6000)
	var ambient: int = clampi(roundi(float(scenario.get("weather_observed", {}).get("air_temp", 22.0)) * 100), -1000, 5500)
	state["vehicle_model"] = MODEL_TAG
	state["track_profile"] = geometry
	state["water_microns"] = water
	state["ambient_centi"] = ambient
	for car in state.cars:
		car["dynamics"] = Vehicle.initial_state(car, int(state.lap_length_mm), ambient)
	return true

func _advance_reference_car(car: Dictionary, _previous: int) -> void:
	var dynamics: Dictionary = car.dynamics
	var had_fuel: bool = int(dynamics.fuel_g) > 0
	var wear_before: int = int(dynamics.wear_micro)
	Vehicle.advance(car, state.track_profile, int(state.lap_length_mm), int(state.water_microns), int(state.ambient_centi), STEP_MS)
	car.progress_units = mini(int(state.race_laps) * LAP_UNITS, int(car.progress_units))
	if had_fuel and int(dynamics.fuel_g) == 0:
		_event("fuel_exhausted", int(car.id))
	if wear_before < 750000 and int(dynamics.wear_micro) >= 750000:
		_event("tire_wear_warning", int(car.id), {"wear_micro": int(dynamics.wear_micro)})

func restore(data: Dictionary) -> bool:
	if not data.get("state", null) is Dictionary:
		return false
	var candidate: Dictionary = data.state
	if str(candidate.get("vehicle_model", "")) != MODEL_TAG:
		return false
	if not candidate.get("track_profile", null) is Array or candidate.track_profile.is_empty():
		return false
	if int(candidate.get("lap_length_mm", 0)) < 1000000 or int(candidate.get("lap_length_mm", 0)) > 30000000:
		return false
	if int(candidate.get("hyper_evolution_revision",0)) in [5,6,7,8,9,10,11,12]:
		if candidate.track_profile.size()>1000:return false
		var last_start:int=-1
		for segment in candidate.track_profile:
			if not segment is Dictionary or typeof(segment.get("start_mm"))!=TYPE_INT or typeof(segment.get("radius_mm"))!=TYPE_INT:return false
			if int(segment.start_mm)<=last_start or int(segment.start_mm)>=int(candidate.lap_length_mm) or int(segment.radius_mm)<Vehicle.MIN_RADIUS_MM or int(segment.radius_mm)>Vehicle.MAX_RADIUS_MM:return false
			if last_start==-1 and int(segment.start_mm)!=0:return false
			last_start=int(segment.start_mm)
	if int(candidate.get("water_microns", -1)) < 0 or int(candidate.get("water_microns", -1)) > 6000:
		return false
	for car in candidate.get("cars", []):
		if not car is Dictionary or not car.get("dynamics", null) is Dictionary:
			return false
		var dyn: Dictionary = car.dynamics
		if not dyn.has_all(["model_schema", "distance_mm", "speed_mm_s", "fuel_g", "tire_temp_centi", "wear_micro", "wear_remainder", "distance_remainder", "wheel_power_w", "drag_milli", "downforce_milli", "dry_mass_kg", "fuel_burn_remainder"]):
			return false
		if int(dyn.model_schema) != 11 or int(dyn.speed_mm_s) < 0 or int(dyn.speed_mm_s) > Vehicle.MAX_V_MM_S:
			return false
		if int(dyn.fuel_g) < 0 or int(dyn.fuel_g) > 200000 or int(dyn.wear_micro) < 0 or int(dyn.wear_micro) > 1000000:
			return false
		if int(dyn.tire_temp_centi) < -1000 or int(dyn.tire_temp_centi) > 17000:
			return false
		if int(dyn.distance_remainder) < 0 or int(dyn.distance_remainder) >= 1000:
			return false
		if int(dyn.wear_remainder) < 0 or int(dyn.wear_remainder) >= 1000000000000:
			return false
		if int(dyn.fuel_burn_remainder) < 0 or int(dyn.fuel_burn_remainder) >= Vehicle.FUEL_ENERGY_J_PER_KG * Vehicle.ENGINE_EFFICIENCY_PERMILLE:
			return false
		if int(car.progress_units) != mini(int(candidate.race_laps) * LAP_UNITS, int(int(dyn.distance_mm) * LAP_UNITS / int(candidate.lap_length_mm))):
			# Initial grid converts progress to integer millimetres once. Before
			# movement, inverse rounding can differ by one progress unit.
			var projected_grid: int = int(int(car.progress_units) * int(candidate.lap_length_mm) / LAP_UNITS)
			if int(candidate.get("hyper_evolution_revision",0)) not in [2,3,4,5,6,7,8,9,10,11,12] or int(candidate.tick)>3 or int(car.progress_units)>0 or int(dyn.speed_mm_s)!=0 or int(dyn.distance_mm)!=projected_grid:
				return false
	return super.restore(data)
