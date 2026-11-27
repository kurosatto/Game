# lineagelocks.gd
# Lineages open through challenges: checks the locks, and with SHOT_DIR set
# screenshots the challenges page and an evolution split with locked cards.
# Backs up and restores the real save.
#   SHOT_DIR=<folder> xvfb-run godot --path . --rendering-driver opengl3 --resolution 2340x1080 -s res://tools/lineagelocks.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
var fails := 0
func check(ok: bool, what: String):
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func snap(name: String):
	if out == "": return
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var P = load("res://data/Progress.gd")
	var L = load("res://data/Lineages.gd")
	var path = ProjectSettings.globalize_path(P.SAVE_PATH)
	var backup = FileAccess.get_file_as_bytes(P.SAVE_PATH) if FileAccess.file_exists(P.SAVE_PATH) else PackedByteArray()
	DirAccess.remove_absolute(path)
	# Every challenge opens a real branch, and every split keeps one open
	for c in P.CHALLENGES:
		check(L.has_form(c.lineage), "%s opens a real form (%s)" % [c.id, c.lineage])
	var keys: Array = L.TREE.keys()
	keys.append("")
	for k in L.TREE:
		var kids = L.get_child_paths(k)
		if kids.is_empty(): continue
		check(kids.any(func(p): return P.lineage_open(p)), "split after '%s' has an open branch on a fresh save" % k)
	check(P.lineage_open("3") and not P.lineage_open("2") and not P.lineage_open("0"), "fresh save: arthropods only")
	P.complete("arthropod")
	check(P.lineage_open("2"), "Jointed Legs opens molluscs")
	check(load("res://data/Progress.gd").new().has_method("start_trait") == false, "starting traits are gone")
	for i in 5: await process_frame
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 20: await process_frame
	menu.show_challenges()
	await snap("challenges")
	var tile = menu.overlay.find_children("*", "Control", true, false).filter(func(n): return n.has_signal("picked"))
	check(tile.size() == P.CHALLENGES.size(), "one tile per challenge")
	tile[1].picked.emit(tile[1])
	await snap("challenges_tapped")
	menu.close_overlay()
	menu.show_more()
	await snap("more")
	menu.queue_free()
	for i in 3: await process_frame
	# An evolution split with locked branches
	P.test_locks = true
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	main.hud.show_evolution_modal(1, [])
	for i in 20: await process_frame
	var btns = main.hud.evolution_modal.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("🔒"))
	check(btns.size() == 2, "first split shows 2 locked cards (%d)" % btns.size())
	check(btns.all(func(b): return b.disabled), "locked cards can't be picked")
	await snap("evolution_locked")
	P.test_locks = false
	DirAccess.remove_absolute(path)
	if not backup.is_empty():
		var f = FileAccess.open(P.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
	print("FAILS ", fails)
	quit()
