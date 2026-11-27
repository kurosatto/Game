# spitwindtest.gd
# A shooting animal (pacer) next to the player: checks it winds up (stops,
# droplet at the mouth) before every shot, and saves frames of one wind-up.
#   SHOT_DIR=<folder> xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/spitwindtest.gd
# Without SHOT_DIR it runs headless and only reports.
extends SceneTree
func _initialize():
	var out := OS.get_environment("SHOT_DIR")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var room = main.current_room_node
	for e in get_nodes_in_group("enemies"): e.queue_free()
	await process_frame
	main.get_node("VisionFog").set_vision(10, true)
	room.spawn_enemy(Vector2(1000, 540), "pacer", 1)
	var foe = get_nodes_in_group("enemies").filter(func(e): return e.enemy_type == "pacer" and not e.is_queued_for_deletion())[0]
	foe.provoke()
	var winds := 0
	var was_wind := false
	var frames := 0
	for f in 600:
		p.invincibility_time = 99.0
		p.health = p.max_health
		p.global_position = room.global_position + Vector2(700, 540)
		await physics_frame
		if not is_instance_valid(foe):
			break
		var winding: bool = foe.spit_wind > 0.0
		if winding and not was_wind:
			winds += 1
		was_wind = winding
		if winding and out != "" and winds == 1 and frames < 8 and f % 4 == 0:
			await RenderingServer.frame_post_draw
			var img = root.get_texture().get_image()
			img.save_png(out + "/wind_%d.png" % frames)
			frames += 1
	print("SPITWIND wind-ups: ", winds)
	print("SPITWIND ", "PASS" if winds >= 1 else "FAIL")
	quit()
