# eracardshots.gd
# The era page that opens each floor: screenshots for era 1 (keys, pad,
# touch wording) and later eras, and checks that it freezes the game and that a
# tap, key, click, pad button or the back button closes it. Needs a window:
# SHOT_DIR=<folder> godot --path . --rendering-driver opengl3 -s res://tools/eracardshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
var fails := 0
func snap(name: String):
	for i in 25: await process_frame # let the reveal finish
	await RenderingServer.frame_post_draw
	if out != "":
		root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func snap_now(name: String):
	await RenderingServer.frame_post_draw
	if out != "":
		root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func check(ok: bool, what: String):
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func wait_ready():
	await create_timer(0.5, true).timeout
func press(ev: InputEvent):
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var hud = main.hud
	for floor_num in [1, 2, 3, 4, 5]:
		main.floor_number = floor_num
		main.generate_floor()
		await process_frame
		hud.show_era_card(floor_num, main.current_form())
		check(paused and hud.is_card_up(), "era %d page freezes the game" % floor_num)
		check(not hud.item_banner.visible, "era %d no banner over play" % floor_num)
		await snap("era%d_page" % floor_num)
		hud.dismiss_card()
	root.get_node("PadInput").using_pad = true
	main.floor_number = 1
	hud.show_era_card(1, main.current_form())
	await snap("era1_page_pad")
	hud.dismiss_card()
	root.get_node("PadInput").using_pad = false

	# Each way of skipping it
	var evs = []
	var t = InputEventScreenTouch.new(); t.pressed = true; t.position = Vector2(500, 500); evs.append(["tap", t])
	var k = InputEventKey.new(); k.pressed = true; k.keycode = KEY_SPACE; k.physical_keycode = KEY_SPACE; evs.append(["key", k])
	var m = InputEventMouseButton.new(); m.pressed = true; m.button_index = MOUSE_BUTTON_LEFT; m.position = Vector2(900, 500); evs.append(["click", m])
	var j = InputEventJoypadButton.new(); j.pressed = true; j.button_index = JOY_BUTTON_A; evs.append(["pad A", j])
	for e in evs:
		hud.show_era_card(2, main.current_form())
		await wait_ready()
		await press(e[1])
		check(not hud.is_card_up() and not paused, e[0] + " closes the page and play resumes")
	# Too soon after opening it is ignored (the tap that opened it)
	hud.show_era_card(2, main.current_form())
	await press(evs[0][1])
	check(hud.is_card_up(), "a tap in the first moment is ignored")
	# Auto-pause leaves it alone, the back button closes it
	hud.auto_pause()
	check(hud.is_card_up() and not hud.settings_modal.visible, "auto-pause keeps the page, no pause menu on top")
	hud.back_pressed()
	check(not hud.is_card_up() and not paused and not hud.settings_modal.visible, "back button closes the page")
	# No floor quests any more: no mark under the map
	main.floor_number = 1
	main.generate_floor()
	for i in 10: await process_frame
	check(hud.get_node_or_null("QuestMark") == null, "no quest mark in play")
	print("FAILS ", fails)
	quit()
