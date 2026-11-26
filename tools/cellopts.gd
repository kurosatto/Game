# cellopts.gd
# In-room close-ups of the starter cell design options, through the ink
# filter, idle / swimming / striking. Needs a window (xvfb-run on Linux):
#   SHOT_DIR=<folder> godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/cellopts.gd
extends SceneTree
const CELL := 300
const CROP := 150
var out := OS.get_environment("SHOT_DIR")
func _initialize():
	var ids := ["ancestral_collar_cell", "collar_cell"]
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
	var poses := ["idle", "swim", "strike"]
	var grid := Image.create(CELL * poses.size(), CELL * ids.size(), false, Image.FORMAT_RGBA8)
	for n in ids.size():
		for m in poses.size():
			for e in get_nodes_in_group("enemies"):
				e.queue_free()
			player.invincibility_time = 0.0
			player.global_position = spawn
			player.reset_physics_interpolation()
			player.body_art.set_form(ids[n])
			for i in 20: await process_frame
			if poses[m] == "swim":
				Input.action_press("move_right")
				for i in 14: await process_frame
			if poses[m] == "strike":
				player.body_art.on_attack()
				for i in 6: await process_frame
			await RenderingServer.frame_post_draw
			var img = root.get_texture().get_image()
			var sp: Vector2 = player.get_global_transform_with_canvas().origin
			sp *= Vector2(img.get_size()) / root.get_visible_rect().size
			var crop = img.get_region(Rect2i(int(sp.x) - CROP / 2, int(sp.y) - CROP / 2, CROP, CROP))
			crop.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
			grid.blit_rect(crop, Rect2i(0, 0, CELL, CELL), Vector2i(m * CELL, n * CELL))
			Input.action_release("move_right")
		print("FORM ", ids[n])
	grid.save_png(out + "/cell_options.png")
	print("SHOT cell_options")
	quit()
