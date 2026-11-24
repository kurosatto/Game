# worldtest.gd
# Checks the sea and land worlds of floors 4 and 5 (data/Worlds.gd):
#  - every playable form gets the right world (land, sea, or a choice)
#  - an amphibious form gets two trapdoors and each leads to its world
#  - each world's rooms use their own art, animals, bosses and special rooms
# With SHOT_DIR set (and a window, e.g. xvfb-run) it also saves a fight room
# of each world, the trapdoor choice and the era page.
#   godot --headless --path . -s res://tools/worldtest.gd
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
const Fauna = preload("res://data/Fauna.gd")
const SR = preload("res://data/SpecialRooms.gd")
var out := OS.get_environment("SHOT_DIR")
var fails := 0

func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("FAIL ", what)

func snap(name: String):
	if out == "":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _initialize():
	run()

func run():
	# 1. Habitats of the forms that play floors 4 and 5
	var L = load("res://data/Lineages.gd")
	for path in L.TREE:
		var depth = 0 if path == "" else path.split(",").size()
		if depth < 3 or not L.TREE[path].has("id"):
			continue
		var id = L.TREE[path].id
		var h = Worlds.habitat(id)
		var floor_num = depth + 1
		if floor_num > 5:
			continue
		print("WORLD floor %d %-26s %s" % [floor_num, id, h])
	check(Worlds.sea_for(4, "scorpion") == false, "scorpion goes to land")
	check(Worlds.sea_for(4, "nautilus") == true, "nautilus goes to sea")
	check(Worlds.sea_for(5, "lissamphibian", "land") == false, "amphibian picks land")
	check(Worlds.sea_for(5, "lissamphibian", "sea") == true, "amphibian picks sea")
	check(Worlds.sea_for(3, "scorpion") == true, "era 3 is all sea")

	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame

	# 2. The trapdoor choice for an amphibious form
	main.floor_number = 3
	main.generate_floor()
	for i in 5: await process_frame
	main.player.evolution_choices = [0, 0, 0] # lobe-finned shorewalker
	main.current_room_node.spawn_trapdoor()
	await process_frame
	var doors = main.current_room_node.get_children().filter(func(n): return n.has_meta("world"))
	check(doors.size() == 2, "shore form gets two trapdoors (got %d)" % doors.size())
	main.player.global_position = main.current_room_node.global_position + Vector2(960, 760)
	main.get_node("VisionFog").set_vision(10, true)
	for i in 30: await process_frame
	main.hud.item_banner.visible = false
	await snap("world_trapdoors")
	main.advance_floor("land")
	for i in 70: await process_frame
	check(main.floor_number == 4 and not Worlds.sea, "the land trapdoor leads to the land world")
	check(main.current_room_node.era_dir().ends_with("/carboniferous/"), "land world art")
	for d in doors:
		if is_instance_valid(d):
			d.queue_free()

	# 3. Each world of floors 4 and 5
	for floor_num in [4, 5]:
		for sea in [true, false]:
			main.floor_number = floor_num
			Worlds.sea = sea
			main.generate_floor()
			var era = Worlds.era(floor_num)
			check(era == (floor_num + 2 if sea else floor_num), "era key")
			var names = Fauna.era_species(floor_num).map(func(f): return f.name)
			check(main.current_room_node.era_dir().ends_with("_sea/") == sea, "room art for era %d" % era)
			for k in SR.kinds_for(floor_num):
				check(not (sea and k == "fire"), "no wildfire at sea")
			# Visit the fight rooms: every animal must belong to this world
			var seen := {}
			for pos in main.dungeon_rooms:
				var r = main.dungeon_rooms[pos]
				if r.type != 1:
					continue
				main.current_room_pos = pos
				main.load_room(pos)
				for i in 3: await process_frame
				for e in main.current_room_node.active_enemies:
					if is_instance_valid(e) and e.get("fauna_name") != null and e.fauna_name != "":
						seen[e.fauna_name] = true
						check(e.fauna_name in names or e.fauna_name in ["Charnia"], "%s belongs in era %d" % [e.fauna_name, era])
			print("WORLD era %d animals met: %s" % [era, seen.keys()])
			# A fight room to look at
			for pos in main.dungeon_rooms:
				if main.dungeon_rooms[pos].type == 1 and main.dungeon_rooms[pos].special == "":
					main.current_room_pos = pos
					main.load_room(pos)
					break
			main.player.global_position = main.current_room_node.global_position + Vector2(760, 560)
			main.player.reset_physics_interpolation()
			main.player.health = 999
			main.get_node("VisionFog").set_vision(10, true)
			for i in 60: await process_frame
			main.hud.item_banner.visible = false
			await snap("world_era%d_room" % era)
			var boss_script = main.current_room_node.pick_boss_script(floor_num)
			print("WORLD era %d boss %s" % [era, boss_script])
			check(sea == (boss_script.contains("Edestus") or boss_script.contains("Helicoprion") or boss_script.contains("DrawnBoss")) or not sea, "sea boss")
			if out != "":
				main.hud.show_era_card(floor_num, main.current_form())
				await create_timer(0.6, true).timeout
				await snap("world_era%d_page" % era)
				var k = InputEventKey.new()
				k.pressed = true
				k.keycode = KEY_SPACE
				k.physical_keycode = KEY_SPACE
				Input.parse_input_event(k)
				for i in 3: await process_frame
				check(not paused, "era page closes")
	print("WORLDTEST done, %d failures" % fails)
	quit(1 if fails > 0 else 0)
