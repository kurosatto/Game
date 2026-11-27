# codexbuttons.gd
# Clicks and taps every top-bar button on the codex tree page and checks each
# one opens its page (the tree used to swallow button releases).
#   xvfb-run -a godot --path . -s res://tools/codexbuttons.gd
extends SceneTree
var failed = false
func check(ok: bool, what: String):
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failed = true
func find_button(menu, text: String) -> Button:
	for b in menu.overlay.find_children("*", "Button", true, false):
		if text in b.text:
			return b
	return null
func click(pos: Vector2, touch: bool):
	if touch:
		for down in [true, false]:
			var e = InputEventScreenTouch.new()
			e.position = pos
			e.pressed = down
			root.push_input(e)
			await process_frame
	else:
		for down in [true, false]:
			var e = InputEventMouseButton.new()
			e.position = pos
			e.global_position = pos
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = down
			root.push_input(e)
			await process_frame
func _initialize():
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 5: await process_frame
	for touch in [false, true]:
		for pair in [["FOSSILS", "FOSSIL RECORD"], ["LIST", "CODEX"], ["BACK", ""]]:
			menu.show_codex()
			for i in 5: await process_frame
			var b = find_button(menu, pair[0])
			await click(b.get_global_rect().get_center(), touch)
			for i in 3: await process_frame
			var ok: bool
			if pair[0] == "BACK":
				ok = menu.overlay == null
			else:
				ok = menu.overlay != null and find_button(menu, "TREE" if pair[0] == "LIST" else "TRACES") != null
			check(ok, "%s %s opens its page" % ["tap" if touch else "click", pair[0]])
	quit(1 if failed else 0)
