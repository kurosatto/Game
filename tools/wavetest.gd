# wavetest.gd
# Headless check of second waves (Room.start_wave): clearing a room with a
# wave left brings animals in through the doors instead of opening them;
# clearing those opens the room. Run:
#   godot --headless --path . -s res://tools/wavetest.gd
extends SceneTree
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	main.floor_number = 3
	main.generate_floor()
	for pos in main.dungeon_rooms:
		if main.dungeon_rooms[pos].type == 1 and main.dungeon_rooms[pos].special == "":
			main.current_room_pos = pos
			main.load_room(pos)
			break
	for i in 5: await physics_frame
	var room = main.current_room_node
	room.room_data.waves_left = 1
	var fails = 0
	for e in room.active_enemies.duplicate():
		e.take_damage(9999)
	for i in 30:
		p.health = 6
		await physics_frame
	print("WAVETEST: after first clear: cleared=%s pending=%s" % [room.room_data.cleared, room.wave_pending])
	if room.room_data.cleared:
		fails += 1
	for i in 85:
		p.health = 6
		await physics_frame
	if OS.get_environment("SHOT_DIR") != "":
		main.get_node("VisionFog").set_vision(10, true)
		main.hud.item_banner.visible = false
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/wave.png")
	var n = room.active_enemies.size()
	print("WAVETEST: wave arrived with %d animals" % n)
	if n == 0:
		fails += 1
	for e in room.active_enemies.duplicate():
		if is_instance_valid(e):
			e.take_damage(9999)
	for i in 60:
		p.health = 6
		await physics_frame
	print("WAVETEST: cleared after wave: %s, waves left %d" % [room.room_data.cleared, room.room_data.waves_left])
	if not room.room_data.cleared:
		fails += 1
	print("WAVETEST: done, %d failures" % fails)
	quit(fails)
