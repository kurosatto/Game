# menufit.gd
# The main menu at phone, PC and Legion Go sizes, plus its MORE page, with a
# played-in save (some runs and challenges done). Needs a window:
#   SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/menufit.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var progress = load("res://data/Progress.gd")
	for c in progress.CHALLENGES.slice(0, 3):
		progress.complete(c.id)
	progress.set_start_trait(progress.unlocked_traits()[0])
	if progress.run_stats().count == 0:
		progress.record_run(3, "Trilobite", false, {})
		progress.record_run(4, "Eurypterid", false, {})
	for i in 5: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for sz in [["phone", Vector2i(2340, 1080)], ["pc", Vector2i(1920, 1080)], ["legion_go", Vector2i(2560, 1600)]]:
		DisplayServer.window_set_size(sz[1])
		for i in 10: await process_frame
		var menu = load("res://MainMenu.tscn").instantiate()
		root.add_child(menu)
		for i in 20: await process_frame
		await snap("menu_" + sz[0])
		if sz[0] == "phone" and menu.has_method("show_more"):
			menu.show_more()
			await snap("more_phone")
		menu.queue_free()
		for i in 3: await process_frame
	quit()
