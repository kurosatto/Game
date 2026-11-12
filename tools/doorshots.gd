# doorshots.gd
# Doors through the vision fog and ink filter in each era: open, shut and
# locked side by side. Needs a window, not --headless.
# Run: SHOT_DIR=<folder> godot --path . -s res://tools/doorshots.gd
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
	for i in 30: await process_frame
	main.get_node("TouchControls").visible = true
	main.hud.use_touch_texts()
	var floors = [1, 3, 5]
	var env_floors = OS.get_environment("DOOR_FLOORS")
	if env_floors != "":
		floors = Array(env_floors.split(",")).map(func(s): return int(s))
	for f in floors:
		main.floor_number = f
		main.generate_floor()
		for i in 20: await process_frame
		var room = main.current_room_node
		var dirs = room.door_nodes.keys()
		# Show one of each state where the room has enough doors
		for i in dirs.size():
			var d = room.door_nodes[dirs[i]]
			if i == 1:
				d.close_door()
			elif i == 2:
				d.lock_door()
		for i in 20: await process_frame
		await snap("doors_era%d" % f)
	quit()
