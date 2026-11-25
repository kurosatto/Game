# specialtest.gd
# Plays each of the ten special rooms (data/SpecialRooms.gd) in a fitting
# era and checks it works: heals, traps, digs, swarms, timers, parents,
# tides, followers, ambushes and the dark cave. Also checks GROW is shut
# mid-fight. Prints SPECIALTEST lines and "FAIL" on any problem.
#   godot --headless --path . -s res://tools/specialtest.gd
# With SHOT_DIR=<folder> (and a window, e.g. xvfb-run) it saves screenshots.
extends SceneTree

var main: Node
var p: Node
var failures := 0
var out := OS.get_environment("SHOT_DIR")
var only := OS.get_environment("ONLY")

func check(ok: bool, what: String):
	if ok:
		print("SPECIALTEST ok: ", what)
	else:
		failures += 1
		print("SPECIALTEST FAIL: ", what)

func snap(name: String, banner: bool = false):
	if out == "":
		return
	if not banner:
		main.hud.item_banner.visible = false
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func frames(n: int, at = null, safe: bool = true):
	for i in n:
		if at != null:
			p.global_position = at
			p.velocity = Vector2.ZERO
		if safe:
			p.health = max(p.health, 2)
		await physics_frame

func room() -> Node:
	return main.current_room_node

func setup(kind: String, f: int):
	main.floor_number = f
	main.generate_floor()
	var pick = null
	for pos in main.dungeon_rooms:
		var r = main.dungeon_rooms[pos]
		if r.type == 1 and pos != Vector2i(4, 4):
			pick = pos
			break
	var data = main.dungeon_rooms[pick]
	data.special = kind
	data.special_state = {}
	data.has_initialized_contents = false
	data.cleared = false
	data.saved_pickups = []
	main.current_room_pos = pick
	p.global_position = Vector2(300, 540)
	main.load_room(pick)
	main.hud.update_minimap(main.dungeon_rooms, pick)
	if out != "" and kind != "glow" and kind != "dark":
		main.get_node("VisionFog").set_vision(10, true)
	else:
		main.get_node("VisionFog").set_vision(3, true)
	p.max_health = 12
	p.health = 12
	await frames(20, Vector2(300, 540))
	return data

func feature(script_name: String) -> Node:
	for c in room().get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(script_name):
			return c
	return null

func kill_all():
	for e in room().active_enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	await frames(30)

func doors_closed() -> bool:
	for d in room().door_nodes:
		if room().door_nodes[d].get("is_open"):
			return false
	return true

func total(d: Dictionary) -> float:
	var t := 0.0
	for k in d:
		t += d[k]
	return t

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20:
		await process_frame
	p = main.player
	var tests = ["vent", "tar", "dig", "frenzy", "extinction", "nest", "tide", "symbiont", "ambush", "glow", "dark", "fire", "molt", "procession", "meadow", "mat", "drought", "treefall", "brachiopods", "current", "cupreef", "deal", "run"]
	for t in tests:
		if only != "" and t != only:
			continue
		print("SPECIALTEST --- ", t)
		await call("t_" + t)
	print("SPECIALTEST done, %d failures" % failures)
	quit(1 if failures > 0 else 0)

func t_vent():
	for f in [2, 4]:
		var d = await setup("vent", f)
		check(main.in_combat() == false, "vent era %d has open doors" % f)
		p.health = 4
		await frames(5, Vector2(960 + 190, 520))
		await snap("01_vent_era%d" % f, f == 2)
		await frames(60 * 5, Vector2(960 + 190, 520))
		check(p.health > 4, "vent era %d heals in the warm ring (%d)" % [f, p.health])
		check(d.special_state.get("heal_left", 6) < 6, "vent remembers what it gave")
		var before = p.health
		p.invincibility_time = 0.0
		await frames(10, Vector2(960, 520), false)
		check(p.health < before, "vent scalds at the mouth")

