extends SceneTree
# Charnia fronds (kuro, 2026-11-23: "I thought these leaves are enemies...
# make them a simple enemy"). Checks that Ediacaran fight rooms turn their
# frond spots into Charnia enemies (no frond scenery left anywhere), that a
# frond stays rooted when shot, lashes a player who comes close, leaves one
# who keeps away alone, and dies to shots.
# Run: godot --headless --path . -s res://tools/frondtest.gd
# With SHOT_DIR=<folder> (and a window, xvfb on Linux) it also saves
# screenshots: SHOT_DIR=... godot --path . --rendering-driver opengl3 -s res://tools/frondtest.gd
var main
var fails := 0
var out := OS.get_environment("SHOT_DIR")

func check(ok: bool, what: String):
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func snap(name: String):
	if out == "":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func fronds() -> Array:
	return get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and not e.dead and e.enemy_type == "frond")

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	# Every room of floor 1: no tall scenery left, fronds only in fight rooms
	var total := 0
	var shown_room = null
	for pos in main.dungeon_rooms.keys():
		main.current_room_pos = pos
		main.load_room(pos)
		for i in 4: await process_frame
		var room = main.current_room_node
		var tall = get_nodes_in_group("obstacles").filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion() and String(o.get("slot_name")).begins_with("tall"))
		check(tall.is_empty(), "room %s has no frond scenery (%d)" % [pos, tall.size()])
		var n = fronds().size()
		total += n
		check(n <= room.FROND_CAP, "room %s has at most %d fronds (%d)" % [pos, room.FROND_CAP, n])
		if n > 0 and main.get_room_type(pos) != 1:
			check(false, "fronds only in fight rooms")
		if n >= 2 and shown_room == null:
			shown_room = pos
	print("fronds on floor 1: ", total)
	check(total > 0, "floor 1 has some Charnia")
	if shown_room == null:
		print("no room with 2 fronds; spawning a test frond")
	else:
		main.current_room_pos = shown_room
		main.load_room(shown_room)
		for i in 10: await process_frame
	var room = main.current_room_node
	if fronds().is_empty():
		room.spawn_enemy(Vector2(1200, 540), "frond", 1)
	main.get_node("VisionFog").set_vision(10, true)
	main.hud.item_banner.visible = false
	# Leave the room's other animals out of it
	for e in get_nodes_in_group("enemies"):
		if e.enemy_type != "frond":
			e.process_mode = Node.PROCESS_MODE_DISABLED
	var f = fronds()[0]
	var home = f.global_position
	# Shots don't push a rooted frond
	f.apply_knockback(Vector2(900, 0))
	f.apply_hit_push(Vector2(900, 0))
	for i in 20: await physics_frame
	check(f.global_position.distance_to(home) < 1.0, "frond stays rooted when hit")
	# Far away: it just sways
	p.global_position = home + Vector2(-420, 60)
	var hurt := 0
	for i in 180:
		p.global_position = home + Vector2(-420, 60)
		p.invincibility_time = 0.0
		var h = p.health
		await physics_frame
		if p.health < h: hurt += 1
	check(hurt == 0 and f.lash_state == "", "leaves a player at a distance alone")
	await snap("1_charnia_swaying")
	# Close: winds up, then lashes
	var saw_windup := false
	var shot_windup := false
	var shot_lash := false
	for i in 240:
		p.global_position = home + Vector2(-120, 40)
		p.health = p.max_health
		var h = p.health
		await physics_frame
		if f.lash_state == "windup":
			saw_windup = true
			if f.lash_timer < 0.2 and not shot_windup:
				shot_windup = true
				await snap("2_charnia_winding_up")
		if f.lash_state == "lash" and f.lash_timer < 0.08 and not shot_lash:
			shot_lash = true
			await snap("3_charnia_lashing")
		if p.health < h: hurt += 1
	check(saw_windup, "bends back before it lashes")
	check(hurt > 0, "lash hurts a player who comes close (%d hits)" % hurt)
	check(f.global_position.distance_to(home) < 1.0, "still rooted after lashing")
	# Shots kill it
	p.invincibility_time = 9999.0
	p.global_position = home + Vector2(-110, 0) # close, so no scenery sits between
	var hp0 = f.health
	var killed := false
	for i in 120:
		if i == 30: print("  health after 30 shots: %.1f of %.1f" % [f.health if is_instance_valid(f) else 0.0, hp0])
		if not is_instance_valid(f) or f.dead:
			killed = true
			break
		p.spawn_tear((home - p.global_position).normalized())
		for k in 4: await physics_frame
	check(killed, "shots kill it")
	print("FROND done, %d failures" % fails)
	quit(1 if fails > 0 else 0)
