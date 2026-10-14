# moodtest.gd
# Checks animal personality (Enemy.process_mood, data/Fauna.gd TEMPERS):
# each era's animals idle calmly while you keep away, notice you when you
# come close (timid ones back off, docile ones ignore you), fight back when
# hit and alarm their kind, and give up again when you leave (predators
# don't). Run:
#   godot --headless --path . -s res://tools/moodtest.gd
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
	var room = main.current_room_node
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	for floor_num in range(1, 6):
		for type in ["fly", "pacer"] + fauna.special_types(floor_num):
			var f = fauna.get_fauna(floor_num, type)
			if f.get("temper", "") == "":
				continue
			await test_type(room, p, floor_num, type, f)
	print("MOOD done, %d failures" % fails)
	quit()

func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)

func hold(p, room, pos: Vector2, frames: int):
	for i in frames:
		p.invincibility_time = 99.0
		p.health = p.max_health
		p.global_position = room.global_position + pos
		await physics_frame

func test_type(room, p, floor_num: int, type: String, f: Dictionary):
	room.spawn_enemy(Vector2(1300, 380), type, floor_num)
	room.spawn_enemy(Vector2(1380, 640), type, floor_num)
	var foes = get_nodes_in_group("enemies").filter(func(e): return e.enemy_type == type and not e.is_queued_for_deletion())
	var a = foes[0]
	var b = foes[-1]
	var t = f.temper
	# Far away: everyone idles and stays near home
	await hold(p, room, Vector2(330, 540), 240)
	var far_calm = foes.all(func(e): return e.mood == "calm")
	var strayed = 0.0
	for e in foes:
		strayed = max(strayed, e.global_position.distance_to(e.home_pos))
	check(far_calm or t == "predator", "%s calm while far" % f.name)
	# Step up close to the first
	var near_pos = a.position + Vector2(-(a.aggro_radius * 0.7), 0)
	if t == "docile":
		near_pos = a.position + Vector2(-(a.aggro_radius + 90.0), 0)
	await hold(p, room, near_pos, 90)
	var near_mood = a.mood
	if t == "docile":
		check(a.mood == "calm", "%s docile ignores you nearby" % f.name)
	elif t != "timid":
		check(a.mood == "hostile", "%s notices you close" % f.name)
	# Hit it: it fights, its kin are alarmed
	await hold(p, room, Vector2(330, 540), 20)
	for e in foes:
		e.home_pos = e.global_position
	a.take_damage(0.1)
	await hold(p, room, Vector2(330, 540), 75)
	check(a.mood == "hostile", "%s fights when hit" % f.name)
	var kin_dist = a.global_position.distance_to(b.global_position)
	var kin_mood = b.mood
	if kin_dist < 360.0:
		check(b.mood == "hostile", "%s alarms kin" % f.name)
	# Leave them alone (out of the room's reach) and see who gives up
	var gave_up = false
	for i in 50:
		await hold(p, room, Vector2(-1400, -1400), 10)
		for e in foes:
			if is_instance_valid(e):
				e.stun_timer = 0.0
		if a.mood == "calm":
			gave_up = true
			break
	check(gave_up == (t != "predator"), "%s gives up: %s" % [f.name, gave_up])
	print("MOOD floor %d %-15s %-11s %-6s strayed %3d  near:%s  kin@%d:%s  gave_up:%s" % [floor_num, f.name, t, f.idle, strayed, near_mood, kin_dist, kin_mood, gave_up])
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()
	await hold(p, room, Vector2(330, 540), 5)