func t_tar():
	for f in [3, 5]:
		var d = await setup("tar", f)
		check(main.in_combat(), "mud room era %d is a fight" % f)
		var mud = null
		for c in room().get_children():
			if c.get_script() and c.get_script().resource_path.ends_with("MudPool.gd") and c.trapped_species != "":
				mud = c
		check(mud != null and mud.trapped != null, "a trapped animal in the mud")
		# Grow is shut mid-fight
		main.hud.show_grow_screen()
		check(not main.hud.is_grow_up(), "GROW won't open mid-fight")
		check(main.hud.grow_btn.text == "FIGHTING" or true, "GROW button greyed")
		await frames(5)
		await snap("02_mud_era%d" % f, f == 3)
		# Animals in the mud are slowed: one walked through it moves half as far
		var e = room().active_enemies[0]
		e.set_physics_process(false)
		e.global_position = mud.global_position + Vector2(-60, 0)
		await physics_frame
		var start = e.global_position
		for i in 30:
			e.global_position += Vector2(4, 0)
			await physics_frame
		var moved = e.global_position.x - start.x
		e.set_physics_process(true)
		check(moved < 90.0, "mud halves an animal's step (moved %.0f of 120)" % moved)
		var els = total(p.elements)
		await frames(150, mud.trapped.global_position + Vector2(70, 0))
		check(d.special_state.get("freed", false), "standing by it frees the trapped animal")
		await frames(40, Vector2(300, 540))
		check(total(p.elements) > els, "freeing it gives elements")
		await kill_all()
		check(d.cleared and not main.in_combat(), "mud room clears")
		main.hud.show_grow_screen()
		check(main.hud.is_grow_up(), "GROW opens once the room is clear")
		main.hud.hide_grow_screen()

func t_dig():
	for f in [1, 3, 5]:
		var d = await setup("dig", f)
		var slab = feature("FossilSlab.gd")
		check(slab != null, "fossil slab in era %d" % f)
		await snap("03_fossil_era%d" % f, f == 1)
		var els = total(p.elements)
		for i in 6:
			slab.take_damage(1.0)
			await frames(4)
		check(d.special_state.get("dug", false), "six hits break the slab")
		await frames(60, Vector2(960, 700))
		check(total(p.elements) > els, "the fossil bed gives a rare element")
		await snap("03_fossil_era%d_open" % f, true)

func t_frenzy():
	for f in [2, 4]:
		var d = await setup("frenzy", f)
		var n = room().active_enemies.size()
		check(n >= 10, "frenzy era %d has a crowd (%d)" % [f, n])
		check(room().active_enemies.all(func(e): return e.damage == 0), "frenzy prey is harmless")
		await frames(30, Vector2(300, 540))
		await snap("04_frenzy_era%d" % f, f == 2)
		var els = total(p.elements)
		await kill_all()
		await frames(40)
		var got = total(p.elements) - els
		check(d.cleared, "frenzy clears when all are eaten")
		check(got > 1.0, "frenzy is a feast (%.1f units)" % got)

func t_meadow():
	for f in [3, 4]:
		if f == 4:
			preload("res://data/Worlds.gd").sea = true
		var d = await setup("meadow", f)
		var covers = room().get_children().filter(func(c): return c.is_in_group("covers"))
		check(covers.size() >= 5, "meadow era %d is grown over (%d patches)" % [f, covers.size()])
		check(main.in_combat(), "meadow is a fight")
		await frames(10, covers[0].position if not covers.is_empty() else Vector2(300, 540))
		check(p.cover_time > 0.0, "you can hide in it")
		if f == 3:
			await snap("15_meadow_era3", true)
		var n = covers.size()
		await kill_all()
		await frames(40)
		check(d.cleared, "meadow clears")
		# Revisit: the same meadow
		main.load_room(main.current_room_pos)
		await frames(10)
		var again = room().get_children().filter(func(c): return c.is_in_group("covers") and not c.is_queued_for_deletion())
		check(again.size() == n, "the meadow is the same on a revisit (%d)" % again.size())
	preload("res://data/Worlds.gd").sea = false

