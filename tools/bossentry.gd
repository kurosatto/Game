extends SceneTree
# Walks into the boss room from each side it can be entered and checks the
# boss starts well away from the player (kuro: "boss spawned on top of me").
# Run: godot --headless --path . -s res://tools/bossentry.gd
var main
func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var fails = 0
	for floor_num in range(1, 6):
		main.floor_number = floor_num
		main.generate_floor()
		for i in 5: await physics_frame
		var boss_pos = null
		for pos in main.dungeon_rooms:
			if main.dungeon_rooms[pos].type == 3:
				boss_pos = pos
		for dir in main.dungeon_rooms[boss_pos].connections:
			var from = boss_pos + dir
			main.dungeon_rooms[boss_pos].cleared = false
			main.dungeon_rooms[boss_pos].has_initialized_contents = false
			main.current_room_pos = from
			main.load_room(from)
			main.current_room_node.position = Vector2.ZERO
			for i in 5: await physics_frame
			main.player.door_cooldown = 0.0
			main._on_room_transition_requested(-dir)
			while main.is_transitioning:
				await physics_frame
			var boss = null
			for e in get_nodes_in_group("enemies"):
				if e.has_method("emit_boss_health") and is_instance_valid(e):
					boss = e
			if boss == null:
				print("FAIL floor %d: no boss" % floor_num); fails += 1; continue
			var d = boss.global_position.distance_to(main.player.global_position)
			var ok = d > 450.0
			print(("PASS " if ok else "FAIL ") + "floor %d entering %s: boss %.0f px away (boss %s player %s)" % [floor_num, -dir, d, boss.global_position, main.player.global_position])
			if not ok: fails += 1
			for e in get_nodes_in_group("enemies"):
				e.queue_free()
			for i in 3: await physics_frame
	print("BOSSENTRY %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	quit()
