# sketchtest.gd
# Checks sketching from life (rooms/FieldSketch.gd): holding still near a
# calm animal sketches it; moving about doesn't; a predator that notices you
# spoils it unless you are hidden in cover; sketched kinds take more damage
# and are kept for the fossil record.
# With SHOT_DIR (xvfb) it takes a picture mid-sketch.
#   godot --headless --path . -s res://tools/sketchtest.gd
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

var main
var p
func room_on(f: int, cover: bool):
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
	data.covers = [{"pos": Vector2(520, 540), "size": Vector2(170, 120), "seed": 5}] if cover else []
	data.hazards_rolled = true
	data.hazards = []
	main.current_room_pos = pick
	main.load_room(pick)
	var room = main.current_room_node
	main.get_node("VisionFog").set_vision(10, true)
	data.waves_left = 0 # no second group turning everyone hostile
	for e in get_nodes_in_group("enemies"):
		room.active_enemies.erase(e)
		e.queue_free()
	await physics_frame
	return room

func hold(room, at: Vector2, frames: int, wiggle: bool = false):
	for i in frames:
		var off = Vector2(sin(i * 0.3) * 120.0, 0) if wiggle else Vector2.ZERO
		p.global_position = room.global_position + at + off
		p.velocity = Vector2(400, 0) if wiggle else Vector2.ZERO
		p.health = p.max_health
		p.invincibility_time = 9.0
		await physics_frame

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	p = main.player
	var codex = preload("res://data/Codex.gd")

	# A docile grazer, sketched by holding still
	var room = await room_on(1, false)
	check(room.get_node_or_null("FieldSketch") != null, "the room has a sketch layer")
	room.spawn_enemy(Vector2(900, 540), "pacer", 1)
	var kim = room.active_enemies[0]
	var nm = kim.fauna_name
	await hold(room, Vector2(900, 540) + Vector2(-260, 0), 20, true)
	check(not p.sketched.has(nm), "moving about doesn't sketch %s" % nm)
	await hold(room, Vector2(900, 540) + Vector2(-260, 0), 60 * 1)
	var fs = room.get_node("FieldSketch")
	check(fs.target == kim and fs.progress > 0.2, "the sketch is under way (%.2f)" % fs.progress)
	if out != "":
		kim.set_physics_process(false)
		await hold(room, Vector2(640, 540), 45)
		await snap("sketch_midway")
		kim.set_physics_process(true)
	await hold(room, Vector2(900, 540) + Vector2(-260, 0), 60 * 3)
	check(p.sketched.has(nm), "holding still sketches %s" % nm)
	check(codex.load_sketches().has(nm), "the sketch is kept for the fossil record")
	var titles = main.hud.journal.map(func(j): return j[0])
	check(titles.has("FIELD SKETCH: " + nm.to_upper()), "the sketch goes in the field journal %s" % [titles])
	# Hits on its kind land harder
	room.spawn_enemy(Vector2(1300, 300), "pacer", 1)
	room.spawn_enemy(Vector2(1300, 800), "tank", 1)
	var a = room.active_enemies[-2]
	var b = room.active_enemies[-1]
	var ha = a.health
	var hb = b.health
	a.take_damage(4.0)
	b.take_damage(4.0)
	await physics_frame
	check(abs((ha - a.health) - 5.0) < 0.01, "a sketched kind takes 1.25x (%.2f)" % (ha - a.health))
	check(abs((hb - b.health) - 4.0) < 0.01, "an unsketched kind takes 1x (%.2f)" % (hb - b.health))

	# A predator in the open notices you and spoils it
	room = await room_on(3, false)
	room.spawn_enemy(Vector2(900, 540), "pacer", 3)
	var pred = room.active_enemies[0]
	pred.speed = 0.0
	await hold(room, Vector2(900 - 160, 540), 60 * 4)
	print("SKETCH open reach %.0f" % (pred.aggro_radius * pred.player_notice() * pred.hunt_focus()))
	check(not p.sketched.has(pred.fauna_name), "%s notices you in the open: no sketch (mood %s)" % [pred.fauna_name, pred.mood])
	# Hidden in cover you can sketch it
	room = await room_on(3, true)
	await hold(room, Vector2(520, 540), 40) # settle in the growth first
	room.spawn_enemy(Vector2(790, 540), "pacer", 3)
	pred = room.active_enemies[0]
	pred.speed = 0.0 # stays put, but still looks about
	await hold(room, Vector2(520, 540), 60 * 5)
	check(p.sketched.has(pred.fauna_name), "from cover, %s is sketched (mood %s)" % [pred.fauna_name, pred.mood])
	print("SKETCH sketched: ", p.sketched.keys())
	print("SKETCH done, %d failures" % fails)
	quit()
