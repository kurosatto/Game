extends SceneTree
# Gap / trap test (kuro, 2026-11-23: "obstacles should not trap you; it looks
# like you can go between them but you can't"). Loads every room layout with
# every set of doors, in every era, on a PC-shaped (16:9) and a phone-shaped (wide) screen,
# then sweeps the player's own circle over the floor:
#  - every door can be reached from every other door,
#  - every spot the player fits is reachable (no sealed pockets to be pushed
#    or spawned into),
#  - no gap between scenery, or scenery and the wall, is narrower than the
#    player yet left open (each is either walkable or closed with pebbles).
# Run: godot --headless --path . -s res://tools/gaptest.gd
const Gen = preload("res://LevelGenerator.gd")
const DIRS = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var main
var fails := 0
var rooms_checked := 0

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	main.player.invincibility_time = 9999.0
	main.player.process_mode = Node.PROCESS_MODE_DISABLED
	var n_normal = load("res://RoomLayouts.gd").get_normal_layouts().size()
	var kinds: Array = []
	for i in n_normal:
		kinds.append([1, i])
	for t in [0, 2, 3, 4]:
		kinds.append([t, -1])
	# Every era has its own scenery drawings, so check each floor
	for floor_num in range(1, 6):
		main.floor_number = floor_num
		for margin in [0.0, 210.0]:
			main.current_room_node.margin_override = margin
			for k in kinds:
				for mask in range(1, 16):
					await check_room(k[0], k[1], mask, margin)
	main.current_room_node.margin_override = -1.0
	print("rooms checked: ", rooms_checked, "  problems: ", fails)
	print("PASS" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)

func check_room(type: int, layout_idx: int, mask: int, margin: float):
	await load_test_room(type, layout_idx, mask)
	rooms_checked += 1
	var label = "floor %d type %d layout %d doors %d margin %d" % [main.floor_number, type, layout_idx, mask, margin]
	# A coarse sweep first; anything it can't reach is checked again on a
	# fine grid, since a gap just wider than the player can fall between
	# coarse sample rows
	var res = sweep(mask, 32.0)
	if not res.ok:
		res = sweep(mask, 10.0)
	for msg in res.msgs:
		fails += 1
		print("FAIL ", msg, ": ", label)

func load_test_room(type: int, layout_idx: int, mask: int):
	var pos := Vector2i(40, 40)
	var rd = Gen.RoomData.new()
	rd.grid_pos = pos
	rd.type = type
	rd.layout_idx = layout_idx
	rd.cleared = true
	rd.has_initialized_contents = true
	rd.treasure_item_id = ""
	for i in 4:
		if mask & (1 << i):
			var d: Vector2i = DIRS[i]
			rd.connections[d] = pos + d
			if not main.dungeon_rooms.has(pos + d):
				var nb = Gen.RoomData.new()
				nb.grid_pos = pos + d
				nb.type = 1
				main.dungeon_rooms[pos + d] = nb
	main.dungeon_rooms[pos] = rd
	main.current_room_pos = pos
	main.load_room(pos)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	for i in 3: await physics_frame

func sweep(mask: int, STEP: float) -> Dictionary:
	var room = main.current_room_node
	var space = room.get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = 28.0
	var q = PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.collision_mask = 4 + 16 # scenery, pebbles and walls; not animals
	var inner: Rect2 = room.interior_rect(30.0)
	var free := {}
	var cols := int(inner.size.x / STEP) + 1
	var rows := int(inner.size.y / STEP) + 1
	for gx in cols:
		for gy in rows:
			var p = inner.position + Vector2(gx, gy) * STEP
			q.transform = Transform2D(0, p)
			q.motion = Vector2.ZERO
			if space.intersect_shape(q, 1).is_empty():
				free[Vector2i(gx, gy)] = p
	# Flood from the first door's doorway
	var starts: Array = []
	for i in 4:
		if mask & (1 << i):
			starts.append(nearest_free(free, room.door_nodes.get(DIRS[i]).position if room.door_nodes.has(DIRS[i]) else door_point(DIRS[i], room)))
	var seen := {starts[0]: true}
	var stack: Array = [starts[0]]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var nb = c + Vector2i(dx, dy)
				if (dx == 0 and dy == 0) or seen.has(nb) or not free.has(nb):
					continue
				q.transform = Transform2D(0, free[c])
				q.motion = free[nb] - free[c]
				var frac = space.cast_motion(q)
				if frac.size() > 0 and frac[0] >= 1.0:
					seen[nb] = true
					stack.append(nb)
	var msgs: Array = []
	for st in starts:
		if not seen.has(st):
			msgs.append("door unreachable at %s" % free.get(st))
	var pockets: Array = []
	for c in free:
		if not seen.has(c):
			pockets.append(free[c])
	if pockets.size() > 0:
		msgs.append("sealed pocket %s" % str(pockets.slice(0, 6)))
	return {"ok": msgs.is_empty(), "msgs": msgs}

func door_point(d: Vector2i, room) -> Vector2:
	var r: Rect2 = room.interior_rect()
	return r.get_center() + Vector2(d) * Vector2(r.size.x * 0.5, r.size.y * 0.5)

func nearest_free(free: Dictionary, p: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var bd := INF
	for c in free:
		var d = free[c].distance_squared_to(p)
		if d < bd:
			bd = d
			best = c
	return best
