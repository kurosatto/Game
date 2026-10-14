# moodshots.gd
# Screenshots of animals minding their own business, then noticing the
# player ("!"), for one fight room per era. Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/moodshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	for floor_num in [1, 3, 5]:
		main.floor_number = floor_num
		main.generate_floor()
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and (pos - main.current_room_pos).length() == 1:
				main.current_room_pos = pos
				main.load_room(pos)
				break
		var room = main.current_room_node
		for e in get_nodes_in_group("enemies"):
			room.active_enemies.erase(e)
			e.queue_free()
		var kinds = ["fly", "pacer"] + preload("res://data/Fauna.gd").special_types(floor_num)
		var spots = [Vector2(1150, 330), Vector2(1450, 420), Vector2(1250, 720), Vector2(1500, 760)]
		for i in kinds.size():
			room.spawn_enemy(spots[i], kinds[i], floor_num)
			room.spawn_enemy(spots[i] + Vector2(-110, 70), kinds[i], floor_num)
		main.get_node("VisionFog").set_vision(10, true)
		main.hud.item_banner.visible = false
		for i in 150:
			p.global_position = room.global_position + Vector2(420, 540)
			p.health = 999
			await physics_frame
		await snap("era%d_calm" % floor_num)
		for i in 26:
			p.global_position = room.global_position + Vector2(920, 560)
			p.health = 999
			await physics_frame
		await snap("era%d_noticed" % floor_num)
	quit()
