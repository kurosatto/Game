# erashots.gd
# One screenshot of a fight room per era, with its animals, for checking the
# look of backgrounds and palettes. Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> godot --path . --rendering-driver opengl3 -s res://tools/erashots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	for floor_num in range(1, 6):
		main.floor_number = floor_num
		main.generate_floor()
		# Walk to the first fight room next to the start
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and (pos - main.current_room_pos).length() == 1:
				main.current_room_pos = pos
				main.load_room(pos)
				break
		main.player.global_position = Vector2(760, 560)
		main.player.reset_physics_interpolation()
		main.player.health = 999 # the animals may attack while we wait
		for i in 70: await process_frame
		main.hud.item_banner.visible = false
		# Park the passing shadow mid-room so it shows up in the picture
		var sh = main.current_room_node.get_node_or_null("PassingShadow")
		if sh and OS.get_environment("SHOW_SHADOW") != "":
			sh.process_mode = Node.PROCESS_MODE_DISABLED # freezes its tween
			sh.position = Vector2(1250, 420)
			sh.rotation = 0.6 if main.current_room_node.era_look.get_look(floor_num).shadow_turns else 0.0
			sh.modulate.a = 0.25
			main.get_node("VisionFog").set_vision(10, true)
			await process_frame
		await snap("era%d" % floor_num)
	quit()
