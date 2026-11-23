# griptest.gd
# A coleoid grabs an animal with the tentacle (GripTether), reels it in,
# bites it while held, then lets go. Also grabs a boss (held, not moved).
# Run: xvfb-run -a godot --path . -s res://tools/griptest.gd
# Prints GRIP lines; SHOT_DIR=<folder> also saves a screenshot mid-hold.
extends SceneTree
var lineages = preload("res://data/Lineages.gd")
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.adapt_pending = true
	p.apply_form(lineages.TREE["2,0,1"])
	p.global_position = main.current_room_node.global_position + Vector2(700, 540)
	p.reset_physics_interpolation()
	var e = load("res://Enemy.tscn").instantiate()
	e.enemy_type = "pacer"
	e.position = Vector2(880, 540)
	main.current_room_node.add_child(e)
	e.setup_enemy(5)
	e.max_health = 999.0
	e.health = 999.0
	for i in 5: await physics_frame
	var d0 = e.global_position.distance_to(p.global_position)
	p.shoot_cooldown = 0.0
	p.shoot_tear(Vector2.RIGHT)
	for i in 20: await physics_frame
	var d1 = e.global_position.distance_to(p.global_position)
	print("GRIP grabbed_time=%.2f dist %.0f -> %.0f tethers=%d" % [e.grabbed_time, d0, d1, get_nodes_in_group("x").size() + main.current_room_node.get_children().filter(func(c): return c.get_script() == preload("res://GripTether.gd")).size()])
	var hp = e.health
	p.shoot_cooldown = 0.0
	p.shoot_tear((e.global_position - p.global_position).normalized())
	print("GRIP bite dmg=%.1f (damage %.1f) still held=%s" % [hp - e.health, p.damage, e.grabbed_time > 0])
	for i in 4: await process_frame
	var dir = OS.get_environment("SHOT_DIR")
	if dir != "":
		root.get_viewport().get_texture().get_image().save_png(dir + "/grip_hold.png")
	for i in 90: await physics_frame
	print("GRIP after 1.5s held=%s tethers left=%d" % [e.grabbed_time > 0, main.current_room_node.get_children().filter(func(c): return c.get_script() == preload("res://GripTether.gd")).size()])
	quit()
