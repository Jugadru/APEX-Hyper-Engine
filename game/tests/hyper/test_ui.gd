extends SceneTree
const Console = preload("res://experimental/hyper/console.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ui = Console.instantiate()
	root.add_child(ui)
	ui.checkpoint_path = "user://hyper_qa_ui_checkpoint.bin"
	await process_frame
	ui._start()
	ui.running = false
	var ok: bool = ui.k.initialized and ui.driver.item_count == 2 and ui.compound.item_count >= 2
	ui.k.step_ticks(350)
	ui._redraw()
	ok = ok and ui.ranking.text.contains("Sebastian Vettel") and ui.map_view.rows.size() == 24
	# No write to user's real environment; this is an isolated QA user directory.
	ui._save()
	var hash_value: String = ui.k.sporting_hash()
	ui.k.step_ticks(10); ui._load()
	ok = ok and ui.k.sporting_hash() == hash_value and not ui.running
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		var image: Image = root.get_texture().get_image()
		if image != null and not image.is_empty(): image.save_png("res://qa/hyper/console_%d.png" % [root.size.x])
	print("HYPER_UI ","PASS" if ok else "FAIL", " drivers=",ui.driver.item_count," rows=",ui.map_view.rows.size())
	quit(0 if ok else 1)