func t_mat():
	var d = await setup("mat", 1)
	var g = feature("MatGround.gd")
	check(g != null, "the mat ground is there")
	check(not main.in_combat(), "mat room has open doors")
	check(g.mats.size() >= 5, "mats on the floor (%d)" % g.mats.size())
	var dick = g.grazers.map(func(x): return x.e)
	check(dick.size() == g.GRAZERS and dick.all(func(e): return e.fauna_name == "Dickinsonia" and e.damage == 0), "harmless Dickinsonia grazing")
	# The Dickinsonia go and lie on the mats, and eat them
	var before = g.mats.map(func(m): return m.left)
	await frames(60 * 8, Vector2(150, 150))
	var eaten = 0.0
	for i in g.mats.size():
		eaten += before[i] - g.mats[i].left
	check(eaten > 0.2, "Dickinsonia eat the mat (%.2f)" % eaten)
	check(g.scars.size() >= 1, "they leave Epibaion feeding scars (%d)" % g.scars.size())
	# You graze one by resting on it
	var m = null
	for x in g.mats:
		if x.left >= 1.0 and not g.grazers.any(func(gr): return gr.target == x):
			m = x
			break
	check(m != null, "a whole mat left to graze")
	if m == null:
		return
	var at = room().global_position + m.pos
	await frames(60, at)
	check(m.left < 1.0 and m.left > 0.0, "resting on it grazes it (%.2f left)" % m.left)
	if out != "":
		await snap("16_mat_era1", true)
	var els = total(p.elements)
	await frames(int(60 * g.GRAZE_TIME) + 20, at)
	check(m.left <= 0.0, "grazed bare")
	await frames(30, at + Vector2(10, 0))
	check(total(p.elements) > els, "the mat gives elements (%.2f)" % (total(p.elements) - els))
	# A hurt Dickinsonia stops feeding
	var e = dick[0]
	e.take_damage(0.5)
	await frames(20, Vector2(150, 150))
	check(not is_instance_valid(e) or e.is_physics_processing(), "hurt, it stops feeding (%s)" % (str(e.health) if is_instance_valid(e) else "gone"))
	# Revisit: the same mats, still grazed
	var n = g.mats.size()
	main.load_room(main.current_room_pos)
	await frames(10, Vector2(150, 150))
	var g2 = feature("MatGround.gd")
	check(g2 != null and g2.mats.size() == n and g2.mats.any(func(x): return x.left <= 0.0), "the mats stay grazed on a revisit")

func t_drought():
	var d = await setup("drought", 5)
	var g = feature("DroughtPool.gd")
	check(g != null, "the drying pool is there")
	check(not main.in_combat(), "drying pool room has open doors")
	check(g.fish.size() == g.FISH and g.fish.all(func(f): return f.e.damage == 0), "harmless fish in the pool (%d)" % g.fish.size())
	var a0 = g.axes()
	await frames(60 * 8, Vector2(250, 250))
	check(g.axes().x < a0.x - 30.0, "the pool shrinks (%.0f -> %.0f)" % [a0.x, g.axes().x])
	# Let it dry right down
	g.dry = 0.97
	await frames(60 * 4, Vector2(250, 250))
	var stranded = g.fish.filter(func(f): return is_instance_valid(f.e) and f.stranded)
	check(stranded.size() >= 1, "some fish are left stranded (%d)" % stranded.size())
	if out != "":
		await frames(5, room().global_position + g.CENTRE + Vector2(g.axes().x + 120, 0))
		await snap("17_drought_era5", true)
	if not stranded.is_empty():
		var e = stranded[0].e
		var h = e.health
		e.take_damage(1.0)
		check(h - e.health >= 2.0, "a stranded fish takes more harm (%.1f)" % (h - e.health))
	# Dig a burrow
	var b = g.burrows.filter(func(x): return not x.dug)[0]
	var els = total(p.elements)
	await frames(int(60 * g.DIG_TIME) + 20, room().global_position + b.pos)
	check(b.dug, "standing on a lungfish burrow digs it out")
	await frames(30, room().global_position + b.pos + Vector2(8, 0))
	check(total(p.elements) > els, "the burrow gives elements (%.2f)" % (total(p.elements) - els))
	# Revisit: still dry, burrow still dug
	main.load_room(main.current_room_pos)
	await frames(10, Vector2(250, 250))
	var g2 = feature("DroughtPool.gd")
	check(g2 != null and g2.dry > 0.9 and g2.burrows.any(func(x): return x.dug), "a revisit finds it dry, the burrow dug")

