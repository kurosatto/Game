# enemytest.gd
# Spawns each era's special animals (third and fourth) next to the player for
# a few seconds and reports what each behaviour did (charges, dazes, burrows,
# blocked hits, sprouts, rolls, slime, venom). Run:
#   godot --headless --path . -s res://tools/enemytest.gd
extends SceneTree
var fauna = preload("res://data/Fauna.gd")
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.adapt_pending = true
	for floor_num in range(1, 6):
		for type in fauna.special_types(floor_num):
			await test_type(main, p, floor_num, type)
	print("ENEMY done")
	quit()

func test_type(main, p, floor_num: int, type: String):
	var room = main.current_room_node
	room.spawn_enemy(Vector2(1300, 540), type, floor_num)
	var foes = get_nodes_in_group("enemies").filter(func(e): return e.enemy_type == type)
	# Skip the calm idling (tools/moodtest.gd covers it): test the fight
	for e in foes: e.provoke()
	var seen := {}
	var start_dist = foes[0].global_position.distance_to(room.global_position + Vector2(700, 540))
	# Slime and venom only land on a player who can be touched
	var touchable = type in ["snarer", "orbiter"]
	if type == "enroll":
		foes[0].take_damage(1.0)
		seen["enrolled_after_hit"] = foes[0].is_enrolled()
		var h = foes[0].health
		foes[0].take_damage(5.0)
		seen["immune_while_rolled"] = foes[0].health == h
	for f in 420:
		p.invincibility_time = 0.0 if touchable else 99.0
		p.health = p.max_health
		p.global_position = room.global_position + Vector2(700, 540)
		await physics_frame
		for e in foes:
			if not is_instance_valid(e):
				continue
			if e.charge_state != "": seen["charge_" + e.charge_state] = true
			if e.spray_state != "": seen["spray_" + e.spray_state] = true
			if e.stun_timer > 0.5: seen["dazed"] = true
			if e.is_burrowed(): seen["burrowed"] = true
			if e.flee_timer > 0: seen["scatter"] = true
		if p.slow_timer > 0: seen["player_slowed"] = true
	var e0 = foes[0]
	if type == "armoured":
		e0.facing = (p.global_position - e0.global_position).normalized()
		var h = e0.health
		e0.take_damage(4.0)
		seen["front_damage_%.1f" % (h - e0.health)] = true
		e0.facing = -e0.facing
		h = e0.health
		e0.take_damage(4.0)
		seen["back_damage_%.1f" % (h - e0.health)] = true
	if type == "swarm":
		e0.take_damage(0.1)
		seen["scatter"] = seen.get("scatter", false) or foes.any(func(e): return is_instance_valid(e) and e.flee_timer > 0)
	if type == "colony":
		seen["fronds_%d" % get_nodes_in_group("enemies").filter(func(e): return e.enemy_type == "colony").size()] = true
	if type == "skittish":
		seen["fled_%d_to_%d" % [start_dist, e0.global_position.distance_to(p.global_position)]] = true
	print("ENEMY floor %d %s x%d: %s" % [floor_num, type, foes.size(), seen.keys()])
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.enemy_type == type:
			e.queue_free()
	for i in 5: await physics_frame
