# growshots.gd
# Screenshots of the element bar and the GROW screen (data/Biominerals.gd).
# Needs a window: SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/growshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(n: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)
func _initialize():
	for i in 5: await process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var p = main.player
	p.elements = {"Ca": 7.0, "P": 3.0, "Fe": 2.0, "Zn": 6.0, "Cu": 1.0, "S": 5.0}
	p.emit_biomass()
	for i in 10: await process_frame
	await snap("element_bar")
	main.hud.show_grow_screen()
	main.hud.grow_selected = "zinc_jaws"
	main.hud._fill_grow_screen()
	for i in 10: await process_frame
	await snap("grow_screen")
	quit()
