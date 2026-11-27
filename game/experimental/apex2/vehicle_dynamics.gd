extends RefCounted
## APEX 2 / Vehicle Dynamics 1.1 (EXPERIMENTAL, NOT PRODUCTION PHYSICS).
## Integer, longitudinal point-mass vehicle model; isolated from Core2.
## Inputs/outputs: millimetres, milliseconds, grams, watts, newtons,
## centi-degrees Celsius, permille and micro-wear. No wall-clock or RNG.
## Normalized 2D circuit silhouettes are NOT surveyed track geometry;
## segment lengths/radii are synthetic approximations for isolated tests.
const Powertrain22 = preload("res://experimental/hyper2/powertrain_22.gd")
const Dynamics23 = preload("res://experimental/hyper2/dynamics_23.gd")
const STEP_MS: int = 200
const LAP_UNITS: int = 1000000
const MAX_V_MM_S: int = 106000
const MIN_RADIUS_MM: int = 28000
const MAX_RADIUS_MM: int = 1000000
const FUEL_ENERGY_J_PER_KG: int = 43000000
const ENGINE_EFFICIENCY_PERMILLE: int = 320
const WHEEL_POWER_W: int = 510000
const CAR_DRY_MASS_KG: int = 640
const TYRES: Dictionary = {
	"Macio": {"mu": 2050, "wear_per_km": 9900, "optimal_centi": 9500},
	"Médio": {"mu": 1910, "wear_per_km": 7000, "optimal_centi": 9000},
	"Duro": {"mu": 1790, "wear_per_km": 5200, "optimal_centi": 8500},
	"Intermediário": {"mu": 1650, "wear_per_km": 8500, "optimal_centi": 7300},
	"Chuva": {"mu": 1530, "wear_per_km": 10400, "optimal_centi": 6800}
}

static func integer_sqrt(value: int) -> int:
	if value <= 0:
		return 0
	var x: int = value
	var y: int = int((x + 1) / 2)
	while y < x:
		x = y
		y = int((x + int(value / x)) / 2)
	return x

static func track_profile(points: Array, lap_mm: int) -> Array:
	if lap_mm < 1000000 or lap_mm > 30000000 or points.size() < 8 or points.size() > 1000:
		return []
	var vertices: Array[Vector2i] = []
	for point in points:
		if not point is Array or point.size() != 2:
			return []
		var x: float = float(point[0])
		var y: float = float(point[1])
		if not is_finite(x) or not is_finite(y) or x < -1.0 or x > 2.0 or y < -1.0 or y > 2.0:
			return []
		var vertex: Vector2i = Vector2i(roundi(x * 1000000.0), roundi(y * 1000000.0))
		if vertices.is_empty() or vertex != vertices[-1]:
			vertices.append(vertex)
	if vertices.size() > 1 and vertices[0] == vertices[-1]:
		vertices.pop_back()
	if vertices.size() < 8:
		return []
	var lengths: Array[int] = []
	var total_units: int = 0
	for i in range(vertices.size()):
		var a: Vector2i = vertices[i]
		var b: Vector2i = vertices[(i + 1) % vertices.size()]
		var dx: int = b.x - a.x
		var dy: int = b.y - a.y
		var length: int = maxi(1, integer_sqrt(dx * dx + dy * dy))
		lengths.append(length)
		total_units += length
	if total_units < 1000:
		return []
	var profile: Array = []
	var accumulated: int = 0
	for i in range(vertices.size()):
		var prev: Vector2i = vertices[(i + vertices.size() - 1) % vertices.size()]
		var cur: Vector2i = vertices[i]
		var next: Vector2i = vertices[(i + 1) % vertices.size()]
		var ab: int = lengths[(i + vertices.size() - 1) % vertices.size()]
		var bc: int = lengths[i]
		var d: Vector2i = next - prev
		var ca: int = maxi(1, integer_sqrt(d.x * d.x + d.y * d.y))
		var cross: int = absi((cur.x - prev.x) * (next.y - cur.y) - (cur.y - prev.y) * (next.x - cur.x))
		# Circumradius R=abc/(2 cross), scaled by silhouette perimeter.
		var radius: int = MAX_RADIUS_MM
		if cross > 0:
			var raw: int = int(ab * bc * ca / (2 * cross))
			radius = clampi(int(raw * lap_mm / total_units), MIN_RADIUS_MM, MAX_RADIUS_MM)
		profile.append({"start_mm": int(accumulated * lap_mm / total_units), "radius_mm": radius})
		accumulated += lengths[i]
	return profile

