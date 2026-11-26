# artshadowshots.gd
# Close-up of a few animals and a boss in the current art style, for checking
# drop shadows and colour wash (2026-11-26). Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> [STYLE=sepia] godot --path . --rendering-driver opengl3 -s res://tools/artshadowshots.gd
extends SceneTree
const Worlds = preload("res://data/Worlds.gd")
var out := OS.get_environment("SHOT_DIR")
func _initialize():
	var settings = root.get_node("SettingsManager")
	var style := OS.get_environment("STYLE")
	if style != "":
		settings.set_art_style(style)
	seed(7)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	p.health = 999
	for era in [1, 6]:
		Worlds.sea = era >= 6
		Worlds.finale = false
		main.floor_number = era - 2 if era >= 6 else era
		main.generate_floor()
		for i in 10: await process_frame
		for e in get_nodes_in_group("enemies"): e.queue_free()
		await process_frame
		var room = main.current_room_node
		var c: Vector2 = room.global_position + Vector2(960, 540)
		p.global_position = c
		p.set_physics_process(false)
		var kinds: Array = ["frond", "tank", "fly"] if era == 1 else ["fly", "pacer", "charger", "skittish"]
		var i := 0
		for k in kinds:
			var spot = c + Vector2(-330 + 220 * i, -170 if i % 2 == 0 else 170)
			room.spawn_enemy(spot, k, 1)
			i += 1
		for e in get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		main.get_node("VisionFog").set_vision(10, true)
		for f in 40: await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.get_region(Rect2i(420, 220, 1080, 640)).save_png(out + "/era%d.png" % era)
		print("SHOT era%d" % era)
	quit()
