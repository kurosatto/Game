# molttest.gd
# Checks molting (Player.molt, rooms/Exuvia.gd): an arthropod molts once at
# the start of each era (Player.molt_into_era), leaving its old skin in the room, healing half a heart if hurt; the skin survives
# leaving and coming back, gives calcium once when touched after stepping
# away; a non-arthropod never molts. Screenshots with SHOT_DIR (xvfb).
#   godot --headless --path . -s res://tools/molttest.gd
extends SceneTree
var fails := 0
var out := OS.get_environment("SHOT_DIR")
func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)
func snap(n: String):
	if out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)
func form(p, id: String):
	for path in preload("res://data/Lineages.gd").TREE:
		var fd: Dictionary = preload("res://data/Lineages.gd").TREE[path]
		if fd.get("id", "") == id:
			p.apply_form(fd)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var p = main.player
	var hud = main.hud
	var room = main.current_room_node
	room.room_data.cleared = true
	main.get_node("VisionFog").set_vision(10, true)
	# Not an arthropod: no molt
	form(p, "pikaia_chordate")
	p.elements = {"Ca": 30.0, "P": 30.0, "Fe": 30.0, "Zn": 30.0, "Cu": 30.0, "S": 30.0}
	p.grant_adaptation("keratin_claws")
	p.molt_into_era()
	for i in 10: await physics_frame
	check(room.room_data.exuviae.is_empty(), "a chordate does not molt")
	check(not p.is_arthropod() and preload("res://data/Reproduction.gd").ancestry("scorpion").has("early_arthropod"), "who is an arthropod")
	# An arthropod grows two parts in one visit: one molt
	form(p, "scorpion")
	p.global_position = Vector2(900, 560)
	p.health = p.max_health - 2
	var hp = p.health
	p.grant_adaptation("calcite_spines")
	p.molt_into_era()
	for i in 40: await physics_frame
	check(room.room_data.exuviae.size() == 1, "one molt for a new era (%d)" % room.room_data.exuviae.size())
	check(p.health == hp + 1, "molting regrows half a heart")
	var e = room.room_data.exuviae[0] if not room.room_data.exuviae.is_empty() else {}
	check(not e.is_empty() and e.parts.has("calcite_spines"), "the old skin keeps the parts it had")
	await snap("1_molted")
	for i in 5:
		p.global_position = Vector2(1250, 560)
		await physics_frame
	await snap("2_skin_left_behind")
	# Standing on it right after: not eaten
	check(not e.eaten, "not eaten while still standing on it")
	# Step away, come back: eaten, +1 Ca
	var ca = p.elements.Ca
	for i in 20:
		p.global_position = Vector2(1300, 560)
		await physics_frame
	for i in 20:
		p.global_position = room.to_global(e.pos)
		await physics_frame
	check(e.eaten and is_equal_approx(p.elements.Ca, ca + 1.0), "eating the old skin gives back 1 Ca (%.1f -> %.1f)" % [ca, p.elements.Ca])
	# Leaves and comes back: still eaten, nothing new drawn
	main.load_room(main.current_room_pos)
	for i in 10: await physics_frame
	var shells = main.current_room_node.get_children().filter(func(c): return c.get_script() == preload("res://rooms/Exuvia.gd"))
	check(shells.is_empty(), "an eaten skin stays gone")
	print("MOLT done, %d failures" % fails)
	quit()
