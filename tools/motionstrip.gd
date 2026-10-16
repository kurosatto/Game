# motionstrip.gd
# Film strips of the player animating in a real room: one row per form, one
# frame every STEP frames through a scripted move (start right, turn down,
# stop, strike). For judging motion, not stills. Needs a window and
# --fixed-fps 60:
#   SHOT_DIR=<folder> godot --fixed-fps 60 --path . --rendering-driver opengl3 -s res://tools/motionstrip.gd
# FORMS=id,id,... picks forms.
extends SceneTree
const CELL := 200
const FRAMES := 96
var out := OS.get_environment("SHOT_DIR")
# STEP=1 also saves every frame as <form>_<n>.png, for animated clips
var STEP := int(OS.get_environment("STEP")) if OS.get_environment("STEP") != "" else 4

# Input held at each frame of the script
func plan(f: int) -> Array:
	if f < 30:
		return ["move_right"]
	if f < 54:
		return ["move_down"]
	return []

func _initialize():
	var lineages = load("res://data/Lineages.gd")
	var by_id := {}
	for path in lineages.TREE:
		by_id[lineages.TREE[path].id] = lineages.TREE[path]
	var ids := ["ancestral_collar_cell", "teleost_line", "scorpion", "sauropsid", "octopus_line", "sea_lamprey"]
	if OS.get_environment("FORMS") != "":
		ids = Array(OS.get_environment("FORMS").split(","))
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
	var spawn: Vector2 = player.global_position - Vector2(220, 120)
	var cols := FRAMES / STEP
	var grid := Image.create(CELL * cols, CELL * ids.size(), false, Image.FORMAT_RGBA8)
	for n in ids.size():
		player.apply_form(by_id[ids[n]])
		player.invincibility_time = 0.0
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		player.global_position = spawn
		player.reset_physics_interpolation()
		for i in 20: await process_frame
		var held := []
		for f in FRAMES:
			var want = plan(f)
			for a in held:
				if not a in want:
					Input.action_release(a)
			for a in want:
				Input.action_press(a)
			held = want
			if f == 62:
				player.shoot_cooldown = 0.0
				player.shoot_tear(Vector2.RIGHT)
			await process_frame
			if f % STEP == 0:
				await RenderingServer.frame_post_draw
				var img = root.get_texture().get_image()
				var sp: Vector2 = player.get_global_transform_with_canvas().origin
				sp *= Vector2(img.get_size()) / root.get_visible_rect().size
				var crop = img.get_region(Rect2i(int(sp.x) - CELL / 2, int(sp.y) - CELL / 2, CELL, CELL))
				grid.blit_rect(crop, Rect2i(0, 0, CELL, CELL), Vector2i((f / STEP) * CELL, n * CELL))
				if STEP == 1:
					crop.save_png("%s/%s_%03d.png" % [out, ids[n], f])
		for a in held:
			Input.action_release(a)
		for t in get_nodes_in_group("player_tears"):
			t.queue_free()
		print("FORM ", ids[n])
	grid.save_png(out + "/motion.png")
	print("SHOT motion")
	quit()
