# itemtest.gd
# Picks up each treasure item from data/Items.gd and checks it does what its
# banner says. Run: godot --headless --path . -s res://tools/itemtest.gd
extends SceneTree
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var items = preload("res://data/Items.gd")
	var fails := 0
	var room = main.current_room_node

	# Every item has a name, fact, effect and icon, and the roll avoids repeats
	for it in items.LIST:
		var ok = it.name != "" and it.fact != "" and it.effect != "" and ResourceLoader.exists("res://assets/ui/icons/item_%s.png" % it.id)
		if not ok:
			fails += check("item %s complete" % it.id, false)
	var found: Array = []
	for i in items.LIST.size():
		var id = items.roll(found)
		if found.has(id):
			fails += check("roll repeats %s" % id, false)
		found.append(id)
	fails += check("roll covers all %d" % found.size(), found.size() == items.LIST.size())

	# Picking one up through a pedestal
	var ped = load("res://ItemPedestal.tscn").instantiate()
	ped.item_id = "plasmid"
	room.add_child(ped)
	var before = 0
	for id in p.adaptations_taken:
		before += p.adaptations_taken[id]
	ped._on_body_entered(p)
	var after = 0
	for id in p.adaptations_taken:
		after += p.adaptations_taken[id]
	fails += check("plasmid gives 2 adaptations (%d -> %d)" % [before, after], after == before + 2)
	fails += check("plasmid recorded", p.items_found.has("plasmid"))

	# Stat items
	var v = p.vision
	p.apply_item_upgrade("glow_bacteria")
	fails += check("glow bacteria vision %d -> %d" % [v, p.vision], p.vision == min(10, v + 2))
	var dcd = p.max_dash_cooldown
	p.apply_item_upgrade("lateral_line")
	fails += check("lateral line dash cd", p.max_dash_cooldown < dcd)

	# Chloroplasts heal over time
	p.apply_item_upgrade("kleptoplasty")
	p.health = p.max_health - 2
	p.photo_timer = 19.9
	for i in 20: await physics_frame
	fails += check("chloroplasts heal", p.health == p.max_health - 1)

	# Ink: hurt, then hidden
	p.apply_item_upgrade("ink_sac")
	p.invincibility_time = 0.0
	p.health = p.max_health
	p.take_damage(1)
	fails += check("ink hides %.1f" % p.cloak_time, p.cloak_time > 2.0)

	# Stingers: hits stun (forced to 100% for the test)
	p.apply_item_upgrade("nematocysts")
	fails += check("stinger chance", is_equal_approx(p.stun_chance, 0.2))
	p.stun_chance = 1.0
	room.spawn_enemy(Vector2(400, 300), "tank", 1)
	var e = room.active_enemies.back()
	e.take_damage(0.1)
	fails += check("stinger stuns", e.stun_timer > 0.5)
	p.stun_chance = 0.2

	# Alarm pheromone and decomposers: a kill freezes and hurts animals nearby
	p.apply_item_upgrade("alarm")
	p.apply_item_upgrade("decomposers")
	room.spawn_enemy(Vector2(1300, 700), "tank", 1)
	var victim = room.active_enemies.back()
	room.spawn_enemy(Vector2(1360, 700), "tank", 1)
	var near = room.active_enemies.back()
	near.stun_timer = 0.0
	var nh = near.health
	victim.take_damage(9999.0)
	fails += check("alarm freezes", near.stun_timer > 1.0)
	for i in 20: await physics_frame
	fails += check("decomposers hurt %.1f" % (nh - near.health), near.health < nh)

	# Head shield: dashing through an animal rams it
	p.apply_item_upgrade("headshield")
	p.escape_style = "dart"
	room.spawn_enemy(room.to_local(p.global_position) + Vector2(60, 0), "tank", 1)
	var target = room.active_enemies.back()
	target.process_mode = Node.PROCESS_MODE_DISABLED
	var th = target.health
	p.dash_cooldown = 0.0
	p.dash_direction = Vector2.RIGHT
	p.perform_bio_dash()
	for i in 20: await physics_frame
	fails += check("head shield rams %.1f" % (th - target.health), target.health < th)

	# Tetrodotoxin: spine pricks paralyse
	p.apply_item_upgrade("tetrodotoxin")
	fails += check("ttx thorns", p.thorns >= 1.0 and p.paralyse)

	# Items survive evolution
	var n = p.items_found.size()
	p.apply_evolution(1, 0)
	fails += check("items survive evolution", p.items_found.size() == n and p.paralyse and p.ram_mult > 0.0)

	print("ITEMS done, %d failures" % fails)
	quit()

func check(what: String, ok: bool) -> int:
	print("ITEMS %s: %s" % [what, "ok" if ok else "FAIL"])
	return 0 if ok else 1
