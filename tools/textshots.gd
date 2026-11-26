# textshots.gd
# The shortened screens: the era page with ERA INFO opened (by a tap on the
# button, which must not close the page), and the pause page's settings page.
# SHOT_DIR=<folder> SHOT_TAG=<shape> xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 2400x1080 -s res://tools/textshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
var tag := OS.get_environment("SHOT_TAG")
var fails := 0
func snap(name: String):
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	if out != "":
		root.get_texture().get_image().save_png(out + "/" + name + "_" + tag + ".png")
	print("SHOT ", name)
func check(ok: bool, what: String):
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var hud = main.hud
	hud.dismiss_card()
	main.floor_number = 4
	main.generate_floor()
	await process_frame
	hud.show_era_card(4, main.current_form())
	await create_timer(0.5, true).timeout
	await snap("era_page")
	var t = InputEventScreenTouch.new(); t.pressed = true
	t.position = hud.era_info_btn.get_global_rect().get_center()
	Input.parse_input_event(t)
	var m = InputEventMouseButton.new(); m.pressed = true; m.button_index = MOUSE_BUTTON_LEFT; m.position = t.position
	Input.parse_input_event(m) # the copied click a phone sends after a tap
	for i in 3: await process_frame
	check(hud.is_card_up() and hud.era_info_box.visible, "tapping ERA INFO opens the info and keeps the page")
	await snap("era_info")
	await create_timer(0.4, true).timeout
	var k = InputEventKey.new(); k.pressed = true; k.keycode = KEY_SPACE
	Input.parse_input_event(k)
	for i in 3: await process_frame
	check(not hud.is_card_up(), "another key closes the page")
	hud.toggle_settings()
	var vp = root.get_visible_rect()
	check(vp.encloses(hud.pause_box.get_global_rect()), "pause page fits the screen")
	await snap("pause")
	hud.show_settings_page(true)
	check(not hud.pause_box.visible and hud.settings_page_up(), "SETTINGS swaps to the settings page")
	await snap("settings")
	check(vp.encloses(hud.get_node("SettingsModal/Panel").get_global_rect()), "settings page fits the screen")
	hud.toggle_settings()
	check(hud.settings_modal.visible and hud.pause_box.visible, "Esc on settings goes back to the pause page")
	hud.toggle_settings()
	check(not hud.settings_modal.visible and not paused, "Esc again resumes")
	print("FAILS ", fails)
	quit()
