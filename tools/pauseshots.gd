# pauseshots.gd
# Screenshots of the pause screen at PC and phone shapes, as the starting cell
# and as an evolved form with adaptations, one with a picture tapped. Needs a
# window (xvfb-run on Linux):
#   SHOT_DIR=<folder> godot --path . --resolution 1920x1080 -s res://tools/pauseshots.gd
# SHOT_TAG names the shape (pc, phone) in the file names.
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
var tag := OS.get_environment("SHOT_TAG")
func snap(name: String):
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.hud.show_item_banner("PIKAIA CHORDATE", "One of the earliest chordates, with a notochord stiffening its body.")
	main.hud.toggle_settings()
	await snap("cell_" + tag)
	main.hud.toggle_settings()
	# Evolve three times and pick up some adaptations
	for f in range(1, 4):
		main.player.apply_evolution(f, 0)
	main.floor_number = 4
	main.hud.update_floor(4)
	for id in ["muscle", "muscle", "toxins", "armour", "senses", "regeneration", "electrocytes", "gut"]:
		main.player.grant_adaptation(id)
	main.hud.toggle_settings()
	await snap("evolved_" + tag)
	main.hud._on_pause_tile_picked(main.hud.pause_wildlife.get_child(1))
	await snap("evolved_tapped_" + tag)
	quit()
