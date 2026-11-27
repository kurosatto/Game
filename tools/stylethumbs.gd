# stylethumbs.gd
# The ART STYLE screen's pictures (assets/ui/art_styles/<id>.png): a real
# in-game shot of the same fight room in every style, cropped to a strip
# around the player with the HUD hidden. Run (writes the PNGs in place):
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://tools/stylethumbs.gd
# ERA=<floor> picks the era (default 2), OUT=<folder> writes elsewhere.
extends SceneTree
const W := 1000
const H := 324
func _initialize():
	var out := OS.get_environment("OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://assets/ui/art_styles")
	var era := int(OS.get_environment("ERA")) if OS.get_environment("ERA") != "" else 2
	var settings = root.get_node("SettingsManager")
	var before: String = settings.art_style
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	main.floor_number = era
	main.generate_floor()
	var room_pos = main.current_room_pos
	for pos in main.dungeon_rooms:
		var r = main.dungeon_rooms[pos]
		if r.type == 1 and (pos - main.current_room_pos).length() == 1:
			room_pos = pos
			break
	# The first room load after a new floor is still settling: shoot sepia twice
	var ids: Array = ["sepia"] + preload("res://data/ArtStyles.gd").ids()
	for id in ids:
		settings.set_art_style(id)
		seed(era * 1000 + 7)
		main.current_room_pos = room_pos
		main.load_room(room_pos)
		var p = main.player
		var lineages = load("res://data/Lineages.gd")
		for path in lineages.TREE:
			if lineages.TREE[path].id == "early_arthropod":
				p.apply_form(lineages.TREE[path])
		p.global_position = main.current_room_node.global_position + Vector2(960, 540)
		p.reset_physics_interpolation()
		p.health = 999
		p.invincibility_time = 0.0
		main.get_node("VisionFog").set_vision(10, true)
		# The same few of the era's animals around you in every shot, held still
		var room = main.current_room_node
		for e in get_nodes_in_group("enemies"): e.queue_free()
		for o in get_nodes_in_group("element_orbs"): o.queue_free()
		await process_frame
		var types = ["pacer", "fly", "fly"] + preload("res://data/Fauna.gd").special_types(era)
		var spots = [Vector2(-230, -40), Vector2(210, -70), Vector2(150, 90), Vector2(-120, 95), Vector2(300, 40)]
		for i in min(types.size(), spots.size()):
			room.spawn_enemy(Vector2(960, 540) + spots[i], types[i], era)
		for i in 6: await process_frame
		for e in get_nodes_in_group("enemies"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
			for c in e.get_children():
				if c is Label: c.visible = false
		for i in 20:
			p.health = 999
			p.invincibility_time = 0.0
			p.visible = true
			await process_frame
		main.hud.visible = false
		for c in main.hud.get_children():
			if c is CanvasItem: c.visible = false
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var sz = img.get_size()
		var cw = int(sz.x * 0.46)
		var ch = int(cw * float(H) / W)
		var crop = img.get_region(Rect2i((sz.x - cw) / 2, (sz.y - ch) / 2, cw, ch))
		crop.resize(W, H, Image.INTERPOLATE_LANCZOS)
		crop.save_png(out + "/" + id + ".png")
		print("THUMB ", id)
		main.hud.visible = true
		for c in main.hud.get_children():
			if c is CanvasItem: c.visible = true
	settings.set_art_style(before)
	quit()
