# fossil_icons.gd
# Renders each code-drawn era boss (bosses/*.gd) once, trims it and saves a
# 256 px square icon to assets/fossils/<name>.png for the main menu's fossil
# record. Needs a window and the GL renderer:
#   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/fossil_icons.gd
extends SceneTree

func _initialize():
	var vp = SubViewport.new()
	vp.size = Vector2i(1400, 1400)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bosses = load("res://Room.gd").BOSSES
	var fauna = load("res://data/Fauna.gd")
	DirAccess.make_dir_recursive_absolute("res://assets/fossils")
	for floor_num in range(1, 6):
		var boss = load(bosses[floor_num]).new()
		boss.position = Vector2(700, 700)
		boss.setup_enemy(floor_num)
		vp.add_child(boss)
		for i in 40: await process_frame
		boss.process_mode = Node.PROCESS_MODE_DISABLED
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var used = img.get_used_rect()
		var side = max(used.size.x, used.size.y) + 24
		var sq = Image.create(side, side, false, Image.FORMAT_RGBA8)
		sq.blit_rect(img, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
		sq.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		# Bosses face down the screen at rest; turn the animals head-up
		if floor_num > 1:
			sq.rotate_180()
		var name = fauna.BOSSES[floor_num].name.to_lower()
		sq.save_png("res://assets/fossils/%s.png" % name)
		print("ICON ", name, " ", used)
		boss.queue_free()
		for i in 3: await process_frame
	quit()
