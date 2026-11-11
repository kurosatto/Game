extends SceneTree
# Pause and back-button checks: back pauses and resumes, the pause screen
# can't open over (and unpause) a card, and a game over waits a moment
# before a tap restarts. Run: godot --headless --path . -s res://tools/pausetest.gd
var main
var fails := 0
func check(ok: bool, what: String):
	print(("PAUSE ok   " if ok else "PAUSE FAIL ") + what)
	if not ok:
		fails += 1
func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10: await process_frame
	var hud = main.hud
	hud.back_pressed()
	check(paused and hud.settings_modal.visible, "back opens the pause screen")
	hud.back_pressed()
	check(not paused and not hud.settings_modal.visible, "back again resumes")
	hud.auto_pause()
	check(paused and hud.settings_modal.visible, "leaving the app pauses")
	hud.auto_pause()
	check(paused and hud.settings_modal.visible, "a second focus loss keeps it paused")
	hud.toggle_settings()
	hud.show_evolution_modal(1, [])
	hud.toggle_settings()
	check(not hud.settings_modal.visible, "Esc does not open the pause screen over an evolution card")
	hud.toggle_settings()
	check(paused, "the evolution card keeps the game paused")
	hud._on_evolution_choice_clicked(1, 0)
	check(not paused, "picking a branch resumes")
	hud.show_grow_screen()
	hud.back_pressed()
	check(not hud.is_grow_up() and not paused, "back closes the grow screen")
	# Touch aim assist: a shot 10 degrees off an animal bends onto it
	var e = load("res://Enemy.tscn").instantiate()
	e.enemy_type = "fly"
	e.process_mode = Node.PROCESS_MODE_DISABLED
	main.current_room_node.add_child(e)
	e.setup_enemy(1)
	e.global_position = main.player.global_position + Vector2.RIGHT.rotated(deg_to_rad(10)) * 400
	await process_frame
	var bent = main.player.aim_assist(Vector2.RIGHT)
	check(absf(bent.angle() - deg_to_rad(10)) < 0.01, "aim assist bends a near miss onto the animal")
	var kept = main.player.aim_assist(Vector2.UP)
	check(kept == Vector2.UP, "aim assist leaves a shot far from any animal alone")
	e.queue_free()
	main.player.take_damage(999)
	await process_frame
	check(hud.game_over_screen.visible and not hud.end_screen_ready(), "game over waits before a tap restarts")
	hud.show_grow_screen()
	check(not hud.is_grow_up(), "no grow screen over the game over")
	print("PAUSE done, %d failures" % fails)
	quit(1 if fails else 0)
