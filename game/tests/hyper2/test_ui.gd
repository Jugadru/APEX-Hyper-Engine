extends SceneTree
const Console=preload("res://experimental/hyper2/console.tscn")
func _initialize()->void:call_deferred("run")
func run()->void:
	var ui=Console.instantiate(); root.add_child(ui); await process_frame
	ui.checkpoint_path="user://hyper2_qa_checkpoint.bin"
	ui._start(); ui.running=false; ui.k.step_ticks(350); ui._redraw()
	var ok:bool=ui.k.initialized and ui.ranking.text.contains("Sebastian Vettel") and ui.map_view.rows.size()==24
	ui.accumulator=3.73; ui._speed(1.0); ok=ok and absf(ui.accumulator-0.13)<0.0001
	ui._save(); var hash_value:String=ui.k.sporting_hash(); ui.k.step_ticks(3); ui._load(); ok=ok and ui.k.sporting_hash()==hash_value
	ui.quality.observe(ui.k.state); ui.quality.observe(ui.k.state); ok=ok and ui.quality.report().observed_ticks==1
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame
		root.get_texture().get_image().save_png("res://qa/hyper2/console.png")
		ui._open_3d(); await process_frame; await process_frame; await process_frame
		ui.view_3d.feed(ui.k.state.cars,ui.selected_id)
		for i in range(10): await process_frame
		ok=ok and ui.view_3d.track_3d.live_cars.size()==24 and ui.k.sporting_hash()==hash_value
		var image:Image=ui.view_3d.viewport_3d.get_texture().get_image()
		if image!=null and not image.is_empty():image.save_png("res://qa/hyper2/tv3d.png")
		else:ok=false
	print("HYPER2_UI ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
