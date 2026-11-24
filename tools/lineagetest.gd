# lineagetest.gd
# Checks the main menu GROW page (LineageGrow.gd, Progress lineage/bank):
# ranks cost the bank and stop at the cap, healing parts can't be grown into
# the lineage, a run starts with every rank (Main.apply_lineage), in-run
# growing is only healing, what you eat is banked (Main.flush_bank), and
# arthropods molt into each era. Backs up and restores the real save.
# Screenshots with SHOT_DIR (xvfb).
#   godot --headless --path . -s res://tools/lineagetest.gd
extends SceneTree
const P = preload("res://data/Progress.gd")
const B = preload("res://data/Biominerals.gd")
var fails := 0
var out := OS.get_environment("SHOT_DIR")
var backup := ""

func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)

func snap(n: String):
	if out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)

func _initialize():
	if FileAccess.file_exists(P.SAVE_PATH):
		backup = FileAccess.get_file_as_string(P.SAVE_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P.SAVE_PATH))
	await _run()
	if backup != "":
		var f = FileAccess.open(P.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P.SAVE_PATH))
	print("LINEAGE %s (%d problems)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(fails)

func _run():
	check(B.lineage_recipes().size() == 19 and B.run_recipes().size() == 1, "19 lineage parts, 1 in-run part (%d, %d)" % [B.lineage_recipes().size(), B.run_recipes().size()])
	P.add_to_bank({"Ca": 40.0, "P": 60.0, "Fe": 20.0, "Zn": 20.0, "Cu": 20.0, "S": 30.0})
	check(int(P.bank().P) == 60, "bank saved")
	# Eyespots: 2 P base x1.5 -> 3, 6, 9
	var p0 = float(P.bank().P)
	for i in 4:
		P.grow_lineage("photoreceptors")
	check(int(P.lineage_ranks().get("photoreceptors", 0)) == 3, "ranks stop at 3 (%s)" % P.lineage_ranks())
	check(is_equal_approx(p0 - float(P.bank().P), 18.0), "ranks cost 3+6+9 P (spent %.1f)" % (p0 - float(P.bank().P)))
	# Locked parts (data/Unlocks.gd) open with their goal
	const U = preload("res://data/Unlocks.gd")
	check(U.unlocked_ids().size() == 3, "three starter parts open (%s)" % [U.unlocked_ids()])
	check(not P.grow_lineage("zinc_venom") and not P.grow_lineage("bone"), "locked parts can't be grown")
	var tiers := {}
	for id in U.GOALS:
		tiers[U.GOALS[id].tier] = tiers.get(U.GOALS[id].tier, 0) + 1
		check(B.get_recipe(id).size() > 0, "goal %s is a real part" % id)
		check(U.icon_texture(U.GOALS[id]) != null, "goal %s has a picture" % id)
	check(U.GOALS.size() + U.STARTERS.size() == B.lineage_recipes().size(), "every part has a goal or is a starter")
	print("LINEAGE tiers: ", tiers)
	P.add_stats({"eat:Sacabambaspis": 3, "eat:Arandaspis": 2, "eat:Isotelus": 6, "eat:Olenoides": 4, "seep": 2})
	check(U.progress_of("calcium_signalling") == [2, 5], "seeps counted 2/5")
	P.add_stats({}, {"reach:arachnid": 5})
	check(U.is_unlocked("bone") and U.is_unlocked("calcite_lenses") and U.is_unlocked("zinc_venom"), "goals met open the parts")
	check(not U.is_unlocked("hemocyanin"), "arthropod goal still locked")
	check(P.grow_lineage("zinc_venom") and not P.grow_lineage("zinc_venom"), "a once-only part grows once")
	check(not P.grow_lineage("membrane_repair"), "healing isn't a lineage part")
	P.grow_lineage("bone")

	# The menu page
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 10: await process_frame
	check(menu.grow_btn != null and menu.grow_btn.text.begins_with("🌱"), "menu has the GROW button (%s)" % menu.grow_btn.text)
	await snap("0_menu")
	menu.show_lineage_grow()
	for i in 20: await process_frame
	var page = menu.overlay.find_children("*", "VBoxContainer", true, false).filter(func(c): return c.get_script() != null and c.get_script().resource_path == "res://LineageGrow.gd")
	check(page.size() == 1, "the GROW page opens")
	await snap("1_grow_page")
	if page.size() == 1:
		var g = page[0]
		check(g.fresh.has("bone") and g.fresh.has("calcite_lenses"), "newly opened parts say NEW")
		g._on_tile("magnetite_teeth")
		for i in 5: await process_frame
		check(g.go.disabled and g.go.text == "LOCKED", "a locked part can't be grown")
		await snap("2_locked_part")
		g._on_tile("calcite_lenses")
		for i in 5: await process_frame
		var before = int(P.lineage_ranks().get("calcite_lenses", 0))
		g._on_tile("calcite_lenses") # tap again grows it
		check(int(P.lineage_ranks().get("calcite_lenses", 0)) == before + 1, "tap again grows a rank")
		for i in 30: await process_frame
		await snap("3_grown_lenses")
		g._on_tile("photoreceptors")
		for i in 5: await process_frame
		await snap("4_fully_grown")
	menu.queue_free()
	await process_frame

	# A run starts with the lineage
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var pl = main.player
	var vis0 = pl.vision
	var hp0 = pl.max_health
	main.apply_lineage(P.lineage_ranks())
	check(pl.adaptations_taken.get("photoreceptors", 0) == 3 and pl.vision >= vis0 + 3 or pl.vision >= 10, "three eyespot ranks: +3 vision (%d -> %d)" % [vis0, pl.vision])
	check(pl.max_health == hp0 + 2 and pl.health == pl.max_health, "bone: +1 heart, full health")
	check(pl.adaptations_taken.has("zinc_venom") and pl.adaptations_taken.has("calcite_lenses"), "every part granted")
	# In-run growing is healing only
	pl.elements = {"Ca": 30.0, "P": 30.0, "S": 30.0}
	check(not pl.grow("calcite_spines"), "no growing lasting parts in a run")
	pl.health = pl.max_health - 2
	check(pl.grow("membrane_repair") and pl.health == pl.max_health, "membrane repair still heals in the run")
	main.current_room_node.room_data.cleared = true
	main.hud.show_grow_screen()
	for i in 10: await process_frame
	check(main.hud.is_grow_up() and main.hud.grow_tiles.size() == 1, "the in-run BODY screen has just the heal tile")
	await snap("5_body_screen_in_run")
	main.hud.hide_grow_screen()
	# Banking follows what's in hand: eat, spend, flush
	var b0 = P.bank().duplicate()
	main.bank_synced = {}
	pl.elements = {}
	pl.add_element("Fe", 5.0)
	main.flush_bank(true)
	check(is_equal_approx(float(P.bank().Fe) - float(b0.Fe), 5.0), "eaten iron is banked (%.1f)" % (float(P.bank().Fe) - float(b0.Fe)))
	main.flush_bank(true)
	check(is_equal_approx(float(P.bank().Fe) - float(b0.Fe), 5.0), "flushing twice doesn't bank twice")
	pl.elements.Fe -= 2.0
	main.flush_bank(true)
	check(is_equal_approx(float(P.bank().Fe) - float(b0.Fe), 3.0), "spending in the run banks less")
	check(pl.elements_eaten >= 5.0, "eaten total counted")
	# Kills and seeps are tallied and saved with the bank
	var st0 = P.stats().duplicate()
	main.field_event("eat:Orthoceras")
	main.field_event("eat:Orthoceras")
	main.tally("boss:2")
	main.flush_bank(true)
	check(int(P.stats().get("eat:Orthoceras", 0)) == int(st0.get("eat:Orthoceras", 0)) + 2, "kills of a species are kept")
	check(int(P.stats().get("eat_all", 0)) == int(st0.get("eat_all", 0)) + 2, "all kills are kept")
	check(preload("res://data/Unlocks.gd").is_unlocked("electric_organ"), "beating the Cambrian boss opens the electric organ")
	main.queue_free()
	await process_frame
