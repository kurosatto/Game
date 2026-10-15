# sightshots.gd
# The vision fog at a few eye ratings (blind cell, dim, good, superb), for
# tuning VisionFog.set_vision. Needs a window, not --headless.
# Run: SHOT_DIR=<folder> SHOT_SIZE=2340x1080 godot --path . -s res://tools/sightshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	var size_env := OS.get_environment("SHOT_SIZE")
	if size_env != "":
		var parts = size_env.split("x")
		for i in 5: await process_frame
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		for i in 5: await process_frame
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		for i in 10: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.get_node("TouchControls").visible = true
	main.hud.use_touch_texts()
	var fog = main.get_node("VisionFog")
	for r in [1, 3, 6, 10]:
		fog.set_vision(r, true)
		for i in 5: await process_frame
		await snap("vision_%02d" % r)
	quit()
