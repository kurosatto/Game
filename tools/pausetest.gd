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
	main.player.take_damage(999)
	await process_frame
	check(hud.game_over_screen.visible and not hud.end_screen_ready(), "game over waits before a tap restarts")
	hud.show_grow_screen()
	check(not hud.is_grow_up(), "no grow screen over the game over")
	print("PAUSE done, %d failures" % fails)
	quit(1 if fails else 0)
