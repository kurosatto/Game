# sceneryshots.gd
# Fight rooms with the fog lifted, to judge the room scenery: its colours per
# floor and its layouts. Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> [ERAS=1,2] [STYLES=sepia,neon] [LAYOUTS=0,17] godot --path . --rendering-driver opengl3 -s res://tools/sceneryshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func env_list(key: String, fallback: Array) -> Array:
	if OS.get_environment(key) == "":
		return fallback
	return Array(OS.get_environment(key).split(","))
func snap(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var settings = root.get_node("SettingsManager")
	var before: String = settings.art_style
	var styles = env_list("STYLES", ["sepia"])
	var eras = env_list("ERAS", ["1", "2", "3", "4", "5"]).map(func(e): return int(e))
	var layouts = env_list("LAYOUTS", ["0"]).map(func(e): return int(e))
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	for floor_num in eras:
		main.floor_number = floor_num
		main.generate_floor()
		var room_pos = main.current_room_pos
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and r.special == "" and (pos - main.current_room_pos).length() == 1:
				room_pos = pos
				break
		var rd = main.dungeon_rooms[room_pos]
		for li in layouts:
			for id in styles:
				settings.set_art_style(id)
				seed(floor_num * 1000 + li)
				rd.layout_idx = li
				rd.has_initialized_contents = false
				main.current_room_pos = room_pos
				main.load_room(room_pos)
				main.player.global_position = Vector2(960, 540)
				main.player.reset_physics_interpolation()
				main.player.health = 999
				main.get_node("VisionFog").set_vision(12, true)
				for i in 40: await process_frame
				main.hud.item_banner.visible = false
				await snap("era%d_l%d_%s" % [floor_num, li, id])
	settings.set_art_style(before)
	quit()
