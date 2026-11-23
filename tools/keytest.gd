extends SceneTree
# One-key rule: a floor with a locked treasure room hides exactly one key,
# in a random fight room (never start/boss/seep/treasure); floors without a
# treasure room have none; no enemy drop or shop sells one; spare keys don't
# carry to the next floor. Run: godot --headless --path . -s res://tools/keytest.gd
func _initialize():
	var gen = load("res://LevelGenerator.gd")
	var fails := 0
	var spots := {}
	for floor_num in range(1, 6):
		for t in 200:
			var rooms = gen.generate_level(floor_num)
			var keys := 0
			var has_treasure := false
			for pos in rooms:
				var r = rooms[pos]
				if r.type == gen.RoomType.TREASURE:
					has_treasure = true
				for p in r.saved_pickups:
					if p["type"] == "key":
						keys += 1
						spots[pos] = true
						if r.type != gen.RoomType.NORMAL:
							fails += 1
							print("KEY bad room type ", r.type)
			if keys != (1 if has_treasure else 0):
				fails += 1
				print("KEY floor %d: %d keys, treasure=%s" % [floor_num, keys, has_treasure])
	print("KEY distinct key rooms seen: ", spots.size())
	# Enemy drops never give keys
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var room = main.current_room_node
	for i in 2000:
		room.spawn_random_pickup(Vector2(960, 540))
	await process_frame
	for c in room.get_children():
		if c.is_in_group("pickups") and c.pickup_type == "key":
			fails += 1
			print("KEY dropped by an enemy")
			break
	# The key lands on clear floor when its room is first entered
	for floor_num in range(1, 6):
		main.floor_number = floor_num
		main.player.keys = 3
		main.generate_floor()
		if main.player.keys != 0:
			fails += 1
			print("KEY spare keys carried to floor ", floor_num)
		for i in 5: await physics_frame
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			var want = r.saved_pickups.any(func(p): return p["type"] == "key")
			if not want:
				continue
			main.current_room_pos = pos
			main.load_room(pos)
			for i in 5: await physics_frame
			var rn = main.current_room_node
			var found = false
			for c in rn.get_children():
				if c.is_in_group("pickups") and c.pickup_type == "key" and not c.is_queued_for_deletion():
					found = true
					if not rn.spot_is_free(c.position, 30.0):
						fails += 1
						print("KEY inside a rock at ", c.position)
			if not found:
				fails += 1
				print("KEY missing in its room on floor ", floor_num)
	print("KEY done: %d problems" % fails)
	quit()
