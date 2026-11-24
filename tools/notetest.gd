# notetest.gd
# Field notes (data/FieldNotes.gd): every era's two goals can be finished,
# each pays out orbs, and the pause screen lists them. Headless:
#   godot --headless --path . -s res://tools/notetest.gd
# With SHOT_DIR set (and a window) it also saves the banners:
#   SHOT_DIR=<folder> xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/notetest.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	if out == "":
		return
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	main.floor_number = 2
	main.generate_floor()
	await snap("notes_floor_banner")
	var fails = 0
	for f in [1, 2, 3, 4, 5]:
		main.floor_number = f
		main.notes_progress = {}
		for n in main.field_notes.for_floor(f):
			for k in n.need:
				main.field_event(n.event)
			await process_frame
		var d = main.field_notes.describe(f, main.notes_progress)
		print("NOTES floor %d: %s" % [f, d.replace("\n", " | ")])
		if d.count("✓") != 2:
			fails += 1
		if f == 2:
			await snap("notes_done_banner")
	var orbs = main.current_room_node.get_children().filter(func(c): return c.get_script() == preload("res://BiomassOrb.gd")).size()
	print("NOTES orbs in room: ", orbs)
	if orbs < 6:
		fails += 1
	main.hud.toggle_settings()
	await process_frame
	print("NOTES pause: ", main.hud.pause_info_body.text.replace("\n", " | "))
	if not "Floor quests" in main.hud.pause_info_body.text:
		fails += 1
	await snap("notes_pause")
	print("NOTES done, %d failures" % fails)
	quit()
