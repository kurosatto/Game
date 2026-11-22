# evoshots.gd
# Pictures of the evolution cards (stat bars, the DETAILS view, a refine and
# a four-way split) in a few art styles, for checking the layout.
# Run: SHOT_DIR=<folder> xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 -s res://tools/evoshots.gd
# Optional SHOT_SIZE=2340x1080 and SHOT_STYLES=sepia,neon
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 40: await process_frame # let the cards deal in and bars fill
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func find_buttons(n: Node, text: String, acc: Array) -> Array:
	if n is Button and n.text == text and n.is_visible_in_tree():
		acc.append(n)
	for c in n.get_children():
		find_buttons(c, text, acc)
	return acc

func _initialize():
	var size_env := OS.get_environment("SHOT_SIZE")
	for i in 5: await process_frame
	if size_env != "":
		var parts = size_env.split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.size = Vector2i(int(parts[0]), int(parts[1]))
		for i in 10: await process_frame
	var styles := OS.get_environment("SHOT_STYLES")
	var style_list: Array = Array(styles.split(",")) if styles != "" else ["sepia"]
	var lin = preload("res://data/Lineages.gd")
	# A path with four children and one with none (refine)
	var four := []
	var leaf := []
	for key in lin.TREE:
		var kids = lin.get_child_paths(key)
		if kids.size() >= 4 and four.is_empty():
			four = Array(key.split(",")) if key != "" else []
		if kids.is_empty() and leaf.is_empty() and key.count(",") >= 1:
			leaf = Array(key.split(","))
	var sm = root.get_node("SettingsManager")
	for st in style_list:
		sm.set_art_style(st)
		var main = load("res://Main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		for i in 30: await process_frame
		var tag = st + ("_" + size_env if size_env != "" else "")
		main.hud.show_evolution_modal(1, [])
		await snap(tag + "_1_split")
		(find_buttons(main.hud, "DETAILS", []) + find_buttons(main.hud, "INFO", []))[0].pressed.emit()
		await snap(tag + "_2_details")
		main.hud.evolution_modal.visible = false
		var p = []
		for x in four: p.append(int(x))
		main.player.evolution_choices = p
		main.hud.show_evolution_modal(2, p)
		await snap(tag + "_3_four")
		main.hud.evolution_modal.visible = false
		p = []
		for x in leaf: p.append(int(x))
		main.player.evolution_choices = p
		main.hud.show_evolution_modal(3, p)
		await snap(tag + "_4_refine")
		main.hud.evolution_modal.visible = false
		get_root().get_tree().paused = false
		main.queue_free()
		for i in 5: await process_frame
	sm.set_art_style("sepia")
	quit()
