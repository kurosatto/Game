# seepshots.gd
# Screenshots of the mineral seep side room (MineralSeep.gd) in a sea era
# and a land era, before and after it is used. Needs a window:
# SHOT_DIR=<folder> xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/seepshots.gd
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
	for floor_num in [2, 5]:
		main.floor_number = floor_num
		main.generate_floor()
		var seep_pos = null
		for pos in main.dungeon_rooms:
			if main.dungeon_rooms[pos].type == 5:
				seep_pos = pos
		if seep_pos == null:
			print("SEEPTEST: no seep on floor ", floor_num)
			continue
		main.current_room_pos = seep_pos
		main.load_room(seep_pos)
		main.get_node("VisionFog").set_vision(10, true)
		main.hud.item_banner.visible = false
		p.health = 2
		for i in 40:
			p.global_position = Vector2(500, 540)
			await physics_frame
		await snap("seep_era%d" % floor_num)
		var before = p.elements.duplicate() if "elements" in p else {}
		for i in 60:
			p.global_position = Vector2(960, 560)
			await physics_frame
		print("SEEPTEST: floor %d health %d elements %s -> %s used %s" % [floor_num, p.health, before, p.elements if "elements" in p else "?", main.dungeon_rooms[seep_pos].seep_used])
		await snap("seep_era%d_used" % floor_num)
	quit()
