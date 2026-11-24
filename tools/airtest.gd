# airtest.gd
# Checks the oxygen-rich Carboniferous air (Main.apply_air): arthropod forms
# get an extra heart on the land floor of era 4, lose it again in the
# Permian, and other forms and the sea world get nothing.
#   godot --headless --path . -s res://tools/airtest.gd
extends SceneTree
var fails := 0
func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)
func form(id: String) -> Dictionary:
	var L = load("res://data/Lineages.gd")
	for p in L.TREE:
		if L.TREE[p].id == id:
			return L.TREE[p]
	return {}
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var W = load("res://data/Worlds.gd")
	var p = main.player
	p.apply_form(form("scorpion"))
	W.sea = false
	main.floor_number = 3
	main.apply_air()
	var base = p.max_health
	check(p.air_bonus == 0, "no bonus in the Ordovician sea")
	main.floor_number = 4
	main.apply_air()
	check(p.max_health == base + 2, "a scorpion gets +1 heart in the coal swamp (%d -> %d)" % [base, p.max_health])
	main.apply_air()
	check(p.max_health == base + 2, "it doesn't stack")
	main.floor_number = 5
	main.apply_air()
	check(p.max_health == base and p.air_bonus == 0, "it goes again in the Permian (%d)" % p.max_health)
	check(p.health >= 1 and p.health <= p.max_health, "health stays in range")
	p.apply_form(form("synapsid"))
	main.floor_number = 4
	base = p.max_health
	main.apply_air()
	check(p.max_health == base, "a synapsid gets nothing")
	p.apply_form(form("horseshoe_crab"))
	W.sea = true
	base = p.max_health
	main.apply_air()
	check(p.max_health == base, "nothing in the sea world (era %d)" % W.era(4))
	W.sea = false
	print("AIR done, %d failures" % fails)
	quit()
