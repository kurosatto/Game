# growshots.gd
# Screenshots of the element bar and the GROW screen (data/Biominerals.gd):
# a part picked (the portrait shows it on the body), mid-grow (elements
# flying in) and after. Needs a window:
#   SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/growshots.gd
# FORM=<lineage id> picks the form shown (default: the starting cell).
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
	var form = OS.get_environment("FORM")
	if form != "":
		for path in preload("res://data/Lineages.gd").TREE:
			var fd: Dictionary = preload("res://data/Lineages.gd").TREE[path]
			if fd.get("id", "") == form:
				p.apply_form(fd)
	p.elements = {"Ca": 3.0, "P": 14.0, "Fe": 2.0, "Zn": 6.0, "Cu": 1.0, "S": 5.0}
	p.health = p.max_health - 2
	p.emit_biomass()
	for i in 10: await process_frame
	await snap("element_bar")
	main.hud.show_grow_screen()
	for i in 10: await process_frame
	await snap("grow_screen_open")
	main.hud._on_grow_tile("photoreceptors")
	for i in 20: await process_frame
	await snap("grow_screen_picked")
	main.hud._on_grow_tile("photoreceptors")
	for i in 14: await process_frame
	await snap("grow_screen_growing")
	for i in 50: await process_frame
	await snap("grow_screen_grown")
	main.hud._on_grow_tile("calcite_lenses")
	for i in 20: await process_frame
	await snap("grow_screen_lenses")
	if OS.get_environment("PARTS") == "1":
		for id in ["calcite_spines", "keratin_horn", "keratin_claws", "magnetite_teeth", "photoreceptors", "calcite_lenses", "shell_plates", "zinc_jaws"]:
			p.adaptations_taken[id] = 2
		main.hud.grow_selected = ""
		main.hud._fill_grow_screen()
		for i in 20: await process_frame
		await snap("grow_screen_all_parts")
	print("taken ", p.adaptations_taken, " vision ", p.vision, " left ", p.elements)
	quit()
