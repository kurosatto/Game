# basinshots.gd
# Open basins (Room.is_basin): shots across a basin with the camera following,
# and a walk through an open pass into the next room.
# SHOT_DIR=<folder> [ERAS=2] godot --path . --rendering-driver opengl3 -s res://tools/basinshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
var fails := 0
func snap(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	if out != "":
		root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func check(ok: bool, what: String):
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1
func _initialize():
	var eras = Array(OS.get_environment("ERAS").split(",")) if OS.get_environment("ERAS") != "" else ["2"]
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var Room = load("res://Room.gd")
	for e in eras:
		var floor_num = int(e)
		main.floor_number = floor_num
		main.generate_floor()
		# a basin with a basin neighbour
		var pick = null
		var nb = null
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if not Room.is_basin(r):
				continue
			for d in r.connections:
				if main.is_basin_room(r.connections[d]) and d.x != 0:
					pick = pos
					nb = d
					break
			if pick != null:
				break
		if pick == null:
			print("no basin pair on floor ", floor_num)
			continue
		main.current_room_pos = pick
		main.load_room(pick)
		main.player.health = 999
		main.get_node("VisionFog").set_vision(12, true)
		var room = main.current_room_node
		check(room.side_margin >= Room.BASIN_EXTRA, "basin is wider than the screen (margin %d)" % room.side_margin)
		for spot in [-room.side_margin + 260.0, 960.0, 1920.0 + room.side_margin - 260.0]:
			main.player.global_position = Vector2(spot, 700)
			main.player.reset_physics_interpolation()
			for i in 60: await process_frame
			main.hud.item_banner.visible = false
			await snap("era%d_x%d" % [floor_num, int(spot)])
			check(absf(main.camera.position.x - main.camera_x_for(room, spot)) < 4.0, "camera follows to x %d (at %d)" % [spot, main.camera.position.x])
		var door = room.door_nodes[nb]
		check(door.open_pass and door.is_open, "pass to the next basin is open")
		room.begin_fight()
		check(door.is_open, "pass stays open in a fight")
		# walk through it
		main.player.door_cooldown = 0.0
		var before = main.current_room_pos
		main._on_room_transition_requested(nb)
		for i in 60: await process_frame
		check(main.current_room_pos == before + nb, "went through the pass")
		var p = main.player.global_position.x
		var nr = main.current_room_node
		check(p > -nr.side_margin and p < 1920 + nr.side_margin, "player is inside the next basin (x %d)" % p)
		check(absf(main.camera.position.x - main.camera_x_for(nr, p)) < 40.0, "camera framed on arrival")
		main.hud.item_banner.visible = false
		await snap("era%d_after_pass" % floor_num)
	print("FAILS ", fails)
	quit()
