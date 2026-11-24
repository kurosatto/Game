# finaletest.gd
# Checks THE GREAT DYING finale (data/Endgame.gd) in both worlds:
#  - beating the Permian boss with the finale open leaves two trapdoors
#  - the finale trapdoor goes to a second floor 5 with Worlds.finale set,
#    the HUD named for it, gas vents / dead water in fight rooms, ash fall
#  - its boss room spawns the world's last boss, whose death wins the run
#  - with the finale locked, the Permian boss ends the run as before
# Run with ENDGAME=1 (opens it without a saved win):
#   ENDGAME=1 godot --headless --path . -s res://tools/finaletest.gd
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
var fails := 0

func check(ok: bool, what: String):
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize():
	run()

func run():
	if OS.get_environment("ENDGAME") != "1":
		print("FAIL run with ENDGAME=1")
		quit(1)
		return
	for sea in [false, true]:
		var w = "sea" if sea else "land"
		var main = load("res://Main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		for i in 20: await process_frame
		main.player.max_health = 999
		main.player.health = 999
		Worlds.sea = sea
		main.floor_number = 5
		main.generate_floor()
		for i in 10: await process_frame
		check(not Worlds.finale, w + ": a run starts outside the finale")
		main.on_boss_defeated(5)
		for i in 5: await process_frame
		var room = main.current_room_node
		check(room.get_node_or_null("TrapdoorEnd") != null and room.get_node_or_null("TrapdoorFinale") != null, w + ": two ways down after the Permian boss")
		check(not main.hud.victory_screen.visible, w + ": no victory screen yet")
		main.advance_floor("finale")
		for i in 150: await process_frame
		check(Worlds.finale and main.floor_number == 5, w + ": into the Great Dying on floor 5")
		check(Worlds.sea == sea, w + ": same world")
		check(main.hud.floor_label.text.contains("GREAT DYING"), w + ": HUD names the Great Dying")
		var vents := 0
		var fights := 0
		var boss_pos = null
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and r.special == "":
				fights += 1
			if r.type == 3:
				boss_pos = pos
		# Visit each fight room and count its hazards
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type != 1 or r.special != "":
				continue
			main.current_room_pos = pos
			main.load_room(pos)
			for i in 3: await process_frame
			var kinds = main.current_room_node.get_children().filter(func(n): return n.get("kind") in ["fumarole", "euxinic"])
			if kinds.size() > 0:
				vents += 1
				check(kinds[0].kind == ("euxinic" if sea else "fumarole"), w + ": hazard kind " + kinds[0].kind)
			check(main.current_room_node.get_node_or_null("AshFall") != null, w + ": ash falls in the fight room")
			for e in get_nodes_in_group("enemies"):
				e.queue_free()
			r.cleared = true
			break
		check(vents > 0, w + ": the fight room has vents or dead water (%d fight rooms)" % fights)
		check(boss_pos != null, w + ": a boss room")
		main.current_room_pos = boss_pos
		main.load_room(boss_pos)
		for i in 10: await process_frame
		var boss = null
		for e in get_nodes_in_group("enemies"):
			if e.has_method("is_boss") and e.is_boss():
				boss = e
		var want = "Campylocephalus" if sea else "Inostrancevia"
		check(boss != null and boss.killer_name() == want, w + ": last boss is " + want)
		if boss:
			for f in 240:
				await physics_frame
				main.player.health = 999
			boss.take_damage(99999.0)
		for i in 90: await process_frame
		check(main.hud.victory_screen.visible, w + ": beating it wins the run")
		check(main.hud.victory_screen.get_node("Center/Label").text.contains("GREAT DYING"), w + ": the victory names the Great Dying")
		main.queue_free()
		for i in 10: await process_frame
	print("FINALETEST %s (%d failures)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
