# motionshots.gd
# A strip of consecutive frames of a player form swimming/walking and biting,
# to check jaws and legs stay attached through the motion. Needs xvfb-run:
#   SHOT_DIR=<folder> FORMS=a,b godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/motionshots.gd
extends SceneTree
const CELL := 240
const SRC := 520
const N := 10
var out := OS.get_environment("SHOT_DIR")
func _initialize():
	var lineages = load("res://data/Lineages.gd")
	var by_id := {}
	for path in lineages.TREE:
		by_id[lineages.TREE[path].id] = lineages.TREE[path]
	var ids := Array(OS.get_environment("FORMS").split(","))
	var parts: Array = []
	if OS.get_environment("PARTS") != "":
		parts = Array(OS.get_environment("PARTS").split(","))
	var step := int(OS.get_environment("STEP")) if OS.get_environment("STEP") != "" else 3
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
	var grid := Image.create(CELL * N, CELL * ids.size() * 2, false, Image.FORMAT_RGBA8)
	for n in ids.size():
		player.apply_form(by_id[ids[n]])
		player.adaptations_taken = {}
		for p in parts:
			player.adaptations_taken[p] = 2
		for row in 2:
			for e in get_nodes_in_group("enemies"):
				e.queue_free()
			player.global_position = spawn + Vector2(-150, 0)
			player.reset_physics_interpolation()
			player.face_dir = Vector2.RIGHT
			Input.action_press("move_right")
			for i in 20: await process_frame
			if row == 1:
				Input.action_release("move_right")
				Input.action_press("move_down")
			for k in N:
				if row == 0 and k % 4 == 0:
					player.shoot_cooldown = 0.0
					player.shoot_tear(Vector2.RIGHT)
				for i in step:
					main.camera.zoom = Vector2(3, 3)
					main.camera.global_position = player.global_position
					main.camera.reset_smoothing()
					await process_frame
				await RenderingServer.frame_post_draw
				var img = root.get_texture().get_image()
				var sp: Vector2 = player.get_global_transform_with_canvas().origin
				sp *= Vector2(img.get_size()) / root.get_visible_rect().size
				var crop = img.get_region(Rect2i(int(sp.x) - SRC / 2, int(sp.y) - SRC / 2, SRC, SRC))
				crop.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
				grid.blit_rect(crop, Rect2i(0, 0, CELL, CELL), Vector2i(k * CELL, (n * 2 + row) * CELL))
			Input.action_release("move_right")
			Input.action_release("move_down")
			for i in 20: await process_frame
		print("FORM ", ids[n])
	grid.save_png(out + "/" + (OS.get_environment("NAME") if OS.get_environment("NAME") != "" else "motion.png"))
	print("SHOT motion")
	quit()
