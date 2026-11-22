extends SceneTree
# Wall regression test (kuro, 2026-11-22: "if you go back quickly you go
# through the walls"). For every door of floor 1: walk through, then at once
# walk straight back, and check the player never ends up outside a room. Then
# a flying form pushes into every wall and must stay inside.
# Run: godot --headless --path . -s res://tools/walltest.gd
const ACT = {Vector2i.UP: "move_up", Vector2i.DOWN: "move_down", Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right"}
const INSET = {Vector2i.UP: Vector2(0, 170), Vector2i.DOWN: Vector2(0, -170), Vector2i.LEFT: Vector2(170, 0), Vector2i.RIGHT: Vector2(-170, 0)}
var main
var fails := 0

func inside(p: Vector2) -> bool:
	return p.x > 0 and p.x < 1920 and p.y > 0 and p.y < 1080

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.player.adapt_pending = true
	var p = main.player
	p.invincibility_time = 9999.0
	var tested := 0
	for pos in main.dungeon_rooms.keys():
		for dir in main.dungeon_rooms[pos].connections.keys():
			if tested >= 8:
				break
			tested += 1
			await go_and_back(pos, dir)
	# Flying forms skip obstacles, but never walls
	p.set_collision_mask_value(3, false)
	await reset_room(main.current_room_pos)
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized()]:
		p.global_position = Vector2(960, 540)
		p.velocity = Vector2.ZERO
		var acts = []
		if dir.x > 0: acts.append("move_right")
		if dir.x < 0: acts.append("move_left")
		if dir.y > 0: acts.append("move_down")
		if dir.y < 0: acts.append("move_up")
		for a in acts: Input.action_press(a)
		# Doors would carry it away; only test where there is a wall
		var room_before = main.current_room_pos
		for i in 150:
			await physics_frame
		for a in acts: Input.action_release(a)
		for i in 40: await physics_frame
		if main.current_room_pos == room_before and not main.is_transitioning:
			var ok = inside(p.global_position)
			print(("PASS " if ok else "FAIL ") + "flying into wall %s stays in room (%s)" % [dir, p.global_position])
			if not ok: fails += 1
		await reset_room(main.current_room_pos)
	p.set_collision_mask_value(3, true)
	print("WALLTEST %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)

func reset_room(pos: Vector2i):
	while main.is_transitioning:
		await physics_frame
	main.current_room_pos = pos
	main.load_room(pos)
	main.current_room_node.position = Vector2.ZERO
	main.camera.position = Vector2(960, 540)
	for i in 5: await physics_frame
	for e in get_nodes_in_group("enemies"):
		e.take_damage(99999.0)
	for i in 30: await physics_frame
	Engine.time_scale = 1.0
	if main.hud.evolution_modal and main.hud.evolution_modal.visible:
		main.hud.evolution_modal.visible = false
		paused = false
	main.player.set_physics_process(true)

func go_and_back(pos: Vector2i, dir: Vector2i):
	await reset_room(pos)
	var p = main.player
	var door = null
	for d in get_nodes_in_group("doors"):
		if d.get_parent() == main.current_room_node and d.direction == dir:
			door = d
	if door == null or not door.is_open:
		return
	p.door_cooldown = 0.0
	p.global_position = door.global_position + INSET[dir]
	p.velocity = Vector2.ZERO
	for i in 3: await physics_frame
	Input.action_press(ACT[dir])
	for i in 120:
		await physics_frame
		if main.is_transitioning:
			break
	Input.action_release(ACT[dir])
	while main.is_transitioning:
		await physics_frame
	# Straight back the moment the slide ends
	var back = -dir
	Input.action_press(ACT[back])
	var worst = 0.0
	var out := false
	for i in 150:
		await physics_frame
		if not main.is_transitioning and not inside(p.global_position):
			out = true
			worst = max(worst, p.global_position.distance_to(Vector2(960, 540)))
	Input.action_release(ACT[back])
	while main.is_transitioning:
		await physics_frame
	for i in 20: await physics_frame
	var ok = not out and inside(p.global_position)
	print(("PASS " if ok else "FAIL ") + "room %s door %s: go and come straight back (player at %s)" % [pos, dir, p.global_position])
	if not ok:
		fails += 1
