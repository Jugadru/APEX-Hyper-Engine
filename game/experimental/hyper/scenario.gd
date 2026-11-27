extends RefCounted
const Drs = preload("res://scripts/core/race_drs_2012.gd")
const Adapter = preload("res://experimental/apex2/scenario_adapter.gd")
static func create(code: String, weather: String, seed_value: int, team: String = "Ferrari", auto_pit: bool = true, wet_setup: int = 0) -> Dictionary:
	var pair: Dictionary = Adapter.create_pair(code, weather, seed_value, team)
	if pair.is_empty(): return {}
	var s: Dictionary = pair.scenario
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	var specs: Dictionary = {}
	var ratings: Dictionary = {}
	for t in data.teams:
		ratings[str(t.name)] = int(t.car)
	for car in s.cars:
		var rating: int = int(ratings.get(str(car.team), 80))
		specs[str(car.id)] = {"power": 480000 + rating * 450, "drag": 1210 - rating, "downforce": 2300 + rating * 5, "wet_setup": wet_setup if str(car.team) == team else (650 if weather == "Chuva intensa" else 0)}
	for track in data.tracks:
		if str(track.code) == code:
			s.hyper_pit_loss_ms = roundi(float(track.get("pit_loss", 21.0)) * 1000.0)
			s.hyper_drs_zones = []
			for zone in Drs.zones(track):
				s.hyper_drs_zones.append({"detect": roundi(float(zone.detect)*1000000.0), "start": roundi(float(zone.start)*1000000.0), "end": roundi(float(zone.end)*1000000.0)})
	s.hyper_specs = specs
	s.hyper_player_team = team
	s.hyper_player_pit_auto = auto_pit
	return s
