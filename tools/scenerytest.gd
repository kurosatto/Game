extends SceneTree
# Scenery regression test (kuro, 2026-11-22: "make objects not destroyable").
# Shoots and hammers every obstacle in the first room far past the old 12 hp,
# then checks every one is still standing, shots still stop on them, and
# a hit shows no flash or wobble.
# Run: godot --headless --path . -s res://tools/scenerytest.gd
var main
var fails := 0

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.invincibility_time = 9999.0
	var obs: Array = []
	for o in get_nodes_in_group("obstacles"):
		obs.append(o)
	if obs.is_empty():
		# The start room may be bare; hop into a fight room for its scenery
		for pos in main.dungeon_rooms.keys():
			if pos != main.current_room_pos and main.get_room_type(pos) == 1:
				main.load_room(pos)
				break
		for i in 30: await process_frame
		for o in get_nodes_in_group("obstacles"):
			obs.append(o)
	print("obstacles in room: ", obs.size())
	if obs.is_empty():
		print("FAIL no obstacles to test")
		quit(1)
		return
	for o in obs:
		for i in 60:
			o.take_damage(50.0)
	for i in 10: await process_frame
	# Real shots: stand the player next to an obstacle and fire at it
	var target = obs[0]
	p.global_position = target.global_position + Vector2(-220, 0)
	for i in 40:
		p.spawn_tear(Vector2.RIGHT)
		for f in 4: await physics_frame
	for i in 40: await physics_frame
	var alive := 0
	for o in obs:
		if is_instance_valid(o) and not o.is_queued_for_deletion():
			alive += 1
	print("still standing: ", alive, "/", obs.size())
	if alive != obs.size():
		fails += 1
	var stray := 0
	for t in get_nodes_in_group("tears"):
		if is_instance_valid(t) and t.global_position.x > target.global_position.x + 60.0:
			stray += 1
	print("shots past the obstacle: ", stray)
	if stray > 0:
		fails += 1
	# No damage look: the sprite keeps its normal colour and angle
	var looks_hurt := 0
	for o in obs:
		var spr = o.get_node_or_null("Sprite2D")
		o.take_damage(5.0)
		if spr and (spr.modulate != Color.WHITE or spr.rotation != 0.0):
			looks_hurt += 1
	print("obstacles showing a hit: ", looks_hurt)
	if looks_hurt > 0:
		fails += 1
	print("PASS" if fails == 0 else "FAIL")
	quit(fails)
