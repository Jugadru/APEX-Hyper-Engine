extends SceneTree
const Primary = preload("res://experimental/apex2/primary_session.gd")
var checks: int = 0
var problems: Array[String] = []
func test(ok: bool, label: String) -> void:
	checks += 1
	if not ok: problems.append(label); printerr("APEX2_PRIMARY_SCENE_FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,900)
	var host = load("res://scenes/main.tscn").instantiate()
	root.add_child(host)
	await process_frame
	host.set_process(false)
	host._start_race()
	await process_frame
	test(host.race != null, "real race created")
	test(host.replay_session is Primary, "game uses APEX2 primary session")
	test(host.heading_label.text.contains("APEX 2") and host.heading_label.text.contains("CORE 2"), "clear hybrid label")
	test(host.render_mode == 1, "3D is default at 1x")
	test(host.race_hud_0620 != null and host.race_hud_0620.standing_rows.size() == 24, "HUD ReBroadcast 24 driver slots")
	var h = host.replay_session
	var car: Dictionary = host.race.player_cars()[0]
	var id: int = int(car.id)
	var tire: String = str(host.race.available_pit_compounds()[1])
	test(host.race.schedule_pit(id,tire,21), "pit order via actual race API")
	test(h.step_tick(), "primary delivers first tick")
	test(int(car.pit_scheduled_lap)==21, "manual V21 registered")
	var next_hash: String = str(h.hashes[-1])
	for mode in range(3):
		host.race_hud_0620._change_hud_mode(mode)
		host.race_hud_0620.refresh_hud()
		test(str(h.hashes[-1]) == next_hash, "HUD switch %d no sports changes" % mode)
	for speed in [1.0, 2.0, 5.0, 10.0, 16.0, 32.0]:
		host.sim_speed = speed
		host.visual_setting = 0
		host._apply_visual_from_setting()
		test(host.render_mode == (1 if speed <= 5.0 else 0), "auto 3D/2D speed %d" % int(speed))
	host.race_hud_0620._change_hud_mode(1)
	print("APEX2_PRIMARY_SCENE_%s checks=%d problems=%s" % ["PASS" if problems.is_empty() else "FAIL", checks, str(problems)])
	quit(0 if problems.is_empty() else 1)
