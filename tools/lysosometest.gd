# lysosometest.gd
# Checks the starting cell's lysosomes: they stop within a short range in
# open water, and a hit keeps digesting the prey after the sac is gone.
# Run: godot --headless --path . -s res://tools/lysosometest.gd
extends SceneTree
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	p.velocity = Vector2.ZERO
	print("WEAPON ", p.current_weapon)
	# 1. Range in open water
	var start: Vector2 = p.global_position
	p.shoot_cooldown = 0.0
	p.shoot_tear(Vector2.RIGHT)
	await physics_frame
	var far := 0.0
	for i in 120:
		var live := false
		for t in get_nodes_in_group("tears"):
			if is_instance_valid(t) and not t.is_queued_for_deletion() and not t.is_enemy_tear:
				live = true
				far = max(far, t.global_position.distance_to(start))
		if not live:
			break
		await physics_frame
	print("RANGE ", snapped(far, 1.0))
	# 2. Digestion after contact
	var prey = load("res://Enemy.tscn").instantiate()
	prey.enemy_type = "pacer"
	prey.position = p.global_position + Vector2(80, 0)
	main.current_room_node.add_child(prey)
	prey.setup_enemy(1)
	prey.speed = 0.0
	prey.health = 999.0
	prey.max_health = 999.0
	for i in 5: await physics_frame
	p.shoot_cooldown = 0.0
	p.shoot_tear(Vector2.RIGHT)
	var hit_at := -1.0
	var log := []
	for i in 120:
		await physics_frame
		if prey.health < 999.0 and hit_at < 0.0:
			hit_at = i
		log.append(prey.health)
	print("HIT_FRAME ", hit_at, " HEALTH_AFTER_HIT ", log[int(hit_at) + 1] if hit_at >= 0 else -1, " FINAL ", log[-1])
	var ok = far > 60.0 and far < 170.0 and hit_at >= 0 and log[-1] < log[int(hit_at) + 1]
	print("LYSOSOME_TEST ", "PASS" if ok else "FAIL")
	quit()
