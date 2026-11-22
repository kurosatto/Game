# extrastest.gd
# Spawns every extra era animal (Fauna.EXTRAS, drawn with the playable forms'
# drawings) beside the player, lets it fight for a few seconds, then kills it,
# and reports that it got its name, drawing, behaviour and a clean death.
#   godot --headless --path . -s res://tools/extrastest.gd
# With SHOT_DIR (and a window: xvfb-run, --rendering-driver opengl3) it saves
# one picture per era with all its extra animals.
extends SceneTree
var fauna = preload("res://data/Fauna.gd")
var fails := 0

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.adapt_pending = true
	var shots = OS.get_environment("SHOT_DIR")
	for floor_num in range(1, 6):
		if shots != "":
			await era_shot(main, p, floor_num, shots)
			continue
		for sp in fauna.extras(floor_num):
			await test_one(main, p, floor_num, sp)
	# The room roll hands out extras about a third of the time
	var room = main.current_room_node
	var n := 0
	for i in 600:
		if "@" in room.roll_enemy_type("fly", 3):
			n += 1
	print("EXTRA roll share %.2f" % (n / 600.0))
	print("EXTRA done, %d failures" % fails)
	quit()

func test_one(main, p, floor_num: int, sp: Dictionary):
	var room = main.current_room_node
	var before = get_nodes_in_group("enemies").size()
	room.spawn_enemy(Vector2(1250, 540), "%s@%s" % [sp.type, sp.name], floor_num)
	var foes = get_nodes_in_group("enemies").filter(func(e): return e.get("fauna_name") == sp.name)
	var ok = foes.size() >= 1 and get_nodes_in_group("enemies").size() > before
	if not ok:
		print("EXTRA FAIL %s did not spawn" % sp.name)
		fails += 1
		return
	var e = foes[0]
	var drawn = e.body_art != null and e.body_art.form_id == sp.form
	for f in foes: f.provoke()
	var start = e.global_position
	var struck = false
	for f in 240:
		p.invincibility_time = 99.0
		p.health = p.max_health
		p.global_position = room.global_position + Vector2(700, 540)
		await physics_frame
		if is_instance_valid(e) and e.body_art and e.body_art.atk < 0.3:
			struck = true
	var moved = is_instance_valid(e) and e.global_position.distance_to(start) > 20.0
	for f in foes:
		if is_instance_valid(f):
			f.take_damage(9999.0)
	for i in 30: await physics_frame
	var gone = foes.all(func(f): return not is_instance_valid(f))
	var good = drawn and gone and e.enemy_type == sp.type if is_instance_valid(e) else drawn and gone
	print("EXTRA floor %d %s (%s as %s): drawn=%s moved=%s struck=%s died=%s" % [floor_num, sp.name, sp.form, sp.type, drawn, moved, struck, gone])
	if not (drawn and gone):
		fails += 1

func era_shot(main, p, floor_num: int, dir: String):
	main.floor_number = floor_num
	main.generate_floor()
	for pos in main.dungeon_rooms:
		var r = main.dungeon_rooms[pos]
		if r.type == 1 and (pos - main.current_room_pos).length() == 1:
			main.current_room_pos = pos
			main.load_room(pos)
			break
	var room = main.current_room_node
	for e in get_nodes_in_group("enemies"):
		room.active_enemies.erase(e)
		e.queue_free()
	var extras = fauna.extras(floor_num)
	var spots = [Vector2(900, 360), Vector2(1250, 330), Vector2(1550, 420), Vector2(1000, 700), Vector2(1400, 730)]
	for i in extras.size():
		var sp = extras[i]
		room.spawn_enemy(spots[i], "%s@%s" % [sp.type, sp.name], floor_num)
	main.get_node("VisionFog").set_vision(10, true)
	main.hud.item_banner.visible = false
	for f in 70:
		p.invincibility_time = 99.0
		p.health = 999
		p.global_position = room.global_position + Vector2(420, 540)
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/era%d_extras.png" % [dir, floor_num])
	print("SHOT era%d" % floor_num)
