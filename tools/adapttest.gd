# adapttest.gd
# Grants each of the newer adaptations and checks it does what its card says.
# Run: godot --headless --path . -s res://tools/adapttest.gd
extends SceneTree
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.adapt_pending = true
	var fails := 0
	# Autotomy: the first hit is shed, the second lands, clearing a room re-arms it
	p.grant_adaptation("autotomy")
	var h = p.health
	p.take_damage(1)
	fails += check("autotomy sheds a hit", p.health == h)
	p.invincibility_time = 0.0
	p.take_damage(1)
	fails += check("autotomy only once", p.health == h - 1)
	p.on_room_cleared()
	fails += check("autotomy re-arms", p.autotomy_ready)
	# Giant escape neurons: longer dash invulnerability
	p.invincibility_time = 0.0
	p.grant_adaptation("mauthner")
	p.dash_cooldown = 0.0
	p.perform_bio_dash()
	fails += check("mauthner iframes %.2f" % p.invincibility_time, p.invincibility_time > 0.4)
	for i in 30: await physics_frame
	# Gut symbionts: 12 biomass heals half a heart
	p.grant_adaptation("symbionts")
	p.health = p.max_health - 2
	p.add_biomass(12.0)
	fails += check("symbionts heal", p.health == p.max_health - 1)
	# Serrated edges and the electric organ set their stats
	p.grant_adaptation("serrated")
	p.grant_adaptation("electrocytes")
	fails += check("serrated crit", is_equal_approx(p.crit_chance, 0.15))
	fails += check("electric organ", is_equal_approx(p.zap_power, 0.4))
	# Defensive spines prick an enemy pressed against you
	p.grant_adaptation("thorns")
	var room = main.current_room_node
	room.spawn_enemy(room.to_local(p.global_position) + Vector2(40, 0), "tank", 1)
	var e = room.active_enemies.back()
	e.process_mode = Node.PROCESS_MODE_DISABLED
	var eh = e.health
	for i in 70:
		p.invincibility_time = 9.0
		await physics_frame
	fails += check("thorns prick %.1f" % (eh - e.health), e.health < eh)
	print("ADAPT done, %d failures" % fails)
	quit()

func check(what: String, ok: bool) -> int:
	print("ADAPT %s: %s" % [what, "ok" if ok else "FAIL"])
	return 0 if ok else 1
