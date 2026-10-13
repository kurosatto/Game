extends SceneTree
# Door regression test: in every room of floors 1-5, starts just inside each
# door and walks into it with the real move actions; reports doors that
# do not lead anywhere. Run: godot --headless --path . -s res://tools/doortest.gd
const ACT = {Vector2i.UP: "move_up", Vector2i.DOWN: "move_down", Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right"}
const INSET = {Vector2i.UP: Vector2(0, 170), Vector2i.DOWN: Vector2(0, -170), Vector2i.LEFT: Vector2(170, 0), Vector2i.RIGHT: Vector2(-170, 0)}
var main
func _initialize():
	# DOORTEST_WIDTH=2340 runs the test with a phone-wide room (side margins)
	var w = OS.get_environment("DOORTEST_WIDTH")
	if w != "":
		load("res://Room.gd").margin_override = (int(w) - 1920) / 2.0
		print("WALK side margin ", (int(w) - 1920) / 2.0)
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	# Kills fill the biomass bar; keep the adaptation pick from pausing the walk
	main.player.adapt_pending = true
	var fails := 0
	var total := 0
	for floor_num in range(1, 6):
		main.floor_number = floor_num
		main.generate_floor()
		for i in 10: await physics_frame
		for pos in main.dungeon_rooms.keys():
			for dir in main.dungeon_rooms[pos].connections.keys():
				total += 1
				var res = await try_door(pos, dir)
				if res != "ok":
					fails += 1
					print("WALK floor %d room %s dir %s: %s" % [floor_num, pos, dir, res])
	print("WALK done: %d doors, %d problems" % [total, fails])
	quit()

func try_door(pos: Vector2i, dir: Vector2i) -> String:
	main.is_transitioning = false
	main.current_room_pos = pos
	main.load_room(pos)
	var room = main.current_room_node
	room.position = Vector2.ZERO
	main.camera.position = Vector2(960, 540)
	for i in 5: await physics_frame
	var spawned = room.active_enemies.size()
	var rtype = main.dungeon_rooms[pos].type
	var was_init = main.dungeon_rooms[pos].cleared
	for e in get_nodes_in_group("enemies"):
		e.take_damage(99999.0)
	for i in 30: await physics_frame
	Engine.time_scale = 1.0
	if main.hud.evolution_modal and main.hud.evolution_modal.visible:
		main.hud.evolution_modal.visible = false
		paused = false
	var door = null
	for d in get_nodes_in_group("doors"):
		if d.get_parent() == room and d.direction == dir:
			door = d
	if door == null:
		return "no door node"
	var p = main.player
	p.set_physics_process(true)
	main.camera.position = Vector2(960, 540)
	p.keys = 1
	p.health = p.max_health
	p.invincibility_time = 99.0
	p.door_cooldown = 0.0
	p.global_position = door.global_position + INSET[dir]
	p.velocity = Vector2.ZERO
	for i in 3: await physics_frame
	var state = "open=%s locked=%s" % [door.is_open, door.is_locked]
	Input.action_press(ACT[dir])
	var moved := false
	for i in 150:
		await physics_frame
		if main.current_room_pos != pos:
			moved = true
			break
	Input.action_release(ACT[dir])
	# Let the slide finish so the next test starts from a settled state
	for i in 200:
		await physics_frame
		if not main.is_transitioning:
			break
	for i in 10: await physics_frame
	if moved:
		return "ok"
	return "STUCK (%s, player at %s, door at %s) spawned=%d type=%d cleared_before=%s cleared=%s active=%d group=%d paused=%s phys=%s ts=%s trans=%s modal=%s" % [state, p.global_position.round(), door.global_position.round(), spawned, rtype, was_init, main.dungeon_rooms[pos].cleared, room.active_enemies.size(), get_nodes_in_group("enemies").size(), paused, p.is_physics_processing(), Engine.time_scale, main.is_transitioning, main.hud.evolution_modal != null and main.hud.evolution_modal.visible]
