# runsshots.gd
# The past-runs page (MainMenu.show_past_runs, Progress.record_run) with a
# few made-up runs. Backs up and restores the real progress save. Needs a
# window for pictures:
#   SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/runsshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
const P = preload("res://data/Progress.gd")
func snap(n: String):
	if out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)
func _initialize():
	var path = ProjectSettings.globalize_path(P.SAVE_PATH)
	var backup = FileAccess.get_file_as_bytes(P.SAVE_PATH) if FileAccess.file_exists(P.SAVE_PATH) else PackedByteArray()
	if FileAccess.file_exists(P.SAVE_PATH):
		DirAccess.remove_absolute(path)
	P.record_run(2, "EARLY ARTHROPOD", false, {"path": ["ancestral_collar_cell", "early_arthropod"], "killer": "Anomalocaris", "kills": 31, "parts": 3})
	P.record_run(4, "SCORPION", false, {"path": ["ancestral_collar_cell", "early_arthropod", "chelicerate", "arachnid", "scorpion"], "killer": "an elder Meganeura", "kills": 88, "parts": 7})
	P.record_run(5, "SYNAPSID", true, {"path": ["ancestral_collar_cell", "pikaia_chordate", "jawed_fish", "lobe_finned_shorewalker", "synapsid"], "kills": 140, "parts": 10})
	var ok = P.history().size() == 3 and P.run_stats().count == 3 and P.history()[1].killer == "an elder Meganeura"
	print("RUNS saved: ", ok)
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 20: await process_frame
	await snap("1_menu_runs_line")
	menu.show_past_runs()
	for i in 10: await process_frame
	await snap("2_past_runs")
	print("RUNS page rows: ", menu.overlay != null)
	# Put the real save back
	DirAccess.remove_absolute(path)
	if backup.size() > 0:
		var f = FileAccess.open(P.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	print("RUNS done, %s" % ("0 failures" if ok else "1 failures"))
	quit()