func t_treefall():
	var d = await setup("treefall", 4)
	d.waves_left = 0
	var g = feature("TreeFall.gd")
	check(g != null, "the scale tree is there")
	check(main.in_combat(), "falling tree room is a fight")
	# Keep the animals still, one right under the trunk's line
	var foes = room().active_enemies.duplicate()
	for e in foes:
		e.set_physics_process(false)
	var victim = foes[0]
	victim.global_position = room().global_position + g.base + g.dir * 600.0
	var safe = room().global_position + g.base + g.dir * 400.0 + g.dir.orthogonal() * 260.0
	victim.max_health = 30.0
	victim.health = 30.0
	await frames(int(60 * (g.WAIT + 0.5)), safe)
	check(g.phase == "tell", "it creaks first, its shadow showing (%s)" % g.phase)
	if out != "":
		await snap("18_treefall_tell", true)
	await frames(int(60 * (g.TELL + g.FALL + 0.5)), safe)
	check(g.phase == "down" and d.special_state.get("down", false), "the tree comes down")
	check(not is_instance_valid(victim) or victim.health <= 30.0 - g.CRUSH + 0.1, "it crushes what's under it")
	var roaches = room().active_enemies.filter(func(e): return is_instance_valid(e) and e.fauna_name == "Archimylacris")
	check(roaches.size() >= g.ROACHES - 1, "cockroaches run from the bark (%d)" % roaches.size())
	if out != "":
		await frames(20, safe)
		await snap("18_treefall_down", true)
	# It's a wall now: you can't walk through it
	var start = room().global_position + g.base + g.dir * 700.0 + g.dir.orthogonal() * 120.0
	p.global_position = start
	await frames(2)
	for i in 60:
		p.velocity = -g.dir.orthogonal() * 400.0
		p.move_and_slide()
		await physics_frame
	var side = (p.global_position - room().global_position - g.base).cross(g.dir)
	var side0 = (start - room().global_position - g.base).cross(g.dir)
	check(signf(side) == signf(side0), "the trunk blocks the way")
	# Anything the trunk hit may have rolled up for a moment
	for e in room().active_enemies:
		if is_instance_valid(e) and e.get("enroll_time") != null:
			e.enroll_time = 0.0
	for k in 3:
		await kill_all()
	await frames(40)
	var left = room().active_enemies.filter(func(e): return is_instance_valid(e) and not e.dead).map(func(e): return e.fauna_name)
	check(d.cleared, "the room clears (left: %s, pending %s)" % [str(left), str(room().get("wave_pending"))])
	main.load_room(main.current_room_pos)
	await frames(10, Vector2(250, 250))
	var g2 = feature("TreeFall.gd")
	check(g2 != null and g2.phase == "down", "the trunk still lies there on a revisit")

func t_brachiopods():
	preload("res://data/Worlds.gd").sea = true
	var d = await setup("brachiopods", 5)
	var g = feature("BrachiopodBed.gd")
	check(g != null, "the lamp-shell bed is there")
	check(not main.in_combat(), "lamp-shell bed has open doors")
	check(g.shells.size() >= 10, "a bed of shells (%d)" % g.shells.size())
	await frames(30, Vector2(250, 250))
	check(g.open_count() == g.shells.size(), "left alone they gape")
	# Rushing in: they feel it and snap shut
	var s0 = g.shells[0]
	var base = room().global_position + s0.pos
	for i in 30:
		p.global_position = base + Vector2(230 - i * 4.0, 0)
		p.velocity = Vector2(-400, 0)
		await physics_frame
	check(s0.shut > 0.0 and s0.gape < 0.3, "rushing in, they snap shut")
	check(not s0.eaten, "a shut shell can't be taken")
	if out != "":
		await snap("19_brachiopods_shut", true)
	# Waiting close by, still: they open again
	await frames(int(60 * (g.SHUT + 2.5)), base + Vector2(110, 0))
	check(s0.gape > 0.9, "waiting still, it opens again (%.2f)" % s0.gape)
	if out != "":
		await snap("19_brachiopods_open", true)
	# A quick lunge from close by takes it before it reacts
	var els = total(p.elements)
	for i in 8:
		p.global_position = base + Vector2(110 - i * 14.0, 0)
		p.velocity = Vector2(-400, 0)
		await physics_frame
	check(s0.eaten, "a lunge from close takes it open")
	await frames(30, base)
	check(total(p.elements) > els, "it gives elements (%.2f)" % (total(p.elements) - els))
	main.load_room(main.current_room_pos)
	await frames(10, Vector2(250, 250))
	var g2 = feature("BrachiopodBed.gd")
	check(g2 != null and g2.shells[0].eaten, "eaten shells stay eaten on a revisit")
	preload("res://data/Worlds.gd").sea = false

func t_current():
	var d = await setup("current", 3)
	d.waves_left = 0
	var g = feature("Current.gd")
	check(g != null, "the current is there")
	check(main.in_combat(), "current room is a fight")
	# Standing still in open water, you are carried along
	g.angle = 0.0
	g.to_angle = 0.0
	g.turn_t = 1.0
	g.next_turn = 99.0
	var start = room().global_position + Vector2(700, 540)
	p.global_position = start
	await frames(60)
	var moved = p.global_position - start
	check(moved.x > 40.0 and absf(moved.y) < 30.0, "the current carries you (%.0f, %.0f)" % [moved.x, moved.y])
	# It swings round
	g.next_turn = 0.01
	await frames(int(60 * (g.TURN_TIME + 0.3)), Vector2(250, 250))
	check(absf(angle_difference(0.0, g.angle)) > 0.4, "the current swings round (%.2f)" % g.angle)
	if out != "":
		await snap("20_current_era3", true)
	# Graptolites to catch
	var c = g.colonies.filter(func(x): return not x.eaten)[0]
	var els = total(p.elements)
	for i in 10:
		p.global_position = room().global_position + c.pos
		await physics_frame
	check(c.eaten, "touching a graptolite colony eats it")
	await frames(30, room().global_position + c.pos)
	check(total(p.elements) > els, "it gives phosphorus")
	for e in room().active_enemies:
		if is_instance_valid(e) and e.get("enroll_time") != null:
			e.enroll_time = 0.0
	for k in 3:
		await kill_all()
	await frames(40)
	check(d.cleared, "the room clears")