static func initial_state(car: Dictionary, lap_mm: int, ambient_centi: int) -> Dictionary:
	var initial_progress: int = int(car.progress_units)
	return {
		"model_schema": 11,
		"distance_mm": int(initial_progress * lap_mm / LAP_UNITS),
		"distance_remainder": 0,
		"speed_mm_s": 0,
		"fuel_g": 150000,
		"fuel_burn_remainder": 0,
		"tire_temp_centi": ambient_centi + 700,
		"wear_micro": 0,
		"wear_remainder": 0,
		"wheel_power_w": WHEEL_POWER_W,
		"drag_milli": 1130,
		"downforce_milli": 2650,
		"dry_mass_kg": CAR_DRY_MASS_KG,
		"last_force_n": 0,
		"last_brake_n": 0,
		"last_grip_n": 0,
		"last_target_speed_mm_s": 0
	}

static func _pace_throttle(pace: String) -> int:
	match pace:
		"Atacar": return 1000
		"Conservar": return 770
	return 910

static func friction_mu(compound: String, water_microns: int, temperature_centi: int, wear_micro: int) -> int:
	var spec: Dictionary = TYRES.get(compound, TYRES["Médio"])
	var water_multiplier: int = 1000
	if compound in ["Macio", "Médio", "Duro"]:
		water_multiplier = clampi(1000 - int(water_microns / 10), 400, 1000)
	elif compound == "Intermediário":
		water_multiplier = clampi(660 + int(water_microns * 95 / 1000), 660, 1120)
	elif compound == "Chuva":
		water_multiplier = clampi(540 + int(water_microns * 105 / 1000), 540, 1140)
	var temp_delta: int = absi(temperature_centi - int(spec.optimal_centi))
	var thermal_multiplier: int = clampi(1000 - int(temp_delta * 55 / 1000), 680, 1000)
	var wear_multiplier: int = clampi(1000 - int(wear_micro / 1600), 480, 1000)
	return maxi(100, int(int(int(spec.mu) * water_multiplier / 1000) * thermal_multiplier / 1000) * wear_multiplier / 1000)

static func _aero_force_n(coefficient_milli: int, speed_mm_s: int) -> int:
	# F=0.5 * (rho * effective_area) * v^2. coefficient_milli = rho*A*1000.
	return maxi(0, int(coefficient_milli * speed_mm_s * speed_mm_s / 2000000000))

static func _grip_force_n(mass_kg: int, speed_mm_s: int, mu_permille: int, downforce_milli: int) -> int:
	var vertical_n: int = int(mass_kg * 981 / 100) + _aero_force_n(downforce_milli, speed_mm_s)
	return maxi(0, int(mu_permille * vertical_n / 1000))

static func _corner_cap_mm_s(radius_mm: int, mass_kg: int, mu: int, downforce_milli: int) -> int:
	if radius_mm >= MAX_RADIUS_MM:
		return MAX_V_MM_S
	# Closed-form lateral equilibrium for point-mass model:
	# m*v²/R = mu*(m*g + downforce(v²)). Integers keep results reproducible.
	var denominator: int = mass_kg * 2000000000 - mu * downforce_milli * radius_mm
	if denominator <= 0:
		return MAX_V_MM_S
	var numerator: int = mu * mass_kg * 981 * 20 * radius_mm
	return mini(MAX_V_MM_S, integer_sqrt(int(numerator / denominator) * 1000000))

static func _profile_index(profile: Array, location_mm: int) -> int:
	var low: int = 0
	var high: int = profile.size()
	while low + 1 < high:
		var middle: int = int((low + high) / 2)
		if int(profile[middle].start_mm) <= location_mm:
			low = middle
		else:
			high = middle
	return low

