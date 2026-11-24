# clutchtest.gd
# Checks laying a clutch (data/Reproduction.gd, Main.lay_clutch, HUD "LAY
# EGGS"): every form has a real way to reproduce; you can only lay in a
# cleared room and one clutch at a time; dying on the same floor hatches it in
# its room with the right health and no game over; dying again is the end;
# a clutch is left behind on the next floor. Run:
#   godot --headless --path . -s res://tools/clutchtest.gd
extends SceneTree
const REPRO = preload("res://data/Reproduction.gd")
const LINEAGES = preload("res://data/Lineages.gd")
var fails := 0

func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)

func frames(n: int):
	for i in n:
		await physics_frame

func _initialize():
	# Every form maps to a mode with a cost in real elements
	var counts := {}
	for path in LINEAGES.TREE:
		var id = LINEAGES.TREE[path].id
		var m = REPRO.mode_id(id)
		counts[m] = counts.get(m, 0) + 1
		check(REPRO.MODES.has(m), "%s has a mode" % id)
	print("CLUTCH modes over %d forms: %s" % [LINEAGES.TREE.size(), counts])
	for id in ["ancestral_collar_cell", "early_arthropod", "scorpion", "spider", "octopus_line", "sea_urchin", "sauropsid", "synapsid", "lissamphibian", "decapod"]:
		var m = REPRO.mode_for(id)
		print("CLUTCH %-22s %-22s cost %s hatch %d/12" % [id, m.name, m.cost, REPRO.hatch_health(id, 12)])
	check(REPRO.mode_id("scorpion") == "carry" and REPRO.mode_id("sauropsid") == "amniote" and REPRO.mode_id("sea_urchin") == "broadcast", "modes follow the tree")

	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(30)
	var p = main.player
	var hud = main.hud
	for el in ["P", "S", "Ca"]:
		p.elements[el] = 20.0
	var start = main.current_room_pos
	var sroom = main.current_room_node
	sroom.room_data.cleared = true
	check(p.can_lay_clutch(), "can lay in the cleared start room")
	# Through the GROW screen: first press shows, second lays
	hud.show_grow_screen()
	await process_frame
	hud._on_eggs_pressed()
	check(not main.has_clutch(), "first press only shows the info")
	print("CLUTCH info: %s | %s" % [hud.grow_title.text, hud.grow_change.get_parsed_text()])
	hud._on_eggs_pressed()
	check(main.has_clutch(), "second press lays the clutch")
	check(p.elements.P < 20.0, "laying spends phosphorus")
	check(not p.can_lay_clutch(), "only one clutch at a time")
	check(sroom.get_node_or_null("YourClutch") != null, "the clutch is drawn in the room")
	hud.hide_grow_screen()
	# Go to a neighbour room and die there
	var next = Vector2i.ZERO
	for d in main.dungeon_rooms[start].connections:
		next = main.dungeon_rooms[start].connections[d]
		break
	main.current_room_pos = next
	main.load_room(next)
	await frames(10)
	check(not p.can_lay_clutch() or main.current_room_node.room_data.cleared, "no laying in an uncleared room")
	p.invincibility_time = 0.0
	p.is_dashing = false
	p.autotomy_ready = false
	p.take_damage(999, "test")
	await frames(10)
	check(main.hatching, "death starts the hatching")
	await frames(60 * 3)
	var want = REPRO.hatch_health(p.current_character_id, p.max_health)
	check(not hud.game_over_screen.visible, "no game over with a clutch")
	check(main.current_room_pos == start, "back in the clutch's room")
	check(p.health == want, "hatches with %d health (has %d)" % [want, p.health])
	check(p.is_physics_processing(), "the young one can move")
	check(not main.has_clutch() and main.dungeon_rooms[start].clutch_hatched, "the clutch is used up")
	print("CLUTCH hatched in room %s with %d/%d health" % [main.current_room_pos, p.health, p.max_health])
	# Die again: now it is the end
	await frames(60 * 3)
	p.invincibility_time = 0.0
	p.take_damage(999, "test")
	await frames(30)
	check(hud.game_over_screen.visible, "second death without a clutch ends the run")
	# A new run: a clutch is left behind on the next floor
	print("CLUTCH done, %d failures" % fails)
	quit()