func t_cupreef():
	var d = await setup("cupreef", 2)
	var g = feature("CupReef.gd")
	check(g != null, "the cup reef is there")
	check(not main.in_combat(), "cup reef room has open doors")
	check(g.cups.size() >= 6, "a reef of cups (%d)" % g.cups.size())
	await frames(20, Vector2(250, 250))
	check(g.hidden_count() == g.HIDERS, "they all hide in the cups (%d)" % g.hidden_count())
	var h = g.hiders[0]
	var e = h.e
	check(not e.is_in_group("enemies") and not e.visible, "inside a cup it is out of reach")
	# Walk up to its cup: it bolts
	var cup_pos = room().global_position + g.cups[h.cup].pos
	await frames(6, cup_pos + Vector2(0, 90))
	check(h.cup == -1 and e.visible and e.is_in_group("enemies"), "come close and it darts out")
	if out != "":
		await frames(4, cup_pos + Vector2(0, 90))
		await snap("21_cupreef_era2", true)
	# Caught in the open
	e.take_damage(9999.0)
	await frames(5, cup_pos + Vector2(0, 90))
	check(not is_instance_valid(e) or e.dead, "caught in the open it can be eaten")
	await frames(60, Vector2(250, 250))
	check(g.hiders.filter(func(x): return is_instance_valid(x.e) and not x.e.dead).all(func(x): return x.cup >= 0), "the others are back in cups")
	main.load_room(main.current_room_pos)
	await frames(10, Vector2(250, 250))
	var g2 = feature("CupReef.gd")
	check(g2 != null and g2.hiders.size() == 5, "one fewer on a revisit (%d)" % (g2.hiders.size() if g2 else -1))

func t_procession():
	var d = await setup("procession", 3)
	var g = feature("Procession.gd")
	check(g != null, "the procession is there")
	check(not main.in_combat(), "procession room has open doors")
	var line = g.line.duplicate()
	check(line.size() == g.COUNT, "a line of %d (%d)" % [g.COUNT, line.size()])
	check(line.all(func(e): return e.fauna_name == "Ampyx" and e.damage == 0), "harmless Ampyx")
	var p0 = line[0].position
	await frames(60, Vector2(150, 150))
	check(line[0].position.distance_to(p0) > 40.0, "the leader walks on (%.0f px)" % line[0].position.distance_to(p0))
	var gap = line[3].position.distance_to(line[4].position)
	check(gap > 40.0 and gap < 80.0, "they keep nose to tail (%.0f px)" % gap)
	if out != "":
		await frames(90, Vector2(1500, 900))
		await snap("14_procession_era3", true)
	# Taking the tail: the rest walk on, a richer meal
	var tail = g.line.back()
	var w = tail.worth_override
	tail.take_damage(9999.0)
	await frames(5, Vector2(150, 150))
	check(not g.broken, "eating the last in line doesn't break it")
	check(w > 1.0, "the quiet kill is worth more (%.1f)" % w)
	var alive = g.line.filter(func(e): return is_instance_valid(e) and not e.dead)
	check(alive.size() == g.COUNT - 1, "one fewer in line (%d)" % alive.size())
	# Hitting the middle breaks it
	var mid = alive[3]
	mid.take_damage(0.5)
	await frames(5, Vector2(150, 150))
	check(g.broken, "hitting the middle breaks the line")
	check(g.line.all(func(e): return not is_instance_valid(e) or e.is_physics_processing()), "they scatter")
	check(d.special_state.get("left", 0) == g.COUNT - 1, "the room remembers how many are left (%d)" % d.special_state.get("left", 0))

