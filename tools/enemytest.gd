# enemytest.gd
# Spawns each era's third animal next to an untouchable player for a few
# seconds and reports what its behaviour did (charges, dazes, burrows,
# blocked hits). Run: godot --headless --path . -s res://tools/enemytest.gd
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
		var type = fauna.special_type(floor_num)
		var room = main.current_room_node
		room.spawn_enemy(Vector2(1300, 540), type, floor_num)
		var foes = get_nodes_in_group("enemies").filter(func(e): return e.enemy_type == type)
		var seen := {}
		for f in 360:
			p.invincibility_time = 99.0
			p.health = p.max_health
			p.global_position = room.global_position + Vector2(700, 540)
			await physics_frame
			for e in foes:
				if not is_instance_valid(e):
					continue
				if e.charge_state != "": seen["charge_" + e.charge_state] = true
				if e.stun_timer > 0.5: seen["dazed"] = true
				if e.is_burrowed(): seen["burrowed"] = true
				if e.flee_timer > 0: seen["scatter"] = true
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
		print("ENEMY floor %d %s x%d: %s" % [floor_num, type, foes.size(), seen.keys()])
		for e in foes:
			if is_instance_valid(e):
				e.queue_free()
		for i in 5: await physics_frame
	print("ENEMY done")
	quit()
