# padtest.gd
# Drives the main menu and a run with fake gamepad presses and checks that
# the highlight, sticks, dash, pause, grow and back all respond.
# Run: godot --headless --path . -s res://tools/padtest.gd
# With SHOT_DIR=<folder> (and a window, e.g. xvfb-run at 1920x1200) it also
# saves pictures of each screen (delete user://settings.cfg first to see the
# first-launch window mode).
extends SceneTree

var out := OS.get_environment("SHOT_DIR")
var fails := 0

func check(ok: bool, what: String):
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func frames(n: int):
	for i in n:
		await process_frame

func snap(name: String):
	if out == "":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func button(b: JoyButton, hold: int = 2):
	var e = InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await frames(hold)
	var r = InputEventJoypadButton.new()
	r.device = 0
	r.button_index = b
	r.pressed = false
	Input.parse_input_event(r)
	await frames(3)

func axis(a: JoyAxis, v: float):
	var e = InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)

func focus() -> Control:
	return root.get_viewport().gui_get_focus_owner()

func focus_text() -> String:
	var f = focus()
	if f == null:
		return "<none>"
	return (f.text if "text" in f else f.get_class()).strip_edges()

func _initialize():
	# Pictures are taken at the Legion Go's 1920x1200
	for i in 10: await process_frame
	print("window mode ", DisplayServer.window_get_mode(), " (3 = fullscreen; xvfb has no window manager to grant it)")
	if out != "":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1200))
		root.size = Vector2i(1920, 1200)
		for i in 10: await process_frame
	var pad = root.get_node("PadInput")

	# ---- Main menu ----
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(10)
	await button(JOY_BUTTON_DPAD_DOWN)
	await frames(3)
	check(pad.using_pad, "pad press switches to pad mode")
	check(focus() != null, "a menu button is highlighted (%s)" % focus_text())
	await snap("1_menu_highlight")
	var start = focus_text()
	await button(JOY_BUTTON_DPAD_DOWN)
	check(focus_text() != start, "d-pad down moves the highlight (%s -> %s)" % [start, focus_text()])
	# Walk down to CODEX and open it
	var guard = 0
	while not focus_text().contains("CODEX") and guard < 8:
		if focus_text().contains("CHALLENGES"):
			await button(JOY_BUTTON_DPAD_RIGHT)
		else:
			await button(JOY_BUTTON_DPAD_DOWN)
		print("  at ", focus_text())
		guard += 1
	check(focus_text().contains("CODEX"), "reached CODEX (%s)" % focus_text())
	await button(JOY_BUTTON_A)
	await frames(5)
	check(menu.overlay != null, "A opens the codex page")
	check(focus() != null and menu.overlay != null and menu.overlay.is_ancestor_of(focus()), "highlight moves into the page (%s)" % focus_text())
	guard = 0
	while focus() and not focus().has_method("pad_navigate") and guard < 4:
		await button(JOY_BUTTON_DPAD_DOWN)
		guard += 1
	check(focus() != null and focus().has_method("pad_navigate"), "d-pad reaches the codex tree")
	await button(JOY_BUTTON_DPAD_UP)
	await snap("2_codex_tree_pad")
	await button(JOY_BUTTON_B)
	await button(JOY_BUTTON_B)
	await frames(5)
	check(menu.overlay == null, "B closes the page")
	check(focus_text().contains("CODEX"), "highlight returns to CODEX (%s)" % focus_text())
	menu.queue_free()
	await frames(2)

	# ---- A run ----
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	main.hud.show_era_card(1, main.hud.lineages.get_form(""))
	await frames(5)
	await snap("3_era_card")
	main.hud.intro_ready_time = 0
	await button(JOY_BUTTON_A)
	check(not main.hud.is_card_up(), "A closes the era card")
	check(not paused, "run is playing")
	var tc = main.get_node("TouchControls")
	check(not tc.canvas.visible, "touch sticks hidden while on the pad")
	var p = main.player
	var x0 = p.global_position.x
	axis(JOY_AXIS_LEFT_X, 1.0)
	await frames(30)
	axis(JOY_AXIS_LEFT_X, 0.0)
	check(p.global_position.x > x0 + 40, "left stick moves (%.0f px)" % (p.global_position.x - x0))
	var tears = get_nodes_in_group("tears").size()
	axis(JOY_AXIS_RIGHT_Y, -1.0)
	await frames(20)
	check(get_nodes_in_group("tears").size() > tears or p.shoot_cooldown > 0.0, "right stick shoots")
	await snap("4_room_pad")
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	await frames(30)
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	check(p.is_dashing or p.dash_cooldown > 0.0, "right trigger dashes")
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await frames(30)
	await button(JOY_BUTTON_START)
	await frames(5)
	check(paused and main.hud.settings_modal.visible, "Start pauses")
	check(focus() == main.hud.resume_btn, "highlight starts on RESUME (%s)" % focus_text())
	await snap("5_pause_pad")
	await button(JOY_BUTTON_DPAD_UP)
	check(focus() != main.hud.resume_btn, "d-pad moves on the pause screen (%s)" % focus_text())
	await button(JOY_BUTTON_B)
	await frames(3)
	check(not paused, "B resumes")
	await button(JOY_BUTTON_Y)
	await frames(5)
	check(main.hud.is_grow_up(), "Y opens grow screen")
	check(focus() != null, "grow screen highlight (%s)" % focus_text())
	await snap("6_grow_pad")
	await button(JOY_BUTTON_B)
	check(not main.hud.is_grow_up() and not paused, "B closes grow screen")
	# Evolution choice: the cards take the highlight once they wake up
	main.hud.show_evolution_modal(1, [])
	await frames(90)
	var em = main.hud.evolution_modal
	check(focus() != null and em.is_ancestor_of(focus()), "evolution card highlighted (%s)" % focus_text())
	await snap("7_evolution_pad")
	await button(JOY_BUTTON_DPAD_RIGHT)
	check(focus() != null and em.is_ancestor_of(focus()), "d-pad stays on the evolution cards (%s)" % focus_text())
	# A card's INFO button swaps its stat bars for the full text and back
	if focus_text() == "INFO" or focus_text() == "DETAILS":
		await button(JOY_BUTTON_A)
		check(focus_text() == "STATS", "A on INFO opens the card's details (%s)" % focus_text())
		await button(JOY_BUTTON_A)
		await button(JOY_BUTTON_DPAD_RIGHT)
	check(focus_text() == "EVOLVE", "d-pad reaches EVOLVE (%s)" % focus_text())
	await button(JOY_BUTTON_A)
	await frames(30)
	check(not em.visible, "A picks an evolution")
	await frames(30)
	if main.hud.is_card_up():
		main.hud.intro_ready_time = 0
		await button(JOY_BUTTON_A)
	check(not paused, "back to playing after evolving")
	# Touching the screen hands control back to the touch sticks
	var t = InputEventScreenTouch.new()
	t.pressed = true
	t.position = Vector2(300, 900)
	Input.parse_input_event(t)
	await frames(2)
	t = InputEventScreenTouch.new()
	t.pressed = false
	t.position = Vector2(300, 900)
	Input.parse_input_event(t)
	await frames(2)
	check(not pad.using_pad, "touch switches back from the pad")

	print("PADTEST %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
