extends SceneTree
## Real Core2 weather and pit strategy operated via APEX2 primary controller.
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
const Factory = preload("res://experimental/apex2/session_factory.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var pair: Dictionary = Adapter.create_pair("BEL", "Chuva intensa", 6701)
	assert(not pair.is_empty())
	var race = pair.core
	var car: Dictionary = race.player_cars()[0]
	var car_id: int = int(car.id)
	var tire: String = str(race.available_pit_compounds()[-1])
	var session = Factory.create(race)
	assert(race.schedule_pit(car_id,tire,21))
	race.running = true
	var samples: Array = []
	while race.lap < 5 and session.tick < 6000 and not race.finished:
		assert(session.step_tick(),session.error)
		if session.tick % 400 == 0:
			samples.append({"tick":session.tick,"lap":race.lap,"scheduled":int(car.pit_scheduled_lap),"pit_request":bool(car.pit_request),"stops":int(car.stops)})
		assert(int(car.pit_scheduled_lap)==21,"Manual V21 must remain scheduled during early heavy rain")
		assert(int(car.stops)==0 and not bool(car.pit_request),"Manual V21 must not pit early")
	assert(race.lap >= 5, "Reached lap 5 in genuine wet race")
	assert(session.apex2_verified_ticks == session.tick)
	print("APEX2_PRIMARY_V21_WET_PASS ",JSON.stringify({"ticks":session.tick,"laps":race.lap,"samples":samples,"hash":session.hashes[-1]}))
	quit(0)
