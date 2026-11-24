# lairtest.gd
# Checks the SECRET LAIRS (data/Endgame.gd): with them open, floor 4 of each
# world hides its giant in one dead-end fight room, the room fights like a
# boss room, and clearing it leaves an item. Also runs each lair boss's
# moves. ENDGAME=1 godot --headless --path . -s res://tools/lairtest.gd
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
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	main.player.max_health = 999
	for sea in [false, true]:
		var w = "sea" if sea else "land"
		main.floor_number = 3
		main.generate_floor()
		var none = main.dungeon_rooms.values().filter(func(r): return r.lair != "").size()
		check(none == 0, w + ": no lair on floor 3")
		main.floor_number = 4
		Worlds.sea = sea
		main.generate_floor()
		for i in 5: await process_frame
		var lairs = main.dungeon_rooms.values().filter(func(r): return r.lair != "")
		check(lairs.size() == 1, w + ": one lair on floor 4")
		if lairs.is_empty():
			continue
		var r = lairs[0]
		var items_before = main.player.items_found.size()
		check(r.lair == ("saivodus" if sea else "megarachne"), w + ": the world's giant (" + r.lair + ")")
		main.current_room_pos = r.grid_pos
		main.load_room(r.grid_pos)
		for i in 10: await process_frame
		var boss = null
		for e in get_nodes_in_group("enemies"):
			if e.has_method("is_boss") and e.is_boss():
				boss = e
			elif is_instance_valid(e):
				check(false, w + ": an ordinary animal in the lair")
		check(boss != null, w + ": the giant is there")
		if boss == null:
			continue
		var moves = {"Megarachne": ["rake_wind", "silt_wind", "tail_wind", "lurch_wind"], "Saivodus": ["bite_wind", "circle", "tail_wind"]}[boss.killer_name()]
		for f in 300:
			await physics_frame
			main.player.health = 999
			if f == 150:
				boss.take_damage(boss.max_health * 0.55)
		if boss.killer_name() == "Megarachne":
			check(not boss.disguised and boss.boss_title.contains("NOT A SPIDER"), "megarachne: the spider falls away at half health")
		for st in moves:
			boss.set_state(st)
			for f in 90:
				await physics_frame
				main.player.health = 999
		boss.take_damage(99999.0)
		for i in 60: await process_frame
		check(r.cleared, w + ": the lair is cleared")
		# (the player may already be standing on it and have picked it up)
		var peds = main.current_room_node.get_children().filter(func(n): return "item_id" in n)
		check(peds.size() == 1 or main.player.items_found.size() > items_before, w + ": an item left behind")
		check(not main.hud.victory_screen.visible and main.floor_number == 4, w + ": the run goes on")
	print("LAIRTEST %s (%d failures)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
