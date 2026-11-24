# gauntlettest.gd
# Checks the FOSSIL GAUNTLET boss rush and DEEP TIME (data/Endgame.gd):
#  - each gauntlet floor is a start room and a boss room, and heals you
#  - beating the Permian boss in the gauntlet leaves only the way on into
#    the Great Dying, whose last boss ends the rush
#  - DEEP TIME raises animal and boss health and adds an animal per room
#   ENDGAME=1 godot --headless --path . -s res://tools/gauntlettest.gd
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
const Endgame = preload("res://data/Endgame.gd")
const Difficulty = preload("res://data/Difficulty.gd")
var fails := 0

func check(ok: bool, what: String):
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize():
	run()

func run():
	# DEEP TIME numbers, off then forced on through the cache
	var base_hp = Difficulty.enemy_health_mult(3)
	var base_boss = Difficulty.boss_health_mult(3)
	var base_extra = Difficulty.room_extra_animals(3)
	Endgame._deep_cache = 1
	check(is_equal_approx(Difficulty.enemy_health_mult(3), base_hp * Endgame.DEEP_ENEMY_HEALTH), "deep time: animal health")
	check(is_equal_approx(Difficulty.boss_health_mult(3), base_boss * Endgame.DEEP_BOSS_HEALTH), "deep time: boss health")
	check(Difficulty.room_extra_animals(3) == base_extra + 1, "deep time: one more animal")
	check(Difficulty.boss_clock("stalk") > Difficulty.BOSS_REST_SPEED, "deep time: bosses rest less")
	Endgame._deep_cache = 0
	check(is_equal_approx(Difficulty.enemy_health_mult(3), base_hp), "deep time off: back to normal")

	Endgame.mode = "gauntlet"
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	check(main.dungeon_rooms.size() == 2, "gauntlet floor 1 is two rooms (%d)" % main.dungeon_rooms.size())
	var types = main.dungeon_rooms.values().map(func(r): return r.type)
	check(0 in types and 3 in types, "a start room and a boss room")
	check(main.hud.floor_label.text.begins_with("GAUNTLET"), "HUD says GAUNTLET")
	main.player.health = 1
	main.floor_number = 3
	main.generate_floor()
	for i in 5: await process_frame
	check(main.player.health == main.player.max_health, "healed for the next boss")
	main.player.max_health = 999
	main.player.health = 999
	Worlds.sea = false
	main.floor_number = 5
	main.generate_floor()
	for i in 5: await process_frame
	main.on_boss_defeated(5)
	for i in 5: await process_frame
	var room = main.current_room_node
	var prize = room.get_children().filter(func(n): return "item_id" in n and n.item_id != "")
	check(prize.size() == 1, "the boss leaves an item")
	check(room.get_node_or_null("TrapdoorFinale") != null and room.get_node_or_null("TrapdoorEnd") == null, "only the way on into the Great Dying")
	main.advance_floor("finale")
	for i in 150: await process_frame
	check(Worlds.finale and main.dungeon_rooms.size() == 2, "the Great Dying is a boss room too")
	var boss_pos = null
	for pos in main.dungeon_rooms:
		if main.dungeon_rooms[pos].type == 3:
			boss_pos = pos
	main.current_room_pos = boss_pos
	main.load_room(boss_pos)
	for i in 10: await process_frame
	var boss = null
	for e in get_nodes_in_group("enemies"):
		if e.has_method("is_boss") and e.is_boss():
			boss = e
	check(boss != null and boss.killer_name() == "Inostrancevia", "last boss of the rush")
	if boss:
		boss.take_damage(99999.0)
	for i in 90: await process_frame
	check(main.hud.victory_screen.visible, "beating it ends the rush")
	Endgame.mode = ""
	print("GAUNTLETTEST %s (%d failures)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
