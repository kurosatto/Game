# healthshots.gd
# In-room screenshot of the health pickups and HUD pips. HP_DIR (optional)
# points at a folder with alternative pickup_heart*.png to try out.
#   HP_DIR=<dir> SHOT=<file.png> godot --path . --resolution 1920x1080 -s res://tools/healthshots.gd
extends SceneTree
func tex(dir: String, name: String, fallback: Texture2D) -> Texture2D:
	if dir == "":
		return fallback
	return ImageTexture.create_from_image(Image.load_from_file(dir + "/" + name + ".png"))
func _initialize():
	for i in 5: await process_frame
	var dir := OS.get_environment("HP_DIR")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var room = main.current_room_node
	for e in room.active_enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	var hud = main.hud
	hud.heart_full_tex = tex(dir, "pickup_heart", hud.heart_full_tex)
	hud.heart_half_tex = tex(dir, "pickup_heart_half", hud.heart_half_tex)
	hud.heart_empty_tex = tex(dir, "pickup_heart_empty", hud.heart_empty_tex)
	p.health = 5
	hud.update_health(5, p.max_health)
	var full_t = tex(dir, "pickup_heart", null)
	var half_t = tex(dir, "pickup_heart_half", null)
	var pickups = []
	var spots = [Vector2(-170, -40), Vector2(170, -40), Vector2(0, -170)]
	for i in 3:
		var pk = load("res://Pickup.tscn").instantiate()
		pk.pickup_type = "heart_half" if i == 2 else "heart"
		pk.position = room.to_local(p.global_position) + spots[i]
		room.add_child(pk)
		pickups.append(pk)
	for i in 60: await process_frame
	if dir != "":
		for pk in pickups:
			pk.get_node("Sprite2D").texture = full_t if pk.pickup_type == "heart" else half_t
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
	print("SHOT saved")
	quit()
