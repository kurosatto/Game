# codexfit.gd
# The codex tree at one screen size (run with --resolution 2340x1080 for the
# phone, 1920x1200 for the Legion Go) in every art style: opening view, a form's info panel open, and fully zoomed
# out. Needs a window (xvfb on Linux); overwrites user://codex.cfg:
#   SHOT_DIR=<folder> [STYLES=sepia,...] godot --path . --rendering-driver opengl3 --resolution 2340x1080 -s res://tools/codexfit.gd
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
	var settings = root.get_node("SettingsManager")
	var before: String = settings.art_style
	for path in ["", "0", "0,1", "0,1,0", "0,1,0,1", "3", "3,1", "3,1,2", "3,1,2,0", "2", "2,0"]:
		if lineages.TREE.has(path):
			codex.discover(lineages.TREE[path].id)
	var styles: Array = preload("res://data/ArtStyles.gd").ids()
	if OS.get_environment("STYLES") != "":
		styles = Array(OS.get_environment("STYLES").split(","))
	var win = DisplayServer.window_get_size()
	for sz in ["%dx%d" % [win.x, win.y]]:
		for i in 10: await process_frame
		for id in styles:
			settings.set_art_style(id)
			var menu = load("res://MainMenu.tscn").instantiate()
			root.add_child(menu)
			for i in 15: await process_frame
			menu.show_codex()
			for i in 10: await process_frame
			var tree = menu.overlay.find_children("*", "Control", true, false).filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("CodexTree.gd"))[0]
			await snap("%s_%s_open" % [sz, id])
			if id == styles[0]:
				print("TREE content=", tree.content_size, " view=", tree.size, " zoom=", tree.zoom, " min=", tree.min_zoom())
				tree.select("3,1,2")
				await snap("%s_%s_info" % [sz, id])
				tree.select(tree.NONE)
				tree.zoom_at(tree.size * 0.5, 0.01)
				await snap("%s_%s_zoomed_out" % [sz, id])
			menu.queue_free()
			for i in 3: await process_frame
	settings.set_art_style(before)
	quit()
