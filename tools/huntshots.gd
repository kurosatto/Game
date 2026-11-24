# huntshots.gd
# Screenshots of a hunt per era: the hunter closing in on fleeing prey, then
# feeding where it caught it (data/FoodWeb.gd). Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/huntshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
const PAIRS = {2: ["pacer@Sanctacaris", "skittish@Marrella"], 3: ["pacer@Megalograptus", "armoured@Lunataspis"], 4: ["fly@Meganeura", "swarm@Archimylacris"], 5: ["pacer@Inostrancevia", "fly@Lystrosaurus"]}
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
	for floor_num in PAIRS:
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
		room.spawn_enemy(Vector2(1000, 420), PAIRS[floor_num][0], floor_num)
		room.spawn_enemy(Vector2(1380, 640), PAIRS[floor_num][1], floor_num)
		var hunter = get_nodes_in_group("enemies").filter(func(e): return not e.is_queued_for_deletion() and e.is_hunter())[0]
		main.get_node("VisionFog").set_vision(10, true)
		main.hud.item_banner.visible = false
		var chased := false
		for i in 60 * 25:
			p.global_position = room.global_position + Vector2(260, 540)
			p.stealth = 0.2
			p.health = 999
			p.invincibility_time = 99.0
			await physics_frame
			if not chased and is_instance_valid(hunter.hunt_target) and hunter.global_position.distance_to(hunter.hunt_target.global_position) < 260.0:
				chased = true
				await snap("era%d_1_chase" % floor_num)
			if hunter.meals > 0:
				for k in 20: await physics_frame
				await snap("era%d_2_feeding" % floor_num)
				break
	quit()
