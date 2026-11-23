# senseshots.gd
# What every non-visual sense shows (SenseHints.gd), one sense at a time and
# then a few real forms' whole sense profiles, with a nearly blind form so the
# room's animals sit in the dark. Animals move and two are wounded, so scent
# trails, ripples, footsteps and taste clouds all show. Needs a window, not --headless.
# Run: SHOT_DIR=<folder> SHOT_SIZE=2340x1080 godot --path . -s res://tools/senseshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var size_env := OS.get_environment("SHOT_SIZE")
	if size_env != "":
		var parts = size_env.split("x")
		for i in 5: await process_frame
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		for i in 5: await process_frame
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		for i in 10: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var hud = main.get("hud")
	for c in hud.get_children() if hud else []:
		if c is Control and c.name.contains("Card"):
			c.visible = false
	var p = main.player
	for pos in main.dungeon_rooms:
		if main.dungeon_rooms[pos].type == 1 and (pos - main.current_room_pos).length() == 1:
			main.current_room_pos = pos
			main.load_room(pos)
			break
	var room = main.current_room_node
	for e in get_nodes_in_group("enemies"):
		room.active_enemies.erase(e)
		e.queue_free()
	await process_frame
	for spot in [Vector2(1700, 250), Vector2(250, 850), Vector2(1650, 880), Vector2(300, 220)]:
		room.spawn_enemy(spot, "pacer", 1)
	for i in 5: await physics_frame
	p.global_position = room.global_position + Vector2(960, 540)
	p.health = 999
	p.invincibility_time = 9999.0
	main.hud.item_banner.visible = false
	var fog = main.get_node("VisionFog")
	fog.set_vision(1, true)
	var n := 0
	for e in get_nodes_in_group("enemies"):
		if e.has_method("become_hostile"):
			e.become_hostile()
		if n % 2 == 0:
			e.health = e.max_health * 0.4
		n += 1
	var styles = OS.get_environment("SHOT_STYLES")
	var lin = load("res://data/Lineages.gd")
	for st in (styles.split(",") if styles != "" else PackedStringArray(["sepia"])):
		var settings = root.get_node("SettingsManager")
		var before: String = settings.art_style
		settings.set_art_style(st)
		var runs: Array = []
		for kind in lin.SENSE_ORDER:
			runs.append([kind.to_lower().replace(" ", "_"), {kind: 8}, kind])
		for id in ["shark_line", "spider", "synapsid"]:
			runs.append([id, lin.sense_profile({"id": id}), lin.SENSES[id][1]])
		for r in runs.filter(func(x): return OS.get_environment("ONLY") == "" or x[0] == OS.get_environment("ONLY")):
			# Animals back out in the dark, then a moment to move and leave trails
			var k := 0
			for e in get_nodes_in_group("enemies"):
				e.global_position = room.global_position + [Vector2(1350, 330), Vector2(520, 760), Vector2(1450, 760), Vector2(560, 300)][k % 4]
				k += 1
			fog.hints.trails.clear()
			fog.set_sense(8, r[2], r[1])
			# Each animal swims a slow loop (one holds still) so trails and ripples
			# show; moved every drawn frame so they are still moving at the snap
			var es = get_nodes_in_group("enemies")
			for e in es:
				e.process_mode = Node.PROCESS_MODE_DISABLED
			var clock := [0.0]
			var mover = func():
				clock[0] += 1.0
				for j in es.size() - 1:
					var a = clock[0] * 0.05 + j * 1.7
					es[j].global_position += Vector2(cos(a), sin(a) * 0.8) * 6.0
			process_frame.connect(mover)
			for i in 60:
				# Touch: brush past one animal, then it slips back into the dark
				if r[1].has("Touch") and i < 30:
					es[1].global_position = p.global_position + Vector2(70, 40)
				if r[1].has("Touch") and i == 30:
					es[1].global_position = room.global_position + Vector2(1350, 640)
				if i == 52 and r[1].has("Vibration"):
					# One coils to lunge: the warning tremor (as Enemy.attack_pose() would trigger)
					fog.hints.tremors.append([es[0].global_position, 0.0, true])
				await process_frame
			await snap("%s_%s" % [st, r[0]])
			process_frame.disconnect(mover)
		settings.set_art_style(before)
	quit()
