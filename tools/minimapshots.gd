# minimapshots.gd
# Close-ups of the top-right survey-chart map after walking a few places on
# floors 1 and 3, so its fit inside the frame can be checked.
# SHOT_DIR=<folder> xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 -s res://tools/minimapshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	for floor_num in [1, 3]:
		main.floor_number = floor_num
		main.generate_floor()
		main.player.health = 999
		# mark every room visited so the chart is full
		var n := 0
		for pos in main.dungeon_rooms:
			main.dungeon_rooms[pos].visited = true
			n += 1
		main.hud.update_minimap(main.dungeon_rooms, main.current_room_pos)
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		var mc: Control = main.hud.get_node("MinimapContainer")
		var r = mc.get_global_rect().grow(40).intersection(Rect2(Vector2.ZERO, img.get_size()))
		var crop = img.get_region(Rect2i(r))
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		if out != "":
			crop.save_png(out + "/minimap_floor%d.png" % floor_num)
			img.save_png(out + "/minimap_full_floor%d.png" % floor_num)
		print("SHOT floor ", floor_num, " rooms ", n, " rect ", mc.get_global_rect())
	quit()
