# codexshots.gd
# Screenshots of the codex evolution tree with a few discovered paths.
# Needs a window (xvfb-run on Linux); overwrites user://codex.cfg:
#   SHOT_DIR=<folder> godot --path . -s res://tools/codexshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var lineages = load("res://data/Lineages.gd")
	var codex = load("res://data/Codex.gd")
	# Two full runs and part of a third
	for path in ["", "0", "0,1", "0,1,0", "0,1,0,1", "3", "3,1", "3,1,2", "3,1,2,0", "2", "2,0"]:
		if lineages.TREE.has(path):
			codex.discover(lineages.TREE[path].id)
	for i in 5: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2340, 1080))
	for i in 10: await process_frame
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 20: await process_frame
	menu.show_codex()
	for i in 10: await process_frame
	await snap("codex_tree")
	var tree = menu.overlay.find_children("*", "Control", true, false).filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("CodexTree.gd"))[0]
	tree.select("3,1,2")
	await snap("codex_tree_info")
	tree.select("3,1,2,1")
	await snap("codex_tree_unknown")
	tree.select(tree.NONE)
	tree.zoom_at(tree.size * 0.5, 0.01)
	await snap("codex_tree_zoomed_out")
	tree.zoom_at(Vector2(200, tree.size.y - 100), 2.2)
	await snap("codex_tree_zoomed_in")
	menu.show_codex_list()
	await snap("codex_list")
	quit()
