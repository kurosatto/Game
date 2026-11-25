# hitboxcover.gd
# Checks that every drawn part of every boss can be hit. Each boss fights a
# circling player and runs through all its moves; every few frames the boss
# alone is rendered into a second viewport and each solid pixel of its
# drawing is tested against the boss's hit test (bosses/BossBase.gd gap_to),
# which shots, bites, stings and blasts all use.
# Prints the share of the drawing outside the hitbox, worst frame first.
# With SHOT_DIR set it saves that worst frame with the missed pixels in red.
#   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/hitboxcover.gd
# Optional ONLY=Anomalocaris,Eryops tests some bosses (by killer name);
# STILL=1 holds each pose a few frames before measuring; DEBUG=1 marks the
# recorded pieces in cyan on the saved picture. Warning marks ("!", floor
# telegraphs) are not body and show up red; look at the picture.
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
const LAYER := 1 << 9
const STEP := 4 # sample every 4th pixel
var out := OS.get_environment("SHOT_DIR")
var only := OS.get_environment("ONLY")
var view: SubViewport

func _initialize():
	run()

func tag(n: Node):
	if n is CanvasItem:
		n.visibility_layer = LAYER
	for c in n.get_children():
		tag(c)

# Share of the boss's solid pixels that lie outside every hit circle
func measure(boss, save_name: String, beat: float = 0.0) -> float:
	if OS.get_environment("STILL") != "":
		# Hold the pose a moment, to tell a one-frame lag from a real gap
		boss.set_physics_process(false)
		for b in boss.get("bodies") if boss.get("bodies") != null else []:
			b.set_process(false)
		await process_frame
		await process_frame
		await process_frame
		if not is_instance_valid(boss):
			return 0.0
		boss.set_physics_process(true)
		for b in boss.get("bodies") if boss.get("bodies") != null else []:
			b.set_process(true)
	tag(boss)
	var up = boss.get_parent()
	while up:
		if up is CanvasItem:
			up.visibility_layer |= LAYER
		up = up.get_parent()
	view.canvas_transform = root.get_canvas_transform()
	await RenderingServer.frame_post_draw
	if not is_instance_valid(boss):
		return 0.0
	var img: Image = view.get_texture().get_image()
	var inv: Transform2D = view.canvas_transform.affine_inverse()
	var parts: Array = boss.hurt_parts()
	var solid := 0
	var missed := 0
	var miss_pts: Array = []
	var w := img.get_width()
	var h := img.get_height()
	for y in range(0, h, STEP):
		for x in range(0, w, STEP):
			if img.get_pixel(x, y).a < 0.6:
				continue
			solid += 1
			var p: Vector2 = inv * Vector2(x, y)
			if boss.gap_to(p, 8.0) > 6.0:
				missed += 1
				miss_pts.append(Vector2i(x, y))
	var share: float = float(missed) / max(solid, 1)
	if out != "" and save_name != "" and share > beat:
		var shot: Image = root.get_texture().get_image()
		for q in miss_pts:
			shot.fill_rect(Rect2i(q, Vector2i(STEP, STEP)), Color.RED)
		var ct: Transform2D = view.canvas_transform
		for part in parts:
			var c: Vector2 = ct * part[0]
			var r: float = part[1] * ct.get_scale().x
			for i in 48:
				var a := TAU * i / 48.0
				shot.fill_rect(Rect2i(Vector2i(c + Vector2(cos(a), sin(a)) * r), Vector2i(3, 3)), Color.YELLOW)
		if OS.get_environment("DEBUG") != "":
			var bx: Transform2D = ct * boss.get_global_transform()
			for d in boss.hit_pieces()[0]:
				var pts: Array = Array(d[0]) if d[0] is PackedVector2Array else [d[0], d[1]]
				for q in pts:
					shot.fill_rect(Rect2i(Vector2i(bx * q), Vector2i(3, 3)), Color.CYAN)
		shot.save_png(out + "/" + save_name + ".png")
	return share

func states_of(script: Script) -> Array:
	var found := []
	var s := script
	var re := RegEx.new()
	re.compile("set_state\\(\"([a-z_0-9]+)\"")
	while s:
		for m in re.search_all(s.source_code):
			var st = m.get_string(1)
			if st != "intro" and st != "dead" and not found.has(st):
				found.append(st)
		s = s.get_base_script()
	return found

