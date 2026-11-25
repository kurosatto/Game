# flickerclip.gd
# Saves a run of consecutive frames from a fight room, to look for flashing.
# FLOOR=5 WORLD=land|sea FINALE=1 ROOM=<n> START=<frame> COUNT=<n> STEP=<n> SHOT_DIR=<dir> xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/flickerclip.gd
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
var out := OS.get_environment("SHOT_DIR")

func env(k: String, d: int) -> int:
	return int(OS.get_environment(k)) if OS.get_environment(k) != "" else d

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	Worlds.sea = OS.get_environment("WORLD") == "sea"
	Worlds.finale = OS.get_environment("FINALE") == "1"
	var p = main.player
	p.max_health = 999
	p.health = 999
	main.floor_number = env("FLOOR", 5)
	main.generate_floor()
	for i in 10: await process_frame
	var fights = main.dungeon_rooms.keys().filter(func(k): return main.dungeon_rooms[k].type == 1)
	var pos = fights[min(env("ROOM", 0), fights.size() - 1)]
	main.current_room_pos = pos
	main.load_room(pos)
	main.get_node("VisionFog").set_vision(10, true)
	var start = env("START", 60)
	var count = env("COUNT", 12)
	var step = env("STEP", 1)
	for i in start + count * step:
		await RenderingServer.frame_post_draw
		p.health = 999
		if OS.get_environment("HOLD") != "":
			p.global_position = Vector2(960, 800)
		if i >= start and (i - start) % step == 0:
			root.get_texture().get_image().save_png("%s/clip_%03d.png" % [out, (i - start) / step])
	quit()
