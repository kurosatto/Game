# clutchshots.gd
# Screenshots of laying a clutch: the GROW screen's LAY EGGS info, the eggs
# in the room, and the young one hatching after a death. Needs a window:
#   SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/clutchshots.gd
# FORM=<lineage id> picks the form (default: the early arthropod).
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(n: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)
func _initialize():
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var p = main.player
	var form = OS.get_environment("FORM") if OS.get_environment("FORM") != "" else "early_arthropod"
	for path in preload("res://data/Lineages.gd").TREE:
		var fd: Dictionary = preload("res://data/Lineages.gd").TREE[path]
		if fd.get("id", "") == form:
			p.apply_form(fd)
	p.elements = {"Ca": 3.0, "P": 6.0, "Fe": 2.0, "Zn": 2.0, "Cu": 1.0, "S": 5.0}
	p.emit_biomass()
	main.current_room_node.room_data.cleared = true
	main.get_node("VisionFog").set_vision(10, true)
	p.global_position = Vector2(760, 560)
	main.hud.show_grow_screen()
	for i in 3: await process_frame
	main.hud._on_eggs_pressed()
	for i in 10: await process_frame
	await snap("1_lay_eggs_info")
	main.hud._on_eggs_pressed()
	for i in 30: await process_frame
	await snap("2_laid")
	main.hud.hide_grow_screen()
	p.global_position = Vector2(1100, 560)
	for i in 30: await physics_frame
	await snap("3_eggs_in_room")
	p.invincibility_time = 0.0
	p.take_damage(999, "test")
	for i in 60 * 2 + 20: await physics_frame
	await snap("4_hatching")
	for i in 60 * 3: await physics_frame
	await snap("5_hatched")
	quit()
