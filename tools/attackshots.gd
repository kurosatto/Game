# attackshots.gd
# Close-ups of each attack style mid-strike in a real room, with a target in
# reach, pasted into one grid (attacks.png): one row per form, three moments
# of the strike across. Needs a window (xvfb-run on Linux) and --fixed-fps:
#   SHOT_DIR=<folder> godot --fixed-fps 60 --path . --rendering-driver opengl3 -s res://tools/attackshots.gd
# FORMS=id,id,... picks other forms.
extends SceneTree
const CELL := Vector2i(420, 260)
const MOMENTS := [2, 5, 9]
var out := OS.get_environment("SHOT_DIR")
func _initialize():
	var lineages = load("res://data/Lineages.gd")
	var by_id := {}
	for path in lineages.TREE:
		by_id[lineages.TREE[path].id] = lineages.TREE[path]
	var ids := ["ancestral_collar_cell", "jawed_fish", "decapod", "early_arthropod", "pikaia_chordate",
		"scorpion", "octopus_line", "lissamphibian", "sea_urchin", "mantis_shrimp_line",
		"giant_clam", "lamprey", "teleost_line", "cone_snail", "spider", "sauropsid", "beetle", "hagfish"]
	if OS.get_environment("FORMS") != "":
		ids = Array(OS.get_environment("FORMS").split(","))
	for i in 5: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.get_node("VisionFog").set_vision(10, true)
	var player = main.player
	var spawn: Vector2 = player.global_position
	var grid := Image.create(CELL.x * MOMENTS.size(), CELL.y * ids.size(), false, Image.FORMAT_RGBA8)
	for n in ids.size():
		player.apply_form(by_id[ids[n]])
		player.invincibility_time = 0.0
		player.health = 99
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		player.global_position = spawn
		player.reset_physics_interpolation()
		var prey = load("res://Enemy.tscn").instantiate()
		prey.enemy_type = "pacer"
		prey.position = spawn + Vector2(120, 0)
		main.current_room_node.add_child(prey)
		prey.setup_enemy(1)
		prey.speed = 0.0
		prey.health = 9999.0
		prey.max_health = 9999.0
		for i in 12: await process_frame
		player.shoot_cooldown = 0.0
		player.shoot_tear(Vector2.RIGHT)
		var f := 0
		for m in MOMENTS.size():
			while f < MOMENTS[m]:
				await process_frame
				f += 1
			await RenderingServer.frame_post_draw
			var img = root.get_texture().get_image()
			var sp: Vector2 = player.get_global_transform_with_canvas().origin
			sp *= Vector2(img.get_size()) / root.get_visible_rect().size
			var crop = img.get_region(Rect2i(int(sp.x) - 110, int(sp.y) - CELL.y / 2, CELL.x, CELL.y))
			grid.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL), Vector2i(m * CELL.x, n * CELL.y))
		if is_instance_valid(prey):
			prey.queue_free()
		for t in get_nodes_in_group("player_tears"):
			t.queue_free()
		print("FORM ", ids[n])
	grid.save_png(out + "/attacks.png")
	print("SHOT attacks")
	quit()