func run():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	view = SubViewport.new()
	view.size = root.get_visible_rect().size
	view.transparent_bg = true
	view.world_2d = root.world_2d
	view.canvas_cull_mask = LAYER
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	# [floor, sea, finale, script]
	var cases = []
	for f in range(1, 6):
		cases.append([f, false, false, Room_boss(f, false)])
		cases.append([f, false, false, "res://bosses/DrawnBoss.gd"])
	for f in [4, 5]:
		cases.append([f, true, false, Room_boss(f, true)])
		cases.append([f, true, false, "res://bosses/DrawnBoss.gd"])
	cases.append([5, false, true, "res://bosses/Inostrancevia.gd"])
	cases.append([5, true, true, "res://bosses/Campylocephalus.gd"])
	cases.append([4, false, false, "res://bosses/Megarachne.gd"])
	cases.append([4, true, false, "res://bosses/Saivodus.gd"])
	var report := []
	for c in cases:
		Worlds.sea = c[1]
		Worlds.finale = c[2]
		main.floor_number = c[0]
		main.generate_floor()
		for i in 10: await process_frame
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		# Stay in this room whatever doors the player wanders into
		var room = main.current_room_node
		if room.room_transition_requested.is_connected(main._on_room_transition_requested):
			room.room_transition_requested.disconnect(main._on_room_transition_requested)
		var script: Script = load(c[3])
		var boss = script.new()
		boss.position = Vector2(960, 540)
		boss.setup_enemy(c[0])
		main.current_room_node.add_child(boss)
		main.register_boss(boss)
		var nm: String = boss.killer_name()
		if only != "" and not only.split(",").has(nm):
			boss.take_damage(99999.0)
			for i in 20: await process_frame
			continue
		var player = main.player
		main.get_node("VisionFog").set_vision(10, true)
		main.hud.item_banner.visible = false
		var worst := 0.0
		var worst_state := ""
		var total := 0.0
		var samples := 0
		var moves: Array = boss.kit.duplicate() if boss.has_method("start_move") else states_of(script)
		var plan := [["fight", 360]]
		for st in moves:
			plan.append([st, 60])
		plan.append(["phase2", 300])
		for st in moves:
			plan.append([st, 60])
		var f := 0
		for step in plan:
			if not is_instance_valid(boss):
				break
			if step[0] == "phase2":
				boss.take_damage(boss.max_health * 0.55)
			elif step[0] != "fight":
				if boss.has_method("start_move"):
					boss.start_move(step[0])
				else:
					boss.set_state(step[0])
			for i in step[1]:
				await physics_frame
				f += 1
				if not is_instance_valid(boss):
					break
				var a := f / 60.0 * 0.9
				var want: Vector2 = boss.global_position + Vector2(cos(a) * 420.0, sin(a) * 260.0)
				want = want.clamp(main.current_room_node.global_position + Vector2(200, 200), main.current_room_node.global_position + Vector2(1720, 880))
				player.global_position = player.global_position.move_toward(want, 6.0)
				player.health = player.max_health
				if f % 12 == 0:
					var share: float = await measure(boss, "cover_" + nm.to_lower() + ("_sea" if c[1] else ""), worst)
					total += share
					samples += 1
					if share > worst:
						worst = share
						worst_state = boss.state
		var line := "%-16s %-5s avg %4.1f%% outside, worst %4.1f%% (%s)" % [nm, "sea" if c[1] else "land", 100.0 * total / max(samples, 1), 100.0 * worst, worst_state]
		print("HITBOX ", line)
		report.append(line)
		if is_instance_valid(boss):
			boss.take_damage(99999.0)
		for i in 30: await process_frame
		for n in main.current_room_node.get_children():
			if n.get_script() == load("res://bosses/BossHazard.gd") or n.is_in_group("enemy_tears"):
				n.queue_free()
	print("HITBOX summary")
	for l in report:
		print("  ", l)
	quit()

func Room_boss(f: int, sea: bool) -> String:
	Worlds.sea = sea
	return load("res://Room.gd").BOSSES.get(Worlds.era(f))
