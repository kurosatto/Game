# crinoidtest.gd
# The crinoid line (sea lily -> stalked sea lily -> Endoxocrinus/Metacrinus,
# and feather stars): the held filter fan digs fossil slabs open, stalked sea
# lilies crawl off on the dash button, the bowl fan turns caught shots into
# food, Metacrinus sheds arms and regrows them, feather stars swim with the
# fan open, and the sea lily is slower and frailer than before.
# Run: godot --headless --path . -s res://tools/crinoidtest.gd
extends SceneTree
var lineages = preload("res://data/Lineages.gd")
var failures := 0
var main: Node
var p: Node

func check(ok: bool, what: String):
	print("CRINOID %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures += 1

func form(id: String) -> Dictionary:
	for path in lineages.TREE:
		if lineages.TREE[path].id == id:
			return lineages.TREE[path]
	return {}

func hold_fan(n: int, dir := Vector2.RIGHT, moving := false):
	for i in n:
		if moving:
			p.velocity = dir * 300.0
		else:
			p.velocity = Vector2.ZERO
		if p.shoot_cooldown <= 0.0:
			p.shoot_tear(dir)
		await physics_frame

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	p = main.player
	var room = main.current_room_node
	for e in room.active_enemies:
		if is_instance_valid(e): e.queue_free()

	# Slower and frailer than before (was 280 speed, +6 health)
	var lily = form("sea_lily")
	check(lily.speed <= 220.0 and lily.max_health_add <= 3, "sea lily is slow (%d) with less health (+%d)" % [lily.speed, lily.max_health_add])

	# Hit to dig: the fan breaks a fossil slab open
	p.apply_form(lily)
	p.global_position = room.global_position + Vector2(700, 540)
	var slab = load("res://rooms/FossilSlab.gd").new()
	slab.floor_num = 3
	slab.position = Vector2(860, 540)
	room.add_child(slab)
	await hold_fan(240)
	check(slab.broken, "holding the filter fan on a fossil slab digs it open (%d hits)" % slab.hits)
	slab.queue_free()

	# Stalked sea lily: CRAWL moves it a short way
	p.apply_form(form("isocrinid_sea_lily"))
	check(p.dash_label() == "CRAWL", "stalked sea lily's button says %s" % p.dash_label())
	p.dash_cooldown = 0.0
	p.dash_direction = Vector2.DOWN
	var start: Vector2 = p.global_position
	p.perform_bio_dash()
	for i in 30: await physics_frame
	var moved = p.global_position.distance_to(start)
	check(moved > 100.0 and moved < 300.0, "crawl carries it a short way (%.0f px)" % moved)
	check(lineages.fan_twist("metacrinus")[0] == "shed" and lineages.get_escape(form("endoxocrinus"))[0] == "crawl", "descendants keep the crawl")

	# Endoxocrinus: 5 caught shots feed it
	p.apply_form(form("endoxocrinus"))
	p.health = p.max_health - 2
	var hp = p.health
	var tear_scene = load("res://Tear.tscn")
	for i in 5:
		var t = tear_scene.instantiate()
		t.is_enemy_tear = true
		t.add_to_group("enemy_tears")
		t.global_position = p.global_position + Vector2(70, 0)
		room.add_child(t)
		t.set_physics_process(false)
		p.shoot_cooldown = 0.0
		p.shoot_tear(Vector2.RIGHT)
		await physics_frame
	check(p.health > hp, "bowl fan: five caught shots are digested into health (%d -> %d)" % [hp, p.health])

	# Metacrinus: sheds an arm instead of a hit, regrows it
	p.apply_form(form("metacrinus"))
	p.invincibility_time = 0.0
	hp = p.health
	check(p.autotomy_ready, "Metacrinus starts with an arm to spare")
	p.take_damage(1)
	check(p.health == hp and not p.autotomy_ready, "the arm is shed instead of a hit")
	p.arm_regrow = p.ARM_REGROW_TIME - 0.05
	for i in 10: await physics_frame
	check(p.autotomy_ready, "the arm grows back")

	# Feather star: fan stays open while swimming
	p.apply_form(form("rosy_feather_star"))
	p.filter_open = 0.0
	await hold_fan(90, Vector2.RIGHT, true)
	check(p.filter_open > 0.6, "feather star's fan stays open on the move (%.2f)" % p.filter_open)
	p.apply_form(lily)
	p.filter_open = 0.0
	await hold_fan(90, Vector2.RIGHT, true)
	check(p.filter_open < 0.4, "a sea lily's fan folds when it moves (%.2f)" % p.filter_open)

	print("CRINOID done, %d failures" % failures)
	quit(1 if failures > 0 else 0)
