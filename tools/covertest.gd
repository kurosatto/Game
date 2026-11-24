# covertest.gd
# Checks hiding in growth (Cover.gd, Room.spawn_covers): inside a patch the
# form is far harder to notice; a hunter chasing you from across the room
# loses you after a moment, one close by does not; patches are kept per room.
# With SHOT_DIR (xvfb) it also takes a picture of each era's growth.
#   godot --headless --path . -s res://tools/covertest.gd
extends SceneTree
var fails := 0
var out := OS.get_environment("SHOT_DIR")
func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)
func snap(n: String):
	if out == "":
		return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var p = main.player
	for f in [1, 2, 3, 4, 5]:
		main.floor_number = f
		main.generate_floor()
		var pick = null
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and r.special == "" and pos != Vector2i(4, 4):
				pick = pos
				break
		var data = main.dungeon_rooms[pick]
		data.covers_rolled = true
		data.covers = [{"pos": Vector2(520, 540), "size": Vector2(160, 110), "seed": 5}]
		data.hazards_rolled = true
		data.hazards = []
		main.current_room_pos = pick
		main.load_room(pick)
		var room = main.current_room_node
		main.get_node("VisionFog").set_vision(10, true)
		for e in get_nodes_in_group("enemies"):
			room.active_enemies.erase(e)
			e.queue_free()
		await physics_frame
		var cover = get_nodes_in_group("covers").filter(func(c): return c.get_parent() == room)
		check(cover.size() == 1, "era %d: the cover patch is there" % f)
		# Outside, then inside: noticed from much less far
		for i in 20:
			p.global_position = Vector2(1300, 540)
			await physics_frame
		var out_m = p.notice_mult()
		p.global_position = Vector2(520, 540)
		for i in 5:
			p.global_position = Vector2(520, 540)
			await physics_frame
		var in_m = p.notice_mult()
		check(in_m < out_m * 0.5, "era %d: hidden in cover (%.2f vs %.2f)" % [f, in_m, out_m])
		# A hunter far off and one close: the far one loses you
		var far_t = "pacer" if f >= 2 else "fly"
		room.spawn_enemy(Vector2(1500, 300), far_t, f)
		room.spawn_enemy(Vector2(700, 600), far_t, f)
		var foes = room.active_enemies.duplicate()
		for e in foes:
			e.become_hostile()
		var far = foes[0]
		var near = foes[1]
		for i in 60 * 2:
			p.global_position = Vector2(520, 540)
			p.health = p.max_health
			p.invincibility_time = 9.0
			if is_instance_valid(near):
				near.global_position = Vector2(700, 600)
			if is_instance_valid(far):
				far.global_position = Vector2(1500, 300)
			await physics_frame
		check(is_instance_valid(far) and far.mood != "hostile", "era %d: the far hunter loses you (%s)" % [f, far.mood if is_instance_valid(far) else "gone"])
		check(is_instance_valid(near) and near.mood == "hostile", "era %d: the near one still sees you" % f)
		if out != "":
			for e in foes:
				if is_instance_valid(e):
					e.queue_free()
			p.global_position = Vector2(560, 560)
			await snap("cover_era%d" % f)
		print("COVER era %d: notice %.2f -> %.2f" % [f, out_m, in_m])
	# Rolled patches stay with the room
	var rd = main.current_room_node.room_data
	rd.covers_rolled = false
	rd.covers = []
	var counts = {}
	for k in 40:
		rd.covers_rolled = false
		rd.covers = []
		main.current_room_node.spawn_covers(3)
		counts[rd.covers.size()] = counts.get(rd.covers.size(), 0) + 1
	check(counts.get(0, 0) > 5 and counts.get(0, 0) < 35, "about half the rooms get cover %s" % counts)
	print("COVER rolls: ", counts)
	print("COVER done, %d failures" % fails)
	quit()
