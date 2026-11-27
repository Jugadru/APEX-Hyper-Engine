extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var front = scene.menu_root.get_node_or_null("FrontDoor")
	if front == null: printerr("HYPER_MENU FAIL missing FrontDoor"); quit(1); return
	front.open_hyper()
	await process_frame
	var window = root.get_node_or_null("HyperLabWindow")
	var ok: bool = window != null and window.get_child_count() > 0
	if ok:
		var ui = window.get_child(0)
		ok = ui.circuit.item_count==20 and ui.team.item_count==12
		ui.career = preload("res://experimental/hyper/career.gd").new("user://hyper_qa_menu_career.bin")
		ui._open_career()
		await process_frame
		ok = ok and is_instance_valid(ui.career_window) and ui.career_body.get_child_count()>0
		if ok and not ui.career.active(): ui._career_new()
		ok = ok and ui.career.active()
		ui._career_refresh()
		await process_frame
		if DisplayServer.get_name() != "headless" and is_instance_valid(ui.career_window):
			var image: Image = ui.career_window.get_texture().get_image()
			if image != null and not image.is_empty(): image.save_png("res://qa/hyper/career.png")
		ui.career_window.queue_free()
		window.queue_free()
	await process_frame
	print("HYPER_MENU ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
