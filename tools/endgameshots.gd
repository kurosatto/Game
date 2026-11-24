# endgameshots.gd
# Pictures of the main menu and its ENDGAME page (data/Endgame.gd), locked
# and (with ENDGAME=1) open.
# SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/endgameshots.gd
extends SceneTree

var out := OS.get_environment("SHOT_DIR")

func snap(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _initialize():
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 30: await process_frame
	var tag = "open" if OS.get_environment("ENDGAME") == "1" else "locked"
	await snap("menu_" + tag)
	menu.show_endgame()
	for i in 30: await process_frame
	await snap("endgame_" + tag)
	quit()
