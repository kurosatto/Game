# tracetest.gd
# Checks trace fossils (data/Traces.gd, rooms/TraceLayer.gd): every animal
# and playable form maps to a real trace or to none, every trace has a maker
# in the game, animals and you leave marks of your own kind as you move, the
# first one seen is named once and kept, and the TRACES page builds.
# With SHOT_DIR (xvfb) it takes a picture of each era's tracks and the page.
#   godot --headless --path . -s res://tools/tracetest.gd
extends SceneTree
const Traces = preload("res://data/Traces.gd")
const FAUNA = preload("res://data/Fauna.gd")
const LINEAGES = preload("res://data/Lineages.gd")
var fails := 0
var out := OS.get_environment("SHOT_DIR")
func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)
func snap(n: String):
	if out == "":
		return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)

func _initialize():
	# ---- Data ----
	var used := {}
	for k in Traces.BY_NAME:
		var v = Traces.BY_NAME[k]
		check(v == "" or Traces.TRACES.has(v), "name %s maps to a real trace (%s)" % [k, v])
		used[v] = true
	for k in Traces.BY_FORM:
		var v = Traces.BY_FORM[k]
		check(v == "" or Traces.TRACES.has(v), "form %s maps to a real trace (%s)" % [k, v])
		used[v] = true
	var form_ids := {}
	for p in LINEAGES.TREE:
		form_ids[LINEAGES.TREE[p].id] = true
	for k in Traces.BY_FORM:
		check(form_ids.has(k), "BY_FORM key %s is a playable form" % k)
	for id in Traces.TRACES:
		check(used.has(id), "trace %s has a maker in the game" % id)
	var names := {}
	for f in range(1, 6):
		for sp in FAUNA.era_species(f):
			names[sp.name] = sp.get("form", "")
		names[FAUNA.BOSSES[f].name] = ""
		names[FAUNA.ALT_BOSSES[f].name] = FAUNA.ALT_BOSSES[f].get("form", "")
	var missing: Array = []
	for n in names:
		if not Traces.BY_NAME.has(n) and names[n] == "":
			missing.append(n)
	check(missing.is_empty(), "every era animal has a trace entry %s" % [missing])
	var with_trace := 0
	for id in form_ids:
		if Traces.for_form(id) != "":
			with_trace += 1
	print("TRACE forms with a trace: %d / %d" % [with_trace, form_ids.size()])
	check(Traces.for_form("ancestral_collar_cell") == "", "a cell leaves no track")
	check(Traces.for_form("scorpion") == "paleohelcura", "scorpions leave scorpion tracks")
	check(Traces.for_form("millipede") == "diplichnites", "millipedes inherit Diplichnites")
	check(Traces.for_form("synapsid") == "dimetropus", "synapsids leave Dimetropus")

	# ---- In play ----
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	if main.hud.is_card_up():
		main.hud.dismiss_card()
	var p = main.player
	var codex = preload("res://data/Codex.gd")
	for f in [1, 2, 3, 4, 5]:
		main.floor_number = f
		main.generate_floor()
		var pick = null
		for pos in main.dungeon_rooms:
			var r = main.dungeon_rooms[pos]
			if r.type == 1 and r.special == "" and pos != Vector2i(4, 4):
				pick = pos
				break
		var data = main.dungeon_rooms[pick]
		data.covers_rolled = true
		data.covers = []
		data.hazards_rolled = true
		data.hazards = []
		main.current_room_pos = pick
		main.load_room(pick)
		var room = main.current_room_node
		main.get_node("VisionFog").set_vision(10, true)
		for e in get_nodes_in_group("enemies"):
			room.active_enemies.erase(e)
			e.queue_free()
		for o in room.get_children():
			if o.is_in_group("obstacles"):
				o.queue_free()
		await physics_frame
		var layer = room.get_node_or_null("Traces")
		check(layer != null, "era %d: the room has a trace layer" % f)
		if layer == null:
			continue
		# Every era animal, each walked along its own lane
		var kinds: Array = []
		for t in FAUNA.FLOORS[f]:
			kinds.append(t)
		for sp in FAUNA.extras(f):
			kinds.append(sp.type + "@" + sp.name)
		var foes: Array = []
		for k in kinds:
			var before = room.active_enemies.size()
			room.spawn_enemy(Vector2(200, 200), k, f)
			for i in range(before, room.active_enemies.size()):
				foes.append(room.active_enemies[i])
				break # one of a pack is enough
		for e in room.active_enemies.duplicate():
			if not foes.has(e):
				room.active_enemies.erase(e)
				e.queue_free()
		var lanes := {}
		for i in foes.size():
			lanes[foes[i]] = 150.0 + i * (780.0 / max(1, foes.size() - 1))
		p.invincibility_time = 99.0
		for step in 150:
			for e in foes:
				if is_instance_valid(e):
					e.global_position = room.global_position + Vector2(260.0 + step * 6.0, lanes[e])
					e.velocity = Vector2.ZERO
					e.stun_timer = 1.0
			p.global_position = room.global_position + Vector2(1700.0, 160.0 + step * 5.0)
			p.health = p.max_health
			preload("res://rooms/TraceLayer.gd")._next_note = 0.0
			await physics_frame
		var by_id := {}
		for m in layer.marks:
			by_id[m[7]] = by_id.get(m[7], 0) + 1
		for e in foes:
			if not is_instance_valid(e):
				continue
			var id = layer.trace_of(e)
			var nm = layer.animal_name(e)
			if id != "":
				check(by_id.get(id, 0) >= (2 if Traces.gap(id) >= 90.0 else 5), "era %d: %s leaves %s (%d marks)" % [f, nm, id, by_id.get(id, 0)])
		print("TRACE era %d: %s" % [f, by_id])
		if out != "":
			main.get_node("VisionFog").set_vision(10, true)
			for e in foes:
				if is_instance_valid(e):
					e.global_position.x -= 80.0
			p.global_position = room.global_position + Vector2(1700.0, 900.0)
			await snap("traces_era%d" % f)
		for e in foes:
			if is_instance_valid(e):
				room.active_enemies.erase(e)
				e.queue_free()

	# Your own tracks, per form
	for form in ["scorpion", "synapsid", "lissamphibian", "sea_snail"]:
		var data: Dictionary = {}
		for path in LINEAGES.TREE:
			if LINEAGES.TREE[path].id == form:
				data = LINEAGES.TREE[path]
		p.apply_form(data)
		var room = main.current_room_node
		var layer = room.get_node("Traces")
		var want = Traces.for_form(form)
		for step in 80:
			p.global_position = room.global_position + Vector2(400.0 + step * 6.0, 540.0)
			await physics_frame
		var n := 0
		for m in layer.marks:
			if m[7] == want:
				n += 1
		check(n >= 5, "as %s you leave %s (%d marks)" % [form, want, n])

	# Named once each, and kept
	var seen = codex.load_traces()
	check(seen.size() >= 2, "traces were noted as they were seen (%d)" % seen.size())
	var titles = main.hud.journal.map(func(j): return j[0])
	check(titles.any(func(t): return String(t).begins_with("TRACE FOSSIL")), "a trace went into the field journal")
	var dup := {}
	for t in titles:
		dup[t] = dup.get(t, 0) + 1
	check(dup.values().all(func(v): return v == 1), "each trace is named only once")
	print("TRACE noted: ", seen)

	# ---- The TRACES page ----
	main.queue_free()
	await process_frame
	var menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 10: await process_frame
	for id in ["undichna", "diplichnites", "cruziana", "kouphichnium", "asteriacites", "epibaion"]:
		codex.note_trace(id)
	menu.show_traces()
	for i in 5: await process_frame
	check(menu.overlay != null, "the TRACES page opens")
	var rows = menu.overlay.find_children("*", "PanelContainer", true, false)
	check(rows.size() >= Traces.TRACES.size(), "a row per trace (%d)" % rows.size())
	await snap("traces_page")
	print("TRACE done, %d failures" % fails)
	quit()
