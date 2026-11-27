extends RefCounted
## Integer approximation; no surveyed aero coefficients or official DRS zones.
static func valid_weather(events: Variant) -> bool:
	if not events is Array or events.size() > 128: return false
	var last: int = 0
	for event in events:
		if not event is Dictionary or typeof(event.get("tick")) != TYPE_INT or typeof(event.get("water")) != TYPE_INT: return false
		if int(event.tick) <= last or int(event.tick) > 400000 or int(event.water) < 0 or int(event.water) > 6000: return false
		last = int(event.tick)
	return true

static func wake(gap: int, radius: int) -> Dictionary:
	var proximity: int = clampi(1000 - int(gap * 1000 / 65000), 0, 1000) if gap > 0 else 0
	var corner: int = clampi(int((350000 - radius) * 1000 / 300000), 0, 1000)
	return {"drag": 1000 - int(130 * proximity * (1000 - corner) / 1000000), "downforce": 1000 - int(230 * proximity * corner / 1000000)}

static func pit_advice(car: Dictionary, available: Array, water: int, remaining: int) -> Dictionary:
	var current: String = str(car.tire)
	var wet: bool = current in ["Chuva", "Intermediário"]
	var target: String = current
	var reason: String = "stay_out"
	var wear: int = int(car.dynamics.wear_micro)
	if water >= 3900 and current != "Chuva":
		target = "Chuva"
		reason = "heavy_rain"
	elif water >= 1900 and water < 3200 and current != "Intermediário":
		target = "Intermediário"
		reason = "wet_track"
	elif water <= 700 and wet:
		target = "Médio" if "Médio" in available else "Duro"
		reason = "drying_track"
	elif wear >= 500000 and remaining >= 3:
		if not wet:
			for compound in ["Duro", "Médio", "Macio"]:
				if compound in available and compound != current:
					target = compound
					break
		reason = "tire_wear"
	elif water <= 700 and not wet and remaining <= 5 and remaining >= 2 and car.hyper.compounds_used.size() == 1:
		for compound in ["Duro", "Médio", "Macio"]:
			if compound in available and compound != current:
				target = compound
				reason = "dry_compound_change"
				break
	return {"stop": reason != "stay_out" and target in available, "compound": target, "reason": reason}

static func valid_zones(zones: Variant) -> bool:
	if not zones is Array or zones.size() > 4: return false
	for z in zones:
		if not z is Dictionary or not z.has_all(["detect","start","end"]): return false
		for key in ["detect","start","end"]:
			if typeof(z[key]) != TYPE_INT: return false
		if int(z.detect) < 0 or int(z.detect) >= int(z.start) or int(z.start) >= int(z.end) or int(z.end) >= 1000000: return false
	return true

static func drs_update(car: Dictionary, zones: Array, front_gap_mm: int, water: int) -> void:
	var h: Dictionary = car.hyper
	var current: int = int(car.progress_units)
	var old: int = int(h.drs_prev_progress)
	h.drs_prev_progress = current
	h.drs_active = false
	var lap: int = int(maxi(0,current)/1000000)
	if int(h.drs_armed_lap) != lap:
		h.drs_armed_lap = lap
		h.drs_armed = []
	if bool(car.finished) or str(car.pit_stage) != "TRACK" or water > 700 or lap < 2:
		h.drs_armed = []
		return
	var speed: int = int(car.dynamics.speed_mm_s)
	for i in range(zones.size()):
		var z: Dictionary = zones[i]
		var detection: int = lap*1000000 + int(z.detect)
		if old < detection and current >= detection and front_gap_mm > 0 and speed >= 25000 and front_gap_mm <= speed:
			if not i in h.drs_armed: h.drs_armed.append(i)
		var fraction: int = posmod(current,1000000)
		if i in h.drs_armed and fraction >= int(z.start) and fraction <= int(z.end): h.drs_active = true
