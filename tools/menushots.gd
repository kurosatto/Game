# menushots.gd
# Screenshots of the main menu, its challenge and codex pages, and the pause
# screen's info panel. Needs a window (xvfb-run on Linux):
#   SHOT_DIR=<folder> godot --path . -s res://tools/menushots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	for i in 5: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2340, 1080))
	for i in 10: await process_frame
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 20: await process_frame
	await snap("menu")
	menu.show_challenges()
	await snap("menu_challenges")
	menu.show_codex()
	await snap("menu_codex")
	menu.queue_free()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.player.grant_adaptation("muscle")
	main.player.grant_adaptation("toxins")
	main.hud.show_item_banner("PIKAIA CHORDATE", "One of the earliest chordates, with a notochord stiffening its body.")
	main.hud.toggle_settings()
	await snap("pause_info")
	quit()
