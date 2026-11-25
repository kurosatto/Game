extends SceneTree
# drawhogs.gd: which nodes cost the most draw calls, over 4 rooms on every floor. Run with:
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 192x108 -s res://tools/drawhogs.gd
func _initialize():
	seed(1234)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	go(main)
func draws() -> int:
	for i in 3:
		await process_frame
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
var worst := {}
func probe(nodes: Array, base: int):
	for o in nodes:
		if not (o is CanvasItem) or not o.visible or not is_instance_valid(o):
			continue
		o.visible = false
		var d = await draws()
		if is_instance_valid(o):
			o.visible = true
		var key = "%s %s" % [o.get_class(), o.get_script().resource_path.get_file() if o.get_script() else o.name]
		if base - d > worst.get(key, 0):
			worst[key] = base - d
func go(main):
	for i in 20:
		await process_frame
	for f in range(1, 6):
		if f > 1:
			main.floor_number = f
			main.generate_floor()
			await draws()
		var n := 0
		for pos in main.dungeon_rooms:
			if n >= 4:
				break
			n += 1
			main.current_room_pos = pos
			main.load_room(pos)
			main.player.global_position = Vector2(960, 900)
			main.player.health = 99
			main.player.invincibility_time = 999.0
			var base = await draws()
			print("ROOM floor %d type %d special %s: %d draws" % [f, main.dungeon_rooms[pos].type, main.dungeon_rooms[pos].special, base])
			await probe(main.current_room_node.get_children(), base)
			await probe(main.get_children().filter(func(c): return c != main.current_room_node), base)
	var keys = worst.keys()
	keys.sort_custom(func(a, b): return worst[a] > worst[b])
	for k in keys:
		if worst[k] >= 4:
			print("WORST %4d %s" % [worst[k], k])
	quit()
