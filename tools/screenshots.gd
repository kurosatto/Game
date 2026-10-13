# screenshots.gd
# Renders the room, evolution cards, pause menu and game over with touch
# controls on, for checking phone layouts on a PC (needs a window, not
# --headless). Run: SHOT_DIR=<folder> godot --path . -s res://tools/screenshots.gd
# Optional SHOT_SIZE=2340x1080 sets the window size (default: as configured).
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	var size_env := OS.get_environment("SHOT_SIZE")
	if size_env != "":
		var parts = size_env.split("x")
		# Wait for SettingsManager to apply the saved window mode, then override it
		for i in 5: await process_frame
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		for i in 5: await process_frame
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		for i in 10: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var tc = main.get_node("TouchControls"); tc.visible = true
	main.hud.use_touch_texts()
	await snap("1_room")
	# Every era animal side by side (one column per era), frozen, in the current room
	var row := 0
	for floor_num in range(1, 6):
		var col := 0
		for kind in ["fly", "pacer"] + preload("res://data/Fauna.gd").special_types(floor_num):
			var e = load("res://Enemy.tscn").instantiate()
			e.enemy_type = kind
			e.position = Vector2(420 + floor_num * 220, 230 + col * 190)
			e.process_mode = Node.PROCESS_MODE_DISABLED
			main.current_room_node.add_child(e)
			e.setup_enemy(floor_num)
			e.get_node("Sprite2D").rotation = 0.0
			col += 1
	await snap("1c_fauna")
	for e in get_nodes_in_group("enemies"):
		if e.process_mode == Node.PROCESS_MODE_DISABLED:
			e.queue_free()
	# Vision fog: starting cell (blind) vs. a dragonfly (best eyes)
	var fog = main.get_node("VisionFog")
	fog.set_vision(1, true)
	fog.set_sense(4, "Chemical sense")
	# Hidden enemies around the cell so the sense arrows show
	var hidden := []
	for pos in [Vector2(300, 250), Vector2(1600, 300), Vector2(1500, 850), Vector2(400, 900)]:
		var he = load("res://Enemy.tscn").instantiate()
		he.enemy_type = "pacer"
		he.position = pos
		he.process_mode = Node.PROCESS_MODE_DISABLED
		main.current_room_node.add_child(he)
		he.setup_enemy(1)
		hidden.append(he)
	await snap("1d_vision_cell")
	fog.set_sense(9, "Smell")
	await snap("1f_sense_mammal")
	for he in hidden:
		he.queue_free()
	fog.set_sense(main.player.sense, main.player.sense_kind)
	fog.set_vision(10, true)
	await snap("1e_vision_dragonfly")
	fog.set_vision(main.player.vision, true)
	# Biomass orbs bursting from a kill
	var prey = load("res://Enemy.tscn").instantiate()
	prey.enemy_type = "pacer"
	prey.position = main.player.position + Vector2(260, -60)
	main.current_room_node.add_child(prey)
	prey.setup_enemy(1)
	await process_frame
	prey.take_damage(9999.0)
	for i in 14: await process_frame
	await snap("1g_biomass")
	main.hud.flash_hurt()
	await snap("1b_hurt")
	main.hud.show_evolution_modal(1, main.player.evolution_choices)
	await snap("2_evolution")
	main.hud._on_evolution_choice_clicked(1, 0)
	var ad = main.player.adaptations
	main.hud.show_adaptation_modal([ad.get_adaptation("autotomy"), ad.get_adaptation("serrated"), ad.get_adaptation("electrocytes")], {"serrated": 1})
	await snap("2b_adaptation")
	main.hud._on_adaptation_clicked(main.hud.adaptation_options[0].id)
	main.hud.toggle_settings()
	await snap("3_settings")
	main.hud.toggle_settings()
	main.hud.show_game_over()
	await snap("4_gameover")
	quit()
