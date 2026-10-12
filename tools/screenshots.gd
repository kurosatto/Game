# screenshots.gd
# Renders the room, evolution cards, pause menu and game over with touch
# controls on, for checking phone layouts on a PC (needs a window, not
# --headless). Run: SHOT_DIR=<folder> godot --path . -s res://tools/screenshots.gd
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
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var tc = main.get_node("TouchControls"); tc.visible = true
	main.hud.use_touch_texts()
	await snap("1_room")
	main.hud.show_evolution_modal(1, main.player.evolution_choices)
	await snap("2_evolution")
	main.hud._on_evolution_choice_clicked(1, 0)
	main.hud.toggle_settings()
	await snap("3_settings")
	main.hud.toggle_settings()
	main.hud.show_game_over()
	await snap("4_gameover")
	quit()