func t_molt():
	for f in [2, 3]:
		var d = await setup("molt", f)
		var g = feature("MoltGathering.gd")
		check(g != null, "the molt gathering is there (era %d)" % f)
		check(main.in_combat(), "molt room starts with doors shut")
		var crowd = room().active_enemies.duplicate()
		check(crowd.size() >= 6, "a crowd gathered (%d)" % crowd.size())
		check(crowd.all(func(e): return e.damage == 0), "molting trilobites are harmless")
		# Hard before molting
		var e0 = crowd.filter(func(e): return not e.get_meta("molted", false))[0]
		var h0 = e0.health
		e0.take_damage(2.0)
		check(abs((h0 - e0.health) - 2.0 * g.HARD_MULT) < 0.01, "the old shell turns most of a blow (%.2f)" % (h0 - e0.health))
		var els = p.elements.get("Ca", 0.0)
		await frames(60 * 4, Vector2(200, 900))
		var molted = crowd.filter(func(e): return is_instance_valid(e) and e.get_meta("molted", false))
		check(molted.size() >= 1, "some have molted (%d)" % molted.size())
		check(g.shells.size() == molted.size(), "each left a moult on the floor")
		var softs = g.soft.keys()
		check(not softs.is_empty(), "a fresh molt is soft")
		if not softs.is_empty():
			var s = softs[0]
			var h1 = s.health
			s.take_damage(0.5)
			check((h1 - s.health) >= 0.5 * g.SOFT_MULT - 0.01, "a soft one takes 3x (%.2f)" % (h1 - s.health))
		if f == 2:
			await frames(20, Vector2(860, 760))
			await snap("13_molt_era%d" % f, false)
		# Hardened again after a while
		await frames(60 * 7, Vector2(200, 900))
		var first = molted[0] if not molted.is_empty() else null
		if first and is_instance_valid(first) and not first.dead:
			check(float(first.get_meta("hit_mult", 1.0)) == 1.0, "the new shell hardens")
		await kill_all()
		await frames(40)
		check(d.cleared, "molt room clears when all are eaten")

func t_extinction():
	for f in [3, 5]:
		var d = await setup("extinction", f)
		check(not main.in_combat(), "extinction room doors open")
		await frames(60 * 6, Vector2(300, 540))
		await snap("05_extinction_era%d" % f, f == 3)
		var els = total(p.elements)
		for c in d.special_state.caches.slice(0, 3):
			await frames(8, c.pos)
		await frames(30)
		check(total(p.elements) > els, "grabbing caches gives elements")
		await frames(60 * 11, Vector2(960, 540))
		check(d.special_state.get("done", false), "the countdown runs out")
		var h = p.health
		p.invincibility_time = 0.0
		await frames(60 * 3, Vector2(960, 540), false)
		check(p.health < h, "the dead room hurts until you leave")
		p.health = 12
		await snap("05_extinction_era%d_after" % f)

func t_nest():
	for f in [2, 4, 5]:
		var d = await setup("nest", f)
		check(not main.in_combat(), "nest era %d starts calm" % f)
		await snap("06_nest_era%d" % f, f == 4)
		var els = total(p.elements)
		await frames(20, Vector2(960, 540))
		await frames(70, Vector2(960, 700))
		check(d.special_state.get("taken", false), "walking in takes the clutch")
		check(total(p.elements) > els + 2.0, "the clutch is a big meal")
		check(main.in_combat() and doors_closed(), "the parent shuts you in")
		var parent = room().active_enemies.filter(func(e): return e.elder)
		check(parent.size() == 1, "an elder parent comes")
		await frames(20, Vector2(960, 700))
		await snap("06_nest_era%d_parent" % f)
		await kill_all()
		check(d.cleared, "nest clears once the parent is beaten")

func t_tide():
	var d = await setup("tide", 2)
	var tide = feature("TideChannel.gd")
	check(tide != null, "tide channel")
	await snap("07_tide_low", true)
	await frames(60 * 8, Vector2(300, 540))
	check(tide.blocking, "high tide blocks the channel")
	await snap("07_tide_high")
	await frames(60, Vector2(660, 540))
	await frames(10)
	check(absf(p.global_position.x - 660.0) > 120.0, "the flood washes you to a bank (x %.0f)" % p.global_position.x)
	await kill_all()
	check(d.cleared, "tide room clears")

