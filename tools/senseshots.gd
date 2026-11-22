# senseshots.gd
# The sense marks for every non-visual sense, with a nearly blind form so the
# room's animals sit in the dark. Needs a window, not --headless.
# Run: SHOT_DIR=<folder> SHOT_SIZE=2340x1080 godot --path . -s res://tools/senseshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var size_env := OS.get_environment("SHOT_SIZE")
	if size_env != "":
		var parts = size_env.split("x")
		for i in 5: await process_frame
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		for i in 5: await process_frame
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		for i in 10: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var hud = main.get("hud")
	for c in hud.get_children() if hud else []:
		if c is Control and c.name.contains("Card"):
			c.visible = false
	var p = main.player
	for pos in main.dungeon_rooms:
		if main.dungeon_rooms[pos].type == 1 and (pos - main.current_room_pos).length() == 1:
			main.current_room_pos = pos
			main.load_room(pos)
			break
	var room = main.current_room_node
	for e in get_nodes_in_group("enemies"):
		room.active_enemies.erase(e)
		e.queue_free()
	await process_frame
	for spot in [Vector2(1700, 250), Vector2(250, 850), Vector2(1650, 880), Vector2(300, 220)]:
		room.spawn_enemy(spot, "pacer", 1)
	for i in 5: await physics_frame
	for e in get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = room.global_position + Vector2(960, 540)
	p.health = 999
	main.hud.item_banner.visible = false
	for i in 20: await process_frame
	var fog = main.get_node("VisionFog")
	fog.set_vision(1, true)
	var styles = OS.get_environment("SHOT_STYLES")
	for st in (styles.split(",") if styles != "" else PackedStringArray(["sepia"])):
		var settings = root.get_node("SettingsManager")
		var before: String = settings.art_style
		settings.set_art_style(st)
		for kind in ["Smell", "Chemical sense", "Electroreception", "Lateral line", "Vibration", "Touch"]:
			fog.set_sense(7, kind)
			fog.hints.sensed_any = false
			for i in 12: await process_frame
			await snap("%s_%s" % [st, kind.to_lower().replace(" ", "_")])
		settings.set_art_style(before)
	quit()
