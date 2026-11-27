extends SceneTree
const K = preload("res://experimental/hyper/kernel.gd")
const S = preload("res://experimental/hyper/scenario.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	var failures: Array = []
	for track in data.tracks:
		var k = K.new()
		if not k.initialize(S.create(str(track.code),"Seco",2026)) or k.step_ticks(20)!=20 or k.state.cars.size()!=24:
			failures.append(str(track.code))
	for team in data.teams:
		var scenario: Dictionary = S.create("ITA","Seco",2026,str(team.name))
		var n: int = 0
		for car in scenario.cars:
			if str(car.team)==str(team.name): n += 1
		if n!=2: failures.append(str(team.name))
	print("HYPER_CALENDAR ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","tracks":data.tracks.size(),"teams":data.teams.size(),"ticks_per_track":20,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