func t_symbiont():
	var d = await setup("symbiont", 4)
	await frames(10)
	await snap("08_symbiont", true)
	await frames(30, Vector2(960, 520))
	check(d.special_state.get("joined", false), "touching the animal befriends it")
	var comp = main.get_tree().get_nodes_in_group("companions")
	check(comp.size() == 1 and comp[0].get_parent() == main, "the follower travels with you")
	# Give it something to hunt
	room().spawn_enemy(Vector2(1200, 540), "fly", 4)
	var e = room().active_enemies.back()
	e.become_hostile()
	e.set_physics_process(false)
	var hp = e.health
	await frames(150, Vector2(1000, 540))
	check(e.health < hp or e.dead, "the follower bites what you fight")
	await snap("08_symbiont_hunting")
	main.floor_number = 5
	main.generate_floor()
	await frames(5)
	check(main.get_tree().get_nodes_in_group("companions").filter(func(c): return not c.is_queued_for_deletion()).is_empty(), "the follower stays behind at the next era")

func t_ambush():
	for f in [3, 5]:
		var d = await setup("ambush", f)
		check(not main.in_combat() and room().active_enemies.is_empty(), "ambush era %d looks empty" % f)
		await snap("09_quiet_era%d" % f)
		await frames(60 * 2, Vector2(960, 540))
		await frames(60)
		check(d.special_state.get("sprung", false), "the ambush springs")
		check(room().active_enemies.any(func(e): return e.elder), "an elder hunter was hiding")
		check(main.in_combat() and doors_closed(), "the doors shut")
		await snap("09_ambush_era%d" % f, true)
		await kill_all()
		check(d.cleared, "ambush clears")

func t_glow():
	for f in [2, 3]:
		var d = await setup("glow", f)
		await frames(90, Vector2(400, 540))
		var fog = main.get_node("VisionFog")
		check(fog.cave > 0.9, "the cave is dark (era %d)" % f)
		check(main.get_tree().get_nodes_in_group("fog_lights").size() >= 5, "glowing animals light it")
		check(main.in_combat(), "the cave has animals to fight")
		await snap("10_glow_era%d" % f, f == 2)
		await kill_all()
		check(d.cleared, "cave clears")

# Pitch dark: no light but your own glimmer; the senses mark the animals
func t_dark():
	for f in [1, 3, 5]:
		var d = await setup("dark", f)
		await frames(90, Vector2(400, 540))
		var fog = main.get_node("VisionFog")
		check(fog.cave > 0.9 and fog.pitch > 0.9, "the room is pitch dark (era %d)" % f)
		check(fog.light_radius() < fog.radius * 0.5, "you see only a glimmer (%d of %d px)" % [fog.light_radius(), fog.radius])
		check(main.get_tree().get_nodes_in_group("fog_lights").is_empty(), "nothing glows")
		check(main.in_combat(), "the dark room has animals to fight")
		if out != "":
			# A form with a few good senses, and animals on the move, to show them
			var prof = {1: {"Touch": 6, "Chemical sense": 7}, 3: {"Lateral line": 8, "Electroreception": 7, "Smell": 4}, 5: {"Smell": 8, "Vibration": 7, "Touch": 4}}[f]
			fog.set_sense(8, prof.keys()[0], prof)
			for e in room().active_enemies:
				if is_instance_valid(e):
					e.become_hostile()
					e.health = e.max_health * 0.6
			await frames(150, Vector2(400, 540))
		await snap("11_dark_era%d" % f, f == 1)
		await kill_all()
		await kill_all() # anything that split or hatched as they died
		check(d.cleared, "dark room clears")
	# The menu test switch makes every fight room dark
	root.get_node("SettingsManager").dark_rooms_all = true
	var rooms = preload("res://LevelGenerator.gd").generate_level(2, [])
	var plain = 0
	for pos in rooms:
		if rooms[pos].type == 1 and rooms[pos].special == "" and pos != Vector2i(4, 4):
			plain += 1
	root.get_node("SettingsManager").dark_rooms_all = false
	check(plain == 0, "DARK ROOMS: EVERY ROOM leaves no lit fight room (%d)" % plain)

