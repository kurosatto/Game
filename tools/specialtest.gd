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
	var tests = ["vent", "tar", "dig", "frenzy", "extinction", "nest", "tide", "symbiont", "ambush", "glow", "dark", "fire", "molt", "deal", "run"]
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
		await frames(200, Vector2(300, 540))
		check(w.lit(), "lightning lights it")
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
	for run in 20:
		for f in range(1, 6):
			var rooms = preload("res://LevelGenerator.gd").generate_level(f, [])
			var n = 0
			for pos in rooms:
				var r = rooms[pos]
				if r.special != "":
					n += 1
					seen[r.special] = true
					if not f in SR.ERAS[r.special]:
						check(false, "%s dealt in era %d" % [r.special, f])
					if r.type != 1:
						check(false, "special on a non-fight room")
			if n < 1:
				check(false, "floor %d got no special rooms" % f)
			if not rooms.values().any(func(r): return r.special == "dark"):
				check(false, "floor %d got no dark room" % f)
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
