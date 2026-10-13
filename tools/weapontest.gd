# weapontest.gd
# Every form attacks a row of enemies a few times, so each weapon's special
# move (Player.weapon_special, ranged signatures) runs at least once.
# Run: godot --headless --path . -s res://tools/weapontest.gd and look for
# SCRIPT ERROR lines; WEAPON lines list each form's kills.
extends SceneTree
var lineages = preload("res://data/Lineages.gd")
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.adapt_pending = true
	for path in lineages.TREE:
		var form = lineages.TREE[path]
		p.apply_form(form)
		p.global_position = main.current_room_node.global_position + Vector2(700, 540)
		p.reset_physics_interpolation()
		var foes = []
		for i in 3:
			var e = load("res://Enemy.tscn").instantiate()
			e.enemy_type = "pacer" if i == 1 else "fly"
			e.position = Vector2(820 + i * 40, 520 + i * 20)
			main.current_room_node.add_child(e)
			e.setup_enemy(2)
			e.set_physics_process(false)
			foes.append(e)
		for n in 8:
			p.shoot_cooldown = 0.0
			p.shoot_tear(Vector2.RIGHT)
			for i in 12: await physics_frame
		var dead = foes.filter(func(e): return not is_instance_valid(e)).size()
		print("WEAPON %s (%s): %d/3 down" % [form.id, form.get("weapon", ""), dead])
		for e in foes:
			if is_instance_valid(e):
				e.queue_free()
		for t in get_nodes_in_group("tears"):
			t.queue_free()
		for i in 10: await physics_frame
	print("WEAPON done")
	quit()
