# hazardshots.gd
# Screenshots of the era ground hazards (Hazard.gd) in fight rooms of eras
# 2, 4 and 5, and a check that pools slow the player and vents hurt animals.
# Needs a window: SHOT_DIR=<folder> xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/hazardshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	for floor_num in [2, 4, 5]:
		main.floor_number = floor_num
		main.generate_floor()
		var room = null
		for tries in 30:
			for pos in main.dungeon_rooms:
				var r = main.dungeon_rooms[pos]
				if r.type == 1 and not r.hazards_rolled:
					r.hazards_rolled = true
					main.current_room_pos = pos
					# force hazards for the shot
					main.load_room(pos)
					room = main.current_room_node
					break
			if room:
				break
		room.room_data.hazards = room.roll_hazards(floor_num)
		for i in 3: await process_frame
		main.load_room(main.current_room_pos)
		for i in 3: await process_frame
		room = main.current_room_node
		var hz = room.get_children().filter(func(c): return c.get_script() == preload("res://Hazard.gd"))
		print("HAZARDTEST: floor %d hazards %d" % [floor_num, hz.size()])
		main.get_node("VisionFog").set_vision(10, true)
		p.health = 999
		if hz.size() > 0:
			var h = hz[0]
			if h.kind == "fumarole":
				var e = room.active_enemies[0] if room.active_enemies.size() > 0 else null
				if e:
					var hp0 = e.health
					for i in 240:
						e.global_position = h.global_position
						p.global_position = h.global_position + Vector2(300, 0)
						await physics_frame
						if not is_instance_valid(e) or e.dead:
							break
					print("HAZARDTEST: vent hurt animal: ", (not is_instance_valid(e)) or e.health < hp0)
			else:
				for i in 10:
					p.global_position = h.global_position
					await physics_frame
				print("HAZARDTEST: slowed in pool: ", p.slow_timer > 0.0, " mult ", p.slow_mult)
		for i in 90:
			p.global_position = Vector2(500, 300)
			p.health = 999
			await physics_frame
		await snap("hazard_era%d" % floor_num)
	quit()
