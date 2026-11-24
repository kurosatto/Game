# lairshots.gd
# Pictures of the secret lair giants (data/Endgame.gd LAIRS): each at rest,
# winding up, and Megarachne after the spider falls away.
# SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/lairshots.gd
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
var out := OS.get_environment("SHOT_DIR")

func snap(name: String, center: Vector2, size: Vector2i = Vector2i(900, 600)):
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	var r = Rect2i(Vector2i(center) - size / 2, size)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	main.player.max_health = 999
	main.player.health = 999
	var cases = [
		[false, "res://bosses/Megarachne.gd", ["rake_wind"]],
		[true, "res://bosses/Saivodus.gd", ["bite_wind", "tail_wind"]],
	]
	for c in cases:
		Worlds.sea = c[0]
		main.floor_number = 4
		main.generate_floor()
		for i in 10: await process_frame
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var boss = load(c[1]).new()
		boss.position = Vector2(960, 540)
		boss.setup_enemy(4)
		main.current_room_node.add_child(boss)
		main.register_boss(boss)
		boss.facing = Vector2(1, 0.25).normalized()
		main.player.global_position = boss.global_position + Vector2(420, 300)
		main.get_node("VisionFog").set_vision(10, true)
		var at = boss.global_position
		for i in 60:
			await process_frame
			boss.global_position = at
		main.hud.item_banner.visible = false
		var nm = boss.killer_name().to_lower()
		await snap("%s_rest" % nm, boss.global_position)
		await snap("%s_room" % nm, Vector2(960, 540), Vector2i(1920, 1080))
		for st in c[2]:
			boss.set_state(st)
			boss.state_time = 0.0
			for i in 25:
				await process_frame
				boss.global_position = at
				main.player.global_position = at + Vector2(420, 300)
			await snap("%s_%s" % [nm, st.trim_suffix("_wind")], boss.global_position)
			boss.set_state("intro")
			for i in 30: await process_frame
		if not c[0]:
			# Half health: the 1980 spider falls away
			boss.take_damage(boss.max_health * 0.55)
			for i in 120: await process_frame
			main.hud.item_banner.visible = false
			await snap("%s_moult" % nm, boss.global_position, Vector2i(1100, 700))
		boss.take_damage(99999.0)
		for i in 20: await process_frame
	quit()
