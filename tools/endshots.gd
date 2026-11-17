# endshots.gd
# Game over and victory screens after a run through four evolutions, to
# check the lineage strip (HUD.add_lineage_strip). Needs a window:
# SHOT_DIR=<folder> xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/endshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 50: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	var p = main.player
	var picks = [3, 0, 0, 0] # arthropod line
	for f in 4:
		p.apply_evolution(f + 1, picks[f])
		await process_frame
	main.floor_number = 5
	main.hud.show_victory(p.get_evolution_summary())
	await snap("victory")
	main.hud.victory_screen.visible = false
	p.kills = 140
	main._on_player_died()
	await snap("gameover")
	quit()
