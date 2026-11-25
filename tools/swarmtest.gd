# swarmtest.gd
# Prey swarms in ordinary fight rooms (Room.spawn_prey_swarm): some rooms get
# a bunch of the era's small swarming prey that flee from you, aren't part of
# the fight (the room clears without them), and are still there after.
# Run: godot --headless --path . -s res://tools/swarmtest.gd
extends SceneTree
var failures := 0
var out := OS.get_environment("SHOT_DIR")

func check(ok: bool, what: String):
	print("SWARM %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures += 1

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	var found := 0
	var floors_with := {}
	for f in [1, 2, 3]:
		main.floor_number = f
		main.generate_floor()
		await process_frame
		for pos in main.dungeon_rooms:
			var d = main.dungeon_rooms[pos]
			if d.type != 1 or d.special != "" or d.lair != "":
				continue
			main.load_room(pos)
			for i in 3: await physics_frame
			var room = main.current_room_node
			var prey = room.get_children().filter(func(c): return c.has_meta("swarm_prey"))
			if prey.is_empty():
				continue
			found += 1
			floors_with[f] = true
			check(prey.size() >= 4 and prey.all(func(e): return e.damage == 0 and not e in room.active_enemies), "floor %d: %d harmless prey, not in the fight" % [f, prey.size()])
			if found == 1:
				# They run from you
				var e = prey[0]
				var start = e.global_position
				for i in 60:
					p.global_position = start + Vector2(90, 0)
					p.health = max(p.health, 2)
					await physics_frame
				check(not is_instance_valid(e) or e.global_position.distance_to(start + Vector2(90, 0)) > 150.0, "come close and they bolt (%.0f px)" % (e.global_position.distance_to(start + Vector2(90, 0)) if is_instance_valid(e) else -1.0))
				if out != "":
					main.hud.item_banner.visible = false
					for i in 3: await process_frame
					root.get_texture().get_image().save_png(out + "/22_swarm.png")
				# The room clears on its fight alone
				d.waves_left = 0
				for x in room.active_enemies.duplicate():
					if is_instance_valid(x):
						x.take_damage(9999.0)
				for i in 40: await physics_frame
				check(d.cleared, "the room clears with the prey still about")
				var left = room.get_children().filter(func(c): return c.has_meta("swarm_prey") and not c.dead).size()
				check(left > 0, "the prey are still there after (%d)" % left)
				# Eat one, and a revisit has one fewer
				var before = d.special_state.swarm
				var q = room.get_children().filter(func(c): return c.has_meta("swarm_prey") and not c.dead)[0]
				q.take_damage(9999.0)
				for i in 5: await physics_frame
				check(d.special_state.swarm == before - 1, "eaten prey are remembered (%d -> %d)" % [before, d.special_state.swarm])
	check(found >= 2, "swarms turn up in some rooms (%d)" % found)
	print("SWARM done, %d failures" % failures)
	quit(1 if failures > 0 else 0)
