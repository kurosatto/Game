extends SceneTree
# Room-clear regression test: in every fight and boss room of floors 1-5, lets
# the animals act for a few seconds around the player, reports any that
# ended up outside the floor or inside a rock, then kills everything and
# checks the doors open. Run: godot --headless --path . -s res://tools/cleartest.gd
const INTERIOR = Rect2(128, 128, 1664, 824)
var main
func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.player.adapt_pending = true
	var fails := 0
	var total := 0
	for floor_num in range(1, 6):
		main.floor_number = floor_num
		main.generate_floor()
		for i in 10: await physics_frame
		for pos in main.dungeon_rooms.keys():
			if not main.dungeon_rooms[pos].type in [1, 3]:
				continue
			total += 1
			var res = await try_room(pos)
			if res != "ok":
				fails += 1
				print("CLEAR floor %d room %s: %s" % [floor_num, pos, res])
	print("CLEAR done: %d rooms, %d problems" % [total, fails])
	quit()

func try_room(pos: Vector2i) -> String:
	main.is_transitioning = false
	main.current_room_pos = pos
	main.load_room(pos)
	var room = main.current_room_node
	room.position = Vector2.ZERO
	if room.room_data.type == 3 and room.active_enemies.is_empty():
		return "boss room with no boss"
	var p = main.player
	p.health = p.max_health
	p.invincibility_time = 999.0
	p.global_position = Vector2(960, 540)
	Engine.time_scale = 3.0
	for i in 360: await physics_frame
	Engine.time_scale = 1.0
	var notes: Array = []
	for e in room.active_enemies:
		if not is_instance_valid(e):
			notes.append("freed enemy still counted")
			continue
		var lp = room.to_local(e.global_position)
		if not INTERIOR.has_point(lp):
			notes.append("%s outside floor at %s" % [e.enemy_type, lp])
		for c in room.get_children():
			if c is StaticBody2D and c.position.distance_to(lp) < 40.0:
				notes.append("%s inside obstacle at %s" % [e.enemy_type, lp])
	# Kill everything, retrying while burrowed / rolled up
	for i in 400:
		for e in room.active_enemies.duplicate():
			if is_instance_valid(e):
				e.take_damage_if_alive(99999.0)
		if room.active_enemies.is_empty():
			break
		await physics_frame
	for i in 10: await physics_frame
	if not is_instance_valid(room):
		return "room was replaced mid-test"
	if main.hud.evolution_modal and main.hud.evolution_modal.visible:
		main.hud.evolution_modal.visible = false
		paused = false
	if not room.room_data.cleared:
		notes.append("not cleared, %d left" % room.active_enemies.size())
	for d in get_nodes_in_group("doors"):
		if d.get_parent() == room and not d.is_open and not d.is_locked:
			notes.append("door %s still shut" % d.direction)
	return "ok" if notes.is_empty() else ", ".join(notes)
