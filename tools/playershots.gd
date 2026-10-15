# playershots.gd
# Close-ups of the player in a real room for a spread of forms, pasted into
# one grid image (playable_forms.png). Needs a window (xvfb-run on Linux):
#   SHOT_DIR=<folder> godot --path . --rendering-driver opengl3 -s res://tools/playershots.gd
# FORMS=id,id,... picks other forms; MOVING=1 walks the player to the right
# so legs and fins are caught mid-stroke (use --fixed-fps 60).
extends SceneTree
const CELL := 300
var out := OS.get_environment("SHOT_DIR")
func _initialize():
	var lineages = load("res://data/Lineages.gd")
	var by_id := {}
	for path in lineages.TREE:
		by_id[lineages.TREE[path].id] = lineages.TREE[path]
	var ids := ["ancestral_collar_cell", "early_arthropod", "scorpion", "decapod", "dragonfly_line",
		"shark_line", "teleost_line", "sea_lamprey", "sauropsid", "lissamphibian",
		"octopus_line", "squid_line", "palau_nautilus", "land_snail", "giant_clam",
		"sea_star", "brittle_star", "sea_urchin", "reef_feather_star", "spider"]
	if OS.get_environment("FORMS") != "":
		ids = Array(OS.get_environment("FORMS").split(","))
	var moving := OS.get_environment("MOVING") == "1"
	for i in 5: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.get_node("VisionFog").set_vision(10, true)
	var player = main.player
	var spawn: Vector2 = player.global_position
	var cols := 5
	var grid := Image.create(CELL * cols, CELL * int(ceil(ids.size() / float(cols))), false, Image.FORMAT_RGBA8)
	for n in ids.size():
		player.apply_form(by_id[ids[n]])
		player.invincibility_time = 0.0
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		player.global_position = spawn
		player.reset_physics_interpolation()
		for i in 12: await process_frame
		if moving:
			Input.action_press("move_right")
		for i in 7: await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		var sp: Vector2 = player.get_global_transform_with_canvas().origin
		sp *= Vector2(img.get_size()) / root.get_visible_rect().size
		var crop = img.get_region(Rect2i(int(sp.x) - CELL / 2, int(sp.y) - CELL / 2, CELL, CELL))
		grid.blit_rect(crop, Rect2i(0, 0, CELL, CELL), Vector2i((n % cols) * CELL, (n / cols) * CELL))
		if moving:
			Input.action_release("move_right")
		print("FORM ", ids[n])
	grid.save_png(out + "/playable_forms.png")
	print("SHOT playable_forms")
	quit()
