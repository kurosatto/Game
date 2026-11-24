# journalshots.gd
# Screenshots of the small tag that replaces the big fact banner during play,
# and the pause screen's FIELD JOURNAL with an entry opened. Needs a window:
#   SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/journalshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(n: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)
func _initialize():
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var hud = main.hud
	var items = preload("res://data/Items.gd")
	var it = items.get_item("nematocysts")
	hud.show_item_banner(it.name.to_upper(), it.effect + "\n" + it.fact, false, -1.0, it.effect)
	hud.show_item_banner("BRINE POOL", "Brine pools are lakes of super-salty water on the seafloor, so dense they have shores and waves.\nWading through it slows you down.", true, -1.0, "Slows you down")
	for i in 20: await process_frame
	await snap("1_tag_in_play")
	hud.toggle_settings()
	for i in 10: await process_frame
	var b: Button = hud.pause_journal.get_child(1)
	b.pressed.emit()
	for i in 10: await process_frame
	await snap("2_pause_journal")
	print("JOURNAL entries: ", hud.journal.size(), " buttons: ", hud.pause_journal.get_child_count(), " info: ", hud.pause_info_title.text)
	quit()
