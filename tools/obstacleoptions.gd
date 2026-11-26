# obstacleoptions.gd
# Mock-ups of other ways to draw room borders and obstacles (kuro, 2026-11-26).
# Pass 1 (no overlays yet) writes <SHOT_DIR>/room_era<N>.json with the
# obstacles' footprints, pebble banks and doors. Pass 2 lays
# <SHOT_DIR>/overlays/<opt>_era<N>.png (full room, drawn by
# tools/obstacle_options.py) over the room in place of the rim, obstacles
# and pebbles, under the real ink filter, animals, player and HUD.
# SHOT_DIR=<folder> [ERAS=2,4] [LAYOUT=3] [OPTS=reef,contour] godot --path . --rendering-driver opengl3 -s res://tools/obstacleoptions.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func env_list(key: String, fallback: Array) -> Array:
	if OS.get_environment(key) == "":
		return fallback
	return Array(OS.get_environment(key).split(","))
func snap(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var eras = env_list("ERAS", ["2", "4"]).map(func(e): return int(e))
	var opts = env_list("OPTS", ["now"])
	var li := int(OS.get_environment("LAYOUT")) if OS.get_environment("LAYOUT") != "" else 3
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	for floor_num in eras:
		main.floor_number = floor_num
		main.generate_floor()
		var room_pos = main.current_room_pos
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and r.special == "" and (pos - main.current_room_pos).length() == 1:
				room_pos = pos
				break
		var rd = main.dungeon_rooms[room_pos]
		for opt in opts:
			seed(floor_num * 1000 + li)
			rd.layout_idx = li
			rd.has_initialized_contents = false
			main.current_room_pos = room_pos
			main.load_room(room_pos)
			main.player.global_position = Vector2(960, 560)
			main.player.reset_physics_interpolation()
			main.player.health = 999
			main.get_node("VisionFog").set_vision(12, true)
			for i in 30: await process_frame
			var room = main.current_room_node
			if opt == "dump":
				var data := {"obstacles": [], "rubble": [], "doors": [], "era": room.era_dir()}
				for c in room.get_children():
					if c.is_in_group("obstacles") and c.has_method("footprint_rect"):
						data.obstacles.append({"x": c.position.x + c.foot_c.x, "y": c.position.y + c.foot_c.y,
							"a": c.foot_a, "b": c.foot_b, "type": c.obstacle_type})
					elif c.get_script() and str(c.get_script().resource_path).ends_with("Rubble.gd"):
						data.rubble.append([c.a.x, c.a.y, c.b.x, c.b.y])
					elif c.get_script() and str(c.get_script().resource_path).ends_with("Door.gd"):
						data.doors.append([c.position.x, c.position.y])
				var f = FileAccess.open(out + "/room_era%d.json" % floor_num, FileAccess.WRITE)
				f.store_string(JSON.stringify(data))
				f.close()
				print("DUMP era ", floor_num)
				continue
			if opt != "now":
				var path = out + "/overlays/%s_era%d.png" % [opt, floor_num]
				var img = Image.load_from_file(path)
				var over = Sprite2D.new()
				over.texture = ImageTexture.create_from_image(img)
				over.centered = false
				over.z_index = -19
				room.add_child(over)
				var fbg = room.get_node_or_null("FullscreenBackground")
				if fbg: fbg.visible = false
				for c in room.get_children():
					var rubble = c.get_script() != null and str(c.get_script().resource_path).ends_with("Rubble.gd")
					if c.is_in_group("obstacles") or rubble:
						c.visible = false
					# Covers stay: they are their own feature
			main.hud.item_banner.visible = false
			for i in 10: await process_frame
			main.hud.item_banner.visible = false
			await snap("%s_era%d" % [opt, floor_num])
	quit()
