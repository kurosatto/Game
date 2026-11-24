# filtertest.gd
# The crinoid filter fan (Player.filter_fan): holding attack keeps catching,
# so animals in the fan lose health every fraction of a second, get drawn
# in, and die; staying still opens the fan wider; the early echinoderm sees
# least of all.
# Run: godot --headless --path . -s res://tools/filtertest.gd
extends SceneTree
var lineages = preload("res://data/Lineages.gd")
var failures := 0

func check(ok: bool, what: String):
	print("FILTER %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures += 1

func form(id: String) -> Dictionary:
	for path in lineages.TREE:
		if lineages.TREE[path].id == id:
			return lineages.TREE[path]
	return {}

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var room = main.current_room_node
	for e in room.active_enemies:
		if is_instance_valid(e): e.queue_free()
	for id in ["sea_lily", "feather_star", "metacrinus"]:
		p.apply_form(form(id))
		check(p.current_weapon == "filter", "%s holds a filter fan" % id)
	p.apply_form(form("sea_lily"))
	p.global_position = room.global_position + Vector2(700, 540)
	var e = load("res://Enemy.tscn").instantiate()
	e.enemy_type = "pacer"
	e.position = Vector2(830, 540)
	room.add_child(e)
	e.setup_enemy(2)
	e.set_physics_process(false)
	e.max_health = 200.0
	e.health = 200.0
	var hp0 = e.health
	# One press already catches
	p.shoot_cooldown = 0.0
	p.shoot_tear(Vector2.RIGHT)
	check(e.health < hp0, "a single press digests at once (%.1f -> %.1f)" % [hp0, e.health])
	# Held: it keeps working, with no long gap between bites
	var hits := 0
	var last = e.health
	var frames_held := 0
	for i in 60:
		p.velocity = Vector2.ZERO
		if p.shoot_cooldown <= 0.0 and is_instance_valid(e):
			p.shoot_tear(Vector2.RIGHT)
		await physics_frame
		frames_held += 1
		if not is_instance_valid(e) or e.dead:
			break
		if e.health < last:
			hits += 1
			last = e.health
	check(hits >= 5, "held for a second it bites again and again (%d times)" % hits)
	check(p.filter_open > 0.5, "standing still opens the fan (%.2f)" % p.filter_open)
	check(p.filter_node != null and p.filter_node.shown > 0.5, "the fan is drawn while held")
	# Damage per second is at least the old sweep's
	var dps_target = p.damage * 1.6 / (p.fire_delay * 1.3)
	var w = lineages.weapon_stats("filter")
	var dps = p.damage * w.damage / (p.fire_delay * w.cooldown)
	check(dps >= dps_target * 0.85, "the fan does steady damage (%.0f/s vs sweep %.0f/s)" % [dps, dps_target])
	# Keep at it until it is eaten
	for i in 600:
		if not is_instance_valid(e) or e.dead:
			break
		p.velocity = Vector2.ZERO
		if p.shoot_cooldown <= 0.0:
			p.shoot_tear(Vector2.RIGHT)
		await physics_frame
	check(not is_instance_valid(e) or e.dead, "the fan finishes the animal off")
	# Released: it folds away
	for i in 40: await physics_frame
	check(p.filter_hold <= 0.0 and p.filter_node.shown < 0.05, "let go, the arms fold")
	# Eyeless early echinoderm sees least
	p.apply_form(form("early_echinoderm"))
	check(p.vision == 0 or lineages.get_vision(form("early_echinoderm")) == 0, "early echinoderm is eyeless (%d)" % p.vision)
	print("FILTER done, %d failures" % failures)
	quit(1 if failures > 0 else 0)
