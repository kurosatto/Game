# bosspartstest.gd
# Hits every boss on the far end of its drawing (tail tip, shell tip, limb,
# sail: whatever sticks out furthest from its middle) with a melee form and
# a shooting form, and checks the boss loses health each time.
#   godot --headless --path . -s res://tools/bosspartstest.gd
# Prints PARTS lines and "BOSSPARTS ok" or "BOSSPARTS FAIL".
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
var lineages = preload("res://data/Lineages.gd")

func _initialize():
	run()

func form_with(weapon: String) -> Dictionary:
	for path in lineages.TREE:
		if lineages.TREE[path].get("weapon", "") == weapon:
			return lineages.TREE[path]
	return {}

# The drawn piece furthest from the boss's middle, in global space
func far_point(boss) -> Vector2:
	var best := Vector2.ZERO
	for d in boss.hit_pieces()[0]:
		var pts: Array = []
		if d[0] is PackedVector2Array:
			pts = Array(d[0])
		else:
			pts = [d[0], d[1]]
		for q in pts:
			if q.length() > best.length():
				best = q
	return boss.to_global(best)

func run():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var cases = []
	for f in range(1, 6):
		cases.append([f, false, false, "orig"])
		cases.append([f, false, false, "res://bosses/DrawnBoss.gd"])
	for f in [4, 5]:
		cases.append([f, true, false, "orig"])
		cases.append([f, true, false, "res://bosses/DrawnBoss.gd"])
	cases.append([5, false, true, "res://bosses/Inostrancevia.gd"])
	cases.append([5, true, true, "res://bosses/Campylocephalus.gd"])
	cases.append([4, false, false, "res://bosses/Megarachne.gd"])
	cases.append([4, true, false, "res://bosses/Saivodus.gd"])
	var fails := 0
	for c in cases:
		Worlds.sea = c[1]
		Worlds.finale = c[2]
		main.floor_number = c[0]
		main.generate_floor()
		for i in 10: await process_frame
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		# Stay in this room whatever doors the player bumps into
		var room = main.current_room_node
		if room.room_transition_requested.is_connected(main._on_room_transition_requested):
			room.room_transition_requested.disconnect(main._on_room_transition_requested)
		var path: String = c[3] if c[3] != "orig" else load("res://Room.gd").BOSSES.get(Worlds.era(c[0]))
		var boss = load(path).new()
		boss.position = Vector2(960, 540)
		boss.setup_enemy(c[0])
		main.current_room_node.add_child(boss)
		main.register_boss(boss)
		p.global_position = boss.global_position + Vector2(0, 700)
		for i in 100: await physics_frame
		boss.set_physics_process(false)
		boss.max_health = 1000000.0
		boss.health = boss.max_health
		for i in 3: await process_frame
		var main_r: float = boss.hurt_parts()[0][1]
		for weapon in ["bite", "sting", "spit", "vesicle"]:
			var form = form_with(weapon)
			if form.is_empty():
				continue
			p.apply_form(form)
			var tip := far_point(boss)
			var out: Vector2 = (tip - boss.global_position).normalized()
			var stand: Vector2 = tip + out * (40.0 if lineages.weapon_stats(weapon).melee else 220.0)
			var room_at: Vector2 = main.current_room_node.global_position
			stand = stand.clamp(room_at + Vector2(170, 170), room_at + Vector2(1750, 910))
			p.global_position = stand
			p.reset_physics_interpolation()
			p.invincibility_time = 99.0
			# Bosses that dive or leap can't be hurt then; test them in reach
			for k in ["depth", "dive", "air", "haze"]:
				if boss.get(k) != null:
					boss.set(k, 0.0)
			var before: float = boss.health
			for n in 3:
				p.shoot_cooldown = 0.0
				p.shoot_tear((tip - stand).normalized())
				for i in 25: await physics_frame
				p.global_position = stand
			if not is_instance_valid(boss):
				print("PARTS boss gone during ", weapon, " ", path)
				fails += 1
				break
			var ok: bool = boss.health < before
			var far: float = tip.distance_to(boss.global_position)
			print("PARTS %-16s %-7s tip %4.0f px out (body radius %3.0f): %s" % [boss.killer_name(), weapon, far, main_r, "hit" if ok else "MISSED"])
			if not ok:
				fails += 1
			boss.health = boss.max_health
		if is_instance_valid(boss):
			boss.set_physics_process(true)
			boss.take_damage(99999.0)
		for i in 30: await process_frame
		for t in get_nodes_in_group("tears"):
			t.queue_free()
	print("BOSSPARTS ", "ok" if fails == 0 else "FAIL %d" % fails)
	quit()