static func advance(car: Dictionary, profile: Array, lap_mm: int, water_microns: int, ambient_centi: int, step_ms: int = STEP_MS) -> void:
	var dyn: Dictionary = car.dynamics
	var old_velocity: int = int(dyn.speed_mm_s)
	var advanced: bool = dyn.has(Powertrain22.KEY)
	var combined: bool = dyn.has(Dynamics23.KEY)
	var mass_kg: int = int(dyn.dry_mass_kg) + int(dyn.fuel_g / 1000)
	var mu: int = friction_mu(str(car.tire), water_microns, int(dyn.tire_temp_centi), int(dyn.wear_micro))
	if car.has("hyper_setup_grip_permille"): mu=int(mu*clampi(int(car.hyper_setup_grip_permille),980,1030)/1000)
	var grip_n: int = _grip_force_n(mass_kg, old_velocity, mu, int(dyn.downforce_milli))
	var brake_decel: int = maxi(2500, int(grip_n * 1000 / mass_kg))
	var position_mm: int = posmod(int(dyn.distance_mm), lap_mm)
	var index: int = _profile_index(profile, position_mm)
	var cap: int = MAX_V_MM_S
	var load: Dictionary = {}
	var corner_margin: int = 1000
	var lateral_demand: int = 0
	var budget: Dictionary = {}
	var long_limit: int = grip_n
	if combined:
		load= Dynamics23.loads(mass_kg,_aero_force_n(int(dyn.downforce_milli),old_velocity),int(dyn[Dynamics23.KEY].accel_mm_s2))
		grip_n=int(grip_n*int(load.scale)/1000)
		corner_margin=Dynamics23.margin(car,water_microns)
		var radius_now:int=int(profile[index].radius_mm)
		# The sentinel describes a straight, not a physical 1000 m curve.
		lateral_demand=0 if radius_now>=MAX_RADIUS_MM else int(mass_kg*old_velocity*old_velocity/maxi(1,radius_now*1000))
		budget=Dynamics23.budget(grip_n,lateral_demand)
		long_limit=int(budget.long_limit_n)
		brake_decel=maxi(2500,int(long_limit*1000/mass_kg))
	# Anticipate upcoming geometry by stopping-distance energy equation v²=v0²+2*a*s.
	for ahead in range(mini(10, profile.size())):
		var k: int = (index + ahead) % profile.size()
		var point: Dictionary = profile[k]
		var next_pos: int = int(point.start_mm)
		var distance: int = posmod(next_pos - position_mm, lap_mm)
		if ahead == 0:
			distance = 0
		if distance > 850000:
			break
		var corner_limit: int = _corner_cap_mm_s(int(point.radius_mm), mass_kg, mu, int(dyn.downforce_milli))
		if combined and int(point.radius_mm)<MAX_RADIUS_MM:
			corner_limit=int(corner_limit*corner_margin/1000)
		var approach_decel: int = brake_decel
		if advanced:
			# Conservative endpoint grip instead of relying on high-speed downforce
			# that disappears while slowing for the corner.
			approach_decel = maxi(2500,int(_grip_force_n(mass_kg,mini(old_velocity,corner_limit),mu,int(dyn.downforce_milli))*1000/mass_kg))
		if combined: approach_decel=maxi(1500,int(approach_decel*800/1000))
		var stopping_cap: int = mini(MAX_V_MM_S, integer_sqrt(corner_limit * corner_limit + 2 * approach_decel * distance))
		cap = mini(cap, stopping_cap)
	# 1.3 opt-in traffic braking envelope; absent for all legacy 1.1/1.2 runs.
	# The cap limits target speed, never boosts acceleration or teleports the car.
	if car.has("traffic_speed_cap_mm_s"):
		cap = mini(cap, clampi(int(car.traffic_speed_cap_mm_s), 0, MAX_V_MM_S))
	# Power-to-wheel tractive force P/v, limited by longitudinal tyre traction.
	var throttle: int = _pace_throttle(str(car.pace))
	var power_requested_w: int = int(int(dyn.wheel_power_w) * throttle / 1000) if int(dyn.fuel_g) > 0 else 0
	var engine_n: int = mini(grip_n, int(power_requested_w * 1000 / maxi(14000, old_velocity)))
	var drag_n: int = _aero_force_n(int(dyn.drag_milli), old_velocity)
	var rolling_n: int = int(mass_kg * 14 / 100)
	var available_drive_n: int = engine_n - drag_n - rolling_n if car.has("hyper") else maxi(0, engine_n - drag_n - rolling_n)
	var braking: bool = old_velocity > cap
	var brake_force: int = grip_n if braking else 0
	if combined: brake_force=Dynamics23.brake_force(old_velocity,cap,mass_kg,drag_n+rolling_n,long_limit,step_ms)
	if advanced:
		var offer: int = int(car.get("hyper_kers_power_w",0))
		var base_power: int = maxi(0,int(dyn.wheel_power_w)-offer) if int(dyn.fuel_g)>0 else 0
		var p: Dictionary = Powertrain22.evaluate(dyn[Powertrain22.KEY],old_velocity,throttle,base_power,offer if base_power>0 else 0,long_limit,braking,step_ms)
		p.drag_n=drag_n;p.rolling_n=rolling_n;p.mass_g=int(dyn.dry_mass_kg)*1000+int(dyn.fuel_g)
		dyn[Powertrain22.KEY]=p
		engine_n=int(p.engine_force_n)
		available_drive_n=engine_n-drag_n-rolling_n
	var force_n: int = -brake_force if braking else available_drive_n
	if advanced and braking: force_n-=drag_n+rolling_n
	var acceleration_mm_s2: int = int(force_n * 1000 / mass_kg)
	var next_speed: int = clampi(old_velocity + int(acceleration_mm_s2 * step_ms / 1000), 0, MAX_V_MM_S)
	if not braking:
		next_speed = mini(next_speed, cap if combined else cap + maxi(1500, int(brake_decel * step_ms / 1000)))
	var distance_numerator: int = int((old_velocity + next_speed) * step_ms / 2) + int(dyn.distance_remainder)
	var distance_delta_mm: int = maxi(0, int(distance_numerator / 1000))
	dyn.distance_remainder = posmod(distance_numerator, 1000)
	dyn.distance_mm = int(dyn.distance_mm) + distance_delta_mm
	dyn.speed_mm_s = next_speed
	if advanced: dyn[Powertrain22.KEY].rpm=clampi(Powertrain22.raw_rpm(next_speed,int(dyn[Powertrain22.KEY].gear)),Powertrain22.IDLE,Powertrain22.LIMIT)
	dyn.last_force_n = force_n
	dyn.last_brake_n = brake_force
	dyn.last_grip_n = grip_n
	dyn.last_target_speed_mm_s = cap
	if combined:
		var info:Dictionary=dyn[Dynamics23.KEY]
		info.front_n=int(load.front_n);info.rear_n=int(load.rear_n);info.transfer_n=int(load.transfer_n)
		info.grip_n=grip_n;info.lateral_demand_n=lateral_demand;info.lateral_alloc_n=int(budget.lateral_alloc_n)
		info.long_limit_n=long_limit;info.long_used_n=brake_force if braking else engine_n
		info.reserve_permille=int(budget.reserve_permille);info.saturated=bool(budget.saturated)
		info.accel_mm_s2=int((next_speed-old_velocity)*1000/maxi(1,step_ms));info.margin_permille=corner_margin
		info.phase=Dynamics23.phase(int(profile[index].radius_mm),int(profile[(index+1)%profile.size()].radius_mm),int(profile[posmod(index-1,profile.size())].radius_mm))
		info.target_mm_s=cap
	# Energy at the wheels / assumed overall efficiency * petrol energy density.
	var delivered_power_w: int = mini(power_requested_w, int(engine_n * old_velocity / 1000)) if not braking else 0
	if advanced:
		delivered_power_w=int(dyn[Powertrain22.KEY].v8_wheel_w)
	elif car.has("hyper_kers_power_w"):
		delivered_power_w = maxi(0, delivered_power_w - int(car.hyper_kers_power_w))
	# Hyper fixes the legacy experimental unit conversion (1000x too high).
	# W * ms -> J, then kg -> g; permille efficiency adds one factor of 1000.
	# Historical 1.1–1.3 behavior is unchanged for replay and rollback.
	var fuel_scale: int = 1000 if car.has("hyper") else 1000000
	var fuel_numerator: int = int((delivered_power_w + 22000) * step_ms * fuel_scale) + int(dyn.fuel_burn_remainder)
	var fuel_divisor: int = FUEL_ENERGY_J_PER_KG * ENGINE_EFFICIENCY_PERMILLE
	var fuel_used_g: int = int(fuel_numerator / fuel_divisor)
	dyn.fuel_burn_remainder = fuel_numerator % fuel_divisor
	dyn.fuel_g = maxi(0, int(dyn.fuel_g) - fuel_used_g)
	# Wear arises from travelled distance, compound, heat excess and lateral demand.
	var spec: Dictionary = TYRES.get(str(car.tire), TYRES["Médio"])
	var temperature_excess: int = maxi(0, int(dyn.tire_temp_centi) - int(spec.optimal_centi) - 900)
	var thermal_wear_permille: int = mini(1700, 1000 + int(temperature_excess / 20))
	var radius: int = int(profile[index].radius_mm)
	var lateral_force: int = int(mass_kg * old_velocity * old_velocity / maxi(1, radius * 1000))
	var lateral_use: int = mini(1000, int(lateral_force * 1000 / maxi(1, grip_n)))
	var work_multiplier: int = 1000 + int(lateral_use / 3) + (220 if braking else 0)
	var wear_rate: int = int(spec.wear_per_km)
	if car.has("hyper"):
		# Initial gameplay calibration, not measured tyre data. Preserve thermal load.
		wear_rate = int(wear_rate * (420 if str(car.tire) in ["Chuva", "Intermediário"] else 550) / 1000)
	var wear_numerator: int = distance_delta_mm * wear_rate * thermal_wear_permille * work_multiplier + int(dyn.wear_remainder)
	var wear_divisor: int = 1000000000000
	dyn.wear_micro = mini(1000000, int(dyn.wear_micro) + int(wear_numerator / wear_divisor))
	dyn.wear_remainder = wear_numerator % wear_divisor
	var temp_gain: int = 7 + int(lateral_use * 14 / 1000) + (12 if braking else 0) + int(throttle * 5 / 1000)
	var air_cooling: int = int((int(dyn.tire_temp_centi) - ambient_centi) / (500 if water_microns >= 3000 else 720))
	dyn.tire_temp_centi = clampi(int(dyn.tire_temp_centi) + temp_gain - air_cooling, ambient_centi, 17000)
	# Progress is derived exclusively from integrated physical travel distance.
	car.progress_units = int(int(dyn.distance_mm) * LAP_UNITS / lap_mm)
	car.progress_remainder = 0
