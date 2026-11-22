# styleshots.gd
# Every art style (data/ArtStyles.gd) in a fight room of each chosen era, plus
# the main menu and its style picker. Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> [ERAS=2,4] [STYLES=neon,...] godot --path . --rendering-driver opengl3 -s res://tools/styleshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var settings = root.get_node("SettingsManager")
	var before: String = settings.art_style
	var styles: Array = preload("res://data/ArtStyles.gd").ids()
	if OS.get_environment("STYLES") != "":
		styles = Array(OS.get_environment("STYLES").split(","))
	var eras: Array = [2, 4]
	if OS.get_environment("ERAS") != "":
		eras = Array(OS.get_environment("ERAS").split(",")).map(func(e): return int(e))
	for i in 5: await process_frame
	if OS.get_environment("NO_MENU") == "":
		var menu = load("res://MainMenu.tscn").instantiate()
		root.add_child(menu)
		for i in 20: await process_frame
		for id in styles:
			settings.set_art_style(id)
			await snap("menu_" + id)
		menu.show_art_styles()
		for i in 10: await process_frame
		await snap("style_picker")
		menu.queue_free()
		for i in 3: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	for floor_num in eras:
		main.floor_number = floor_num
		main.generate_floor()
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and (pos - main.current_room_pos).length() == 1:
				main.current_room_pos = pos
				main.load_room(pos)
				break
		main.player.global_position = Vector2(760, 560)
		main.player.reset_physics_interpolation()
		main.player.health = 999
		main.get_node("VisionFog").set_vision(7, true)
		for i in 60: await process_frame
		main.hud.item_banner.visible = false
		# Freeze the room so every style shows the same moment
		main.current_room_node.process_mode = Node.PROCESS_MODE_DISABLED
		main.player.process_mode = Node.PROCESS_MODE_DISABLED
		for id in styles:
			settings.set_art_style(id)
			await snap("era%d_%s" % [floor_num, id])
		main.current_room_node.process_mode = Node.PROCESS_MODE_INHERIT
		main.player.process_mode = Node.PROCESS_MODE_INHERIT
	settings.set_art_style(before)
	quit()
