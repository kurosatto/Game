# codextest.gd
# Checks the codex tree's touch input: a tap selects a form, a drag pans
# without selecting, a pinch zooms.
# Needs a real window (headless has a 0x0 one that breaks input transforms):
#   xvfb-run -a godot --path . -s res://tools/codextest.gd
extends SceneTree
func touch(i: int, pos: Vector2, down: bool):
	var e = InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = down
	root.push_input(e)
func move(i: int, pos: Vector2, rel: Vector2):
	var e = InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	root.push_input(e)
func check(ok: bool, what: String):
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failed = true
var failed = false
func _initialize():
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 5: await process_frame
	menu.show_codex()
	for i in 5: await process_frame
	var tree = menu.overlay.find_children("*", "Control", true, false).filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("CodexTree.gd"))[0]
	check(tree.nodes.size() == 75, "all 75 forms laid out")
	var root_screen = tree.global_position + tree.offset + tree.nodes[""].pos * tree.zoom
	touch(0, root_screen, true)
	touch(0, root_screen, false)
	await process_frame
	check(tree.selected == "" and tree.info.visible, "tap on the starting cell selects it")
	tree.select(tree.NONE)
	var before = tree.offset
	var p = tree.global_position + tree.size * 0.5
	touch(0, p, true)
	for k in 5:
		move(0, p + Vector2(-40 * (k + 1), 0), Vector2(-40, 0))
	touch(0, p + Vector2(-200, 0), false)
	await process_frame
	check(tree.offset.x < before.x - 100, "drag pans the tree")
	check(tree.selected == tree.NONE, "drag does not select")
	var z = tree.zoom
	touch(0, p - Vector2(50, 0), true)
	touch(1, p + Vector2(50, 0), true)
	move(1, p + Vector2(150, 0), Vector2(100, 0))
	touch(1, p + Vector2(150, 0), false)
	touch(0, p - Vector2(50, 0), false)
	await process_frame
	check(tree.zoom > z * 1.3, "pinch zooms in")
	quit(1 if failed else 0)
