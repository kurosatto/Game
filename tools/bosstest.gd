# bosstest.gd
# Spawns each era boss in its own era's room and lets it fight a player who
# circles the arena (kept alive), checking every attack runs without errors.
# With SHOT_DIR set (and a window, e.g. xvfb-run) it saves screenshots.
#   godot --headless --path . -s res://tools/bosstest.gd
# Optional BOSS=3 tests one floor; FIGHT_SECONDS=25 sets the length.
extends SceneTree

var out := OS.get_environment("SHOT_DIR")

func _initialize():
	run()

func snap(name: String):
	if out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func run():
	var only := int(OS.get_environment("BOSS")) if OS.get_environment("BOSS") != "" else 0
	var secs := float(OS.get_environment("FIGHT_SECONDS")) if OS.get_environment("FIGHT_SECONDS") != "" else 25.0
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var room_script = load("res://Room.gd")
	for floor_num in range(1, 6):
		if only != 0 and floor_num != only:
			continue
		main.floor_number = floor_num
		main.generate_floor()
		for i in 10: await process_frame
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var player = main.player
		var boss = load(room_script.BOSSES[floor_num]).new()
		boss.position = Vector2(960, 540)
		boss.setup_enemy(floor_num)
		main.current_room_node.add_child(boss)
		main.register_boss(boss)
		player.global_position = Vector2(960, 860)
		var states := {}
		var frames := int(secs * 60.0)
		var shots := 0
		for f in frames:
			await physics_frame
			if not is_instance_valid(boss):
				break
			# Circle the arena so the boss has to chase and aim
			var a := f / 60.0 * 0.9
			var want := Vector2(960, 540) + Vector2(cos(a) * 560.0, sin(a) * 260.0)
			if f > frames / 2:
				# Second half: keep away, so the long-range attacks come out
				var best := want
				for c in [Vector2(260, 260), Vector2(1660, 260), Vector2(260, 820), Vector2(1660, 820)]:
					if c.distance_to(boss.global_position) > best.distance_to(boss.global_position):
						best = c
				want = best
			player.global_position = player.global_position.move_toward(want, 6.0)
			player.health = player.max_health
			states[boss.state] = states.get(boss.state, 0) + 1
			if f == frames / 2:
				boss.take_damage(boss.max_health * 0.55)
			if out != "" and f % 150 == 75 and shots < 6:
				main.hud.item_banner.visible = false
				await snap("boss%d_%d_%s" % [floor_num, shots, boss.state])
				shots += 1
		# Force the rarer attacks once each so they are exercised too
		var force = {4: ["rear", "coil"], 5: ["tail_wind", "to_sun", "bask"], 3: ["ram_wind", "blast_wind"], 1: ["detach", "contract"]}
		for st in force.get(floor_num, []):
			if not is_instance_valid(boss):
				break
			boss.set_state(st)
			for f in 120:
				await physics_frame
				if not is_instance_valid(boss):
					break
				player.health = player.max_health
				states["forced " + boss.state] = states.get("forced " + boss.state, 0) + 1
		print("BOSSTEST floor %d %s states: %s" % [floor_num, boss.boss_title if is_instance_valid(boss) else "?", states])
		if is_instance_valid(boss):
			boss.take_damage(99999.0)
		for i in 30: await process_frame
		for n in main.current_room_node.get_children():
			if n.get_script() == load("res://bosses/BossHazard.gd") or n.is_in_group("enemy_tears"):
				n.queue_free()
	print("BOSSTEST done")
	quit()
