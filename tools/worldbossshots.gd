# worldbossshots.gd
# Close-up pictures of the bosses of the sea and land worlds of floors 4
# and 5 (data/Worlds.gd), each at rest and winding up an attack.
# SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/worldbossshots.gd
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
var out := OS.get_environment("SHOT_DIR")

func snap(name: String, center: Vector2):
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	var r = Rect2i(Vector2i(center) - Vector2i(450, 300), Vector2i(900, 600))
	img.get_region(r).save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var cases = [
		[4, true, "res://bosses/Edestus.gd", "shear_wind"],
		[5, true, "res://bosses/Helicoprion.gd", "saw_wind"],
		[4, true, "res://bosses/DrawnBoss.gd", ""],
		[5, true, "res://bosses/DrawnBoss.gd", ""],
		[4, false, "res://bosses/DrawnBoss.gd", ""],
	]
	for c in cases:
		Worlds.sea = c[1]
		main.floor_number = c[0]
		main.generate_floor()
		for i in 10: await process_frame
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var boss = load(c[2]).new()
		boss.position = Vector2(960, 540)
		boss.setup_enemy(c[0])
		main.current_room_node.add_child(boss)
		main.register_boss(boss)
		boss.facing = Vector2(1, 0.25).normalized()
		main.player.global_position = main.current_room_node.global_position + Vector2(1500, 900)
		main.get_node("VisionFog").set_vision(10, true)
		for i in 40: await process_frame
		main.hud.item_banner.visible = false
		var at = boss.global_position
		var nm = boss.killer_name().to_lower()
		await snap("%s_rest" % nm, at)
		if c[3] != "":
			boss.set_state(c[3])
			for i in 30: await process_frame
			await snap("%s_attack" % nm, boss.global_position)
		boss.take_damage(99999.0)
		for i in 20: await process_frame
	quit()
