extends SceneTree
## Real Godot Compatibility render (not a fabricated mockup).
const Factory = preload("res://experimental/apex2/session_factory.gd")
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func capture(label: String, size: Vector2i) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = size
	for frame_i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() != size.x or img.get_height() != size.y:
		errors.append("render dimensions " + label)
		return
	var path: String = "res://qa/apex2_primary_06682/" + label + ".png"
	if img.save_png(path) != OK: errors.append("save " + label)
	else: print("APEX2_PRIMARY_CAPTURE_PASS ",path," ",size)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	var host = load("res://scenes/main.tscn").instantiate()
	root.add_child(host)
	for i in range(8): await process_frame
	host.set_process(false)
	host._start_race()
	if not host.replay_session.get_script().resource_path.contains("primary_session"):
		errors.append("primary runtime not selected")
	host.race.running = true
	for i in range(100): host._process(1.0/60.0)
	host.race.running = false
	host._process(1.0/60.0)
	if host.render_mode != 1: errors.append("auto 3D default")
	await capture("APEX2_06682_3D_COMPACT_1600x900",Vector2i(1600,900))
	host._change_speed(3)
	host._process(1.0/60.0)
	if host.render_mode != 0: errors.append("10x auto 2D")
	await capture("APEX2_06682_2D_COMPACT_1920x1080",Vector2i(1920,1080))
	print("APEX2_PRIMARY_VISUAL_", "PASS" if errors.is_empty() else "FAIL", " errors=", errors)
	quit(0 if errors.is_empty() else 1)