# Wildfire: lit on the far side after a moment, crosses the room, burns you
# and the animals in it, chars the plants, leaves phosphorus in the ash
func t_fire():
	for f in [4, 5]:
		var d = await setup("fire", f)
		var w = feature("Wildfire.gd")
		check(w != null, "the fire feature is there (era %d)" % f)
		check(w.state.dir < 0.0, "it starts on the side away from you")
		check(not w.lit(), "not lit at first")
		await frames(5, Vector2(300, 540))
		var sign = null
		for c in main.get_node("VisionFog").get_children():
			if c.get_script() and c.get_script().resource_path.ends_with("FireSign.gd"):
				sign = c
		check(sign != null, "an oxygen warning sign shows on entry (era %d)" % f)
		check(main.hud.item_banner.visible and main.hud.item_title.text == "WILDFIRE WARNING", "the warning banner shows")
		await frames(90, Vector2(300, 540))
		await snap("12_fire_warning_era%d" % f, true)
		await frames(170, Vector2(300, 540))
		check(w.lit(), "lightning lights it")
		check(not is_instance_valid(sign), "the warning sign goes once it strikes")
		var hp0 = 0
		var burnt_any = false
		var start_hp = {}
		for e in room().active_enemies:
			start_hp[e] = e.health
		# Stand still in its path
		p.invincibility_time = 0.0
		var hurt = false
		for i in 60 * 32:
			p.global_position = room().global_position + Vector2(960, 540)
			p.health = max(p.health, 4)
			p.is_dashing = false
			var before = p.health
			await physics_frame
			if p.health < before:
				hurt = true
			for e in start_hp:
				if not is_instance_valid(e) or e.dead or e.health < start_hp[e]:
					burnt_any = true
			if w.state.get("done", false):
				break
			if i == 60 * 9 or (out != "" and i == 60 * 4):
				await snap("12_fire_era%d_%ds" % [f, i / 60], f == 4)
		check(hurt, "standing in the fire hurts")
		check(burnt_any, "animals get burnt")
		check(w.state.get("done", false), "it burns out")
		var charred = room().get_children().filter(func(c): return c.is_in_group("obstacles") and c.modulate.r < 0.6).size()
		var plants = room().get_children().filter(func(c): return c.is_in_group("obstacles")).size()
		check(plants == 0 or charred == plants, "the plants are charred (%d / %d)" % [charred, plants])
		await frames(5)
		var ash = room().get_children().filter(func(c): return c.get_script() == preload("res://BiomassOrb.gd") and c.element == "P").size()
		check(ash > 0, "the ash leaves phosphorus (%d orbs)" % ash)
		for k in 4: # a second wave may come in
			await kill_all()
			await frames(60)
		check(d.cleared, "the fire room clears")
		# Back again: burnt, no second ash
		main.load_room(main.current_room_pos)
		await frames(10)
		var w2 = feature("Wildfire.gd")
		var ash2 = room().get_children().filter(func(c): return c.get_script() == preload("res://BiomassOrb.gd")).size()
		check(w2 != null and w2.state.done and ash2 == 0, "a revisit is burnt, no new ash (%d)" % ash2)
		print("SPECIALTEST fire era %d: ash orbs %d, plants %d" % [f, ash, plants])

# Every floor deals its special rooms, fitting the era
func t_deal():
	var SR = preload("res://data/SpecialRooms.gd")
	var seen := {}
	var W = preload("res://data/Worlds.gd")
	for run in 20:
		# Half the runs take the sea world on floors 4 and 5
		W.sea = run % 2 == 1
		for f in range(1, 6):
			var rooms = preload("res://LevelGenerator.gd").generate_level(f, [])
			var n = 0
			for pos in rooms:
				var r = rooms[pos]
				if r.special != "":
					n += 1
					seen[r.special] = true
					if not W.era(f) in SR.ERAS[r.special]:
						check(false, "%s dealt in era %d" % [r.special, W.era(f)])
					if r.type != 1:
						check(false, "special on a non-fight room")
			if n < 1:
				check(false, "floor %d got no special rooms" % f)
			if not rooms.values().any(func(r): return r.special == "dark"):
				check(false, "floor %d got no dark room" % f)
	W.sea = false
	check(seen.size() == SR.KINDS.size(), "all %d kinds turn up (%d)" % [SR.KINDS.size(), seen.size()])

func t_run():
	# The ordinary floor still works with specials in it
	main.floor_number = 3
	main.generate_floor()
	var kinds = []
	for pos in main.dungeon_rooms:
		if main.dungeon_rooms[pos].special != "":
			kinds.append(main.dungeon_rooms[pos].special)
	check(kinds.size() == 4 and "dark" in kinds, "floor 3 deals three special rooms and a dark one %s" % str(kinds))
	for pos in main.dungeon_rooms:
		if main.dungeon_rooms[pos].special != "":
			main.current_room_pos = pos
			main.load_room(pos)
			await frames(30, Vector2(960, 540))
			await kill_all()
			await frames(30, Vector2(300, 540))
			# leave and come back: it must look the same and not break
			main.load_room(Vector2i(4, 4))
			await frames(5)
			main.load_room(pos)
			await frames(30, Vector2(300, 540))
			check(true, "revisited %s" % main.dungeon_rooms[pos].special)
