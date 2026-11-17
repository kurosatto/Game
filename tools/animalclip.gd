# animalclip.gd
# Records the era animals moving (calm, then fighting, then one killed) as
# numbered PNG frames for a video, to judge the Enemy.gd motion layer.
# Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> [FLOORS=1,2] godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/animalclip.gd
# then: ffmpeg -framerate 30 -i <folder>/f%05d.png -pix_fmt yuv420p clip.mp4
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
var n := 0
var cam: Camera2D
var look := Vector2.INF
func frame():
	# Follow the animals up close so their motion is readable
	var foes = root.get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.dead)
	if cam and foes.size() > 0:
		var c := Vector2.ZERO
		for e in foes: c += e.global_position
		c /= foes.size()
		look = c if look == Vector2.INF else look.lerp(c, 0.08)
		cam.zoom = Vector2(2.0, 2.0)
		cam.global_position = look
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
	img.save_png(out + "/f%05d.png" % n)
	n += 1
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	cam = main.get_viewport().get_camera_2d()
	var floors = [1, 2, 3, 4, 5]
	if OS.get_environment("FLOORS") != "":
		floors = Array(OS.get_environment("FLOORS").split(",")).map(func(s): return int(s))
	for floor_num in floors:
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
		var spots = [Vector2(1200, 420), Vector2(1420, 470), Vector2(1260, 640), Vector2(1450, 680)]
		for i in kinds.size():
			room.spawn_enemy(spots[i], kinds[i], floor_num)
		main.get_node("VisionFog").set_vision(10, true)
		main.hud.item_banner.visible = false
		var centre = room.global_position + Vector2(960, 540)
		look = Vector2.INF
		# Calm: the player keeps away and they idle
		for i in 90:
			p.global_position = room.global_position + Vector2(380, 540)
			p.health = 999
			await physics_frame
			if i % 2 == 0: await frame()
		for e in get_nodes_in_group("enemies"):
			if e.has_method("provoke"): e.provoke()
		# Fighting: the player circles the room so they chase and turn
		for i in 200:
			var a = i * 0.02
			p.global_position = centre + Vector2(cos(a) * 330.0 + 180.0, sin(a) * 200.0)
			p.health = 999
			p.invincibility_time = 1.0
			await physics_frame
			if i % 2 == 0: await frame()
		# Shove one from the side, then kill it, to show the flinch and death
		var foes = get_nodes_in_group("enemies").filter(func(e): return not e.dead)
		if foes.size() > 0:
			foes[0].apply_hit_push(Vector2(700, 0))
			foes[0].take_damage(0.5)
		for i in 20:
			await physics_frame
			if i % 2 == 0: await frame()
		if foes.size() > 1 and is_instance_valid(foes[1]):
			foes[1].take_damage(9999.0)
		for i in 50:
			await physics_frame
			if i % 2 == 0: await frame()
		print("CLIP floor ", floor_num, " frames ", n)
	quit()
