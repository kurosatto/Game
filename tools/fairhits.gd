# fairhits.gd
# Do hits on the player match the drawings? kuro (2026-11-25): "a leaf
# monster hit me even if the visual looks like it did not hit me, make all
# the damages accurate". Renders the player and one animal into two
# separate viewports and calls it a touch when their painted pixels overlap,
# then compares that with the game's own test (Player.touched_by, through
# ArtShape.gd) and with the old collision-circle test.
#  1. Every era animal (painted sheets and code-drawn forms), on four sides
#     of the player: how far apart they first touch in the pictures, in the
#     game's test and in the old circles. Prints the worst gaps.
#  2. Charnia lashes at a player placed all round it: hits the old rule gave
#     where the frond never touched, and whether the new one only hits on a
#     real touch.
# Run with a window (xvfb on Linux):
#   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/fairhits.gd
# SHOT_DIR=<folder> saves pictures of the worst old false hits and of the
# frond cases. ONLY=Charnia,Dickinsonia limits part 1 to some animals;
# SKIP_ANIMALS=1 or SKIP_FROND=1 skips a part.
extends SceneTree

const Worlds = preload("res://data/Worlds.gd")
const Fauna = preload("res://data/Fauna.gd")
const LE := 1 << 10
const LP := 1 << 11
const BOX := 300 # half size of the checked screen square around the player
var out := OS.get_environment("SHOT_DIR")
var only := OS.get_environment("ONLY")
var ve: SubViewport
var vp: SubViewport
var main
var p
var fails := 0

func _initialize():
	run()

func check(ok: bool, what: String):
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func make_view(mask: int) -> SubViewport:
	var v := SubViewport.new()
	v.size = root.get_visible_rect().size
	v.transparent_bg = true
	v.world_2d = root.world_2d
	v.canvas_cull_mask = mask
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v)
	return v

func tag(n: Node, bit: int):
	if n is CanvasItem:
		n.visibility_layer = bit
	for c in n.get_children():
		tag(c, bit)

func tag_up(n: Node):
	var up = n
	while up:
		if up is CanvasItem:
			up.visibility_layer |= LE | LP
		up = up.get_parent()

# Painted pixels of both views overlap near the player (alpha >= 0.25)
func pictures_touch() -> bool:
	await RenderingServer.frame_post_draw
	var ct := root.get_canvas_transform()
	ve.canvas_transform = ct
	vp.canvas_transform = ct
	var c: Vector2 = ct * p.global_position
	var size := Vector2i(ve.size)
	var r := Rect2i(Vector2i(c) - Vector2i(BOX, BOX), Vector2i(BOX * 2, BOX * 2)).intersection(Rect2i(Vector2i.ZERO, size))
	var a: PackedByteArray = ve.get_texture().get_image().get_region(r).get_data()
	var b: PackedByteArray = vp.get_texture().get_image().get_region(r).get_data()
	var i := 3
	var n := a.size()
	while i < n:
		if a[i] >= 64 and b[i] >= 64:
			return true
		i += 4
	return false

func snap(name: String, label: String):
	if out == "":
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("SHOT ", name, "  ", label)

func old_touch(e) -> bool:
	var er: float = e.get_node("CollisionShape2D").shape.radius * absf(e.scale.x)
	var ec: Vector2 = e.get_node("CollisionShape2D").global_position
	var pr: float = p.body_radius(p, 26.0)
	return ec.distance_to(p.global_position) < er + pr + 1.0

func freeze(n: Node, on: bool):
	n.set_physics_process(not on)
	n.set_process(not on)

func run():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	p = main.player
	ve = make_view(LE)
	vp = make_view(LP)
	if OS.get_environment("SKIP_ANIMALS") == "":
		await animals()
	if OS.get_environment("SKIP_FROND") == "":
		await fronds()
	print("FAIRHITS done, %d failures" % fails)
	quit()

func clear_room():
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	for b in get_nodes_in_group("bosses"):
		b.queue_free()
	await process_frame

func set_era(era: int):
	Worlds.sea = era >= 6
	Worlds.finale = false
	main.floor_number = era - 2 if era >= 6 else era
	main.generate_floor()
	for i in 10: await process_frame
	await clear_room()

func place_player():
	var room = main.current_room_node
	p.global_position = room.global_position + Vector2(960, 540)
	p.velocity = Vector2.ZERO
	p.invincibility_time = 999.0
	freeze(p, true)
	if p.body_art:
		p.body_art.body_only = true
		p.body_art.set_process(true) # keeps drawing, and recording its pieces
	tag(p.get_node("Sprite2D"), LP)
	tag_up(p)
	p.visibility_layer = LP

# Largest distance (along dir) at which test() still says they touch.
# Poses are frozen, so only the picture test needs a new frame drawn.
func onset(e, dir: Vector2, test: Callable, render: bool) -> float:
	var lo := 0.0
	var hi := 420.0
	for it in 9:
		var mid := (lo + hi) * 0.5
		e.global_position = p.global_position + dir * mid
		e._gapper_frame = -1
		p._art_frame = -1
		if render:
			await process_frame
		var t: bool = await test.call()
		if t:
			lo = mid
		else:
			hi = mid
	return lo

func animals():
	print("== every era animal: distance at first touch (pictures / game / old circles)")
	var worst_new := 0.0
	var worst_old := 0.0
	var worst_old_name := ""
	var lines := []
	for era in range(1, 8):
		await set_era(era)
		place_player()
		var fl: int = era if era < 6 else era - 2
		var kinds := []
		var table: Dictionary = Fauna.FLOORS.get(Worlds.era(fl), {})
		for t in table:
			if t != "frond": # the lash has its own test below
				kinds.append([t, table[t]])
		for x in Fauna.extras(fl):
			kinds.append([x.type, x])
		for kind in kinds:
			var sp: Dictionary = kind[1].duplicate()
			sp["type"] = kind[0]
			if only != "" and not sp.name in only.split(","):
				continue
			var room = main.current_room_node
			var before = get_nodes_in_group("enemies").size()
			room.spawn_enemy(p.global_position + Vector2(300, 0), sp.type + "@" + sp.name, era - 2 if era >= 6 else era)
			var foes = get_nodes_in_group("enemies").filter(func(x): return x.fauna_name == sp.name)
			if foes.is_empty():
				continue
			var e = foes[0]
			for extra in foes.slice(1):
				extra.queue_free()
			await process_frame
			freeze(e, true)
			if e.body_art:
				e.body_art.body_only = true
				e.body_art.set_process(true)
			tag(e.get_node("Sprite2D"), LE)
			tag_up(e)
			e.visibility_layer = LE
			# Hold both poses still, so every test sees the same drawing
			for i in 3: await process_frame
			if e.body_art:
				e.body_art.set_process(false)
			if p.body_art:
				p.body_art.set_process(false)
			var harmless: bool = e.damage <= 0
			var d_new := 0.0
			var d_old := 0.0
			var miss_new := 0.0
			var miss_old := 0.0
			var lt := ""
			for k in 4:
				var dir := Vector2.RIGHT.rotated(TAU * k / 4.0 + 0.3)
				var t_pic: float = await onset(e, dir, func(): return await pictures_touch(), true)
				var t_new: float = await onset(e, dir, func(): return p.touched_by(e), false)
				var t_old: float = await onset(e, dir, func(): return old_touch(e), false)
				# Positive: the test hits before the drawings touch (a phantom
				# hit). Negative: drawings overlap first (feelers and
				# flagella are left out on purpose, ArtShape.body_pieces)
				d_new = max(d_new, t_new - t_pic)
				d_old = max(d_old, t_old - t_pic)
				miss_new = max(miss_new, t_pic - t_new)
				miss_old = max(miss_old, t_pic - t_old)
				lt += " %3.0f/%3.0f/%3.0f" % [t_pic, t_new, t_old]
				# A picture of the old rule's worst false hit
				if t_old - t_pic > worst_old and not harmless:
					worst_old = t_old - t_pic
					worst_old_name = sp.name
					if out != "":
						e.global_position = p.global_position + dir * t_old * 0.98
						await process_frame
						await process_frame
						await snap("old_false_hit_worst", "%s: circles touch %.0f px before the drawings" % [sp.name, t_old - t_pic])
			worst_new = max(worst_new, d_new)
			lines.append([d_old, "  %-16s era %d  phantom hit by up to: new %4.1f px, old %5.1f px; overlap before a hit: new %5.1f, old %5.1f  [%s]%s" % [sp.name, era, d_new, d_old, miss_new, miss_old, lt, "  (harmless)" if harmless else ""]])
			e.queue_free()
			if p.body_art:
				p.body_art.set_process(true)
			await process_frame
		freeze(p, false)
		if p.body_art:
			p.body_art.body_only = false
	lines.sort_custom(func(a, b): return a[0] > b[0])
	for l in lines:
		print(l[1])
	print("worst phantom hit: new test %.1f px before the drawings touch, old circles %.1f px (%s)" % [worst_new, worst_old, worst_old_name])
	check(worst_new <= 8.0, "no animal hurts by contact more than 8 px before the drawings touch")

func fronds():
	print("== Charnia lash, player placed all round the frond")
	await set_era(1)
	place_player()
	freeze(p, false)
	p.set_physics_process(false) # stays put, but keeps drawing
	var room = main.current_room_node
	var spot: Vector2 = room.global_position + Vector2(960, 540)
	var old_false := 0
	var new_false := 0
	var new_hits := 0
	var real_touches := 0
	var missed := 0
	var cases := 0
	var shot_old := false
	var shot_new := false
	for ring in [70.0, 120.0, 165.0]:
		for k in 12:
			await clear_room()
			room.spawn_enemy(spot, "frond", 1)
			var f = get_nodes_in_group("enemies").filter(func(x): return x.enemy_type == "frond")[0]
			f.global_position = spot
			f.provoke() if f.has_method("provoke") else null
			f.lash_cooldown = 0.0
			tag(f.get_node("Sprite2D"), LE)
			tag_up(f)
			f.visibility_layer = LE
			var root_pt: Vector2 = spot + f.FROND_ROOT
			p.global_position = root_pt + Vector2.RIGHT.rotated(TAU * k / 12.0) * ring
			await process_frame
			var old_hit := false
			var touched := false
			var hit := false
			var hurt_frame := false
			var old_img: Image = null
			for fr in 90:
				p.invincibility_time = 0.0
				p.health = p.max_health
				await physics_frame
				var lashing: bool = f.lash_state == "lash"
				if p.health < p.max_health:
					hit = true
					hurt_frame = true
				if lashing:
					var kk: float = 1.0 - f.lash_timer / f.FROND_LASH
					var t_now: bool = await pictures_touch()
					touched = touched or t_now
					if kk > 0.4 and not old_hit and (p.global_position - root_pt).length() < f.FROND_REACH + 15.0:
						old_hit = true
						if out != "" and not shot_old:
							old_img = root.get_texture().get_image()
				if f.lash_state == "recover":
					break
			# The lash may land during a frame this loop spent waiting on a picture
			hit = hit or f.lash_hit
			cases += 1
			if touched:
				real_touches += 1
			if old_hit and not touched:
				old_false += 1
				if not shot_old and old_img:
					shot_old = true
					old_img.save_png(out + "/frond_old_rule_hit_%d_%d.png" % [ring, k])
					print("SHOT frond_old_rule_hit_%d_%d: old rule hit here, the frond never touched" % [ring, k])
			if hit and not touched:
				new_false += 1
			if touched and not hit:
				missed += 1
			if hit:
				new_hits += 1
				if not shot_new and out != "":
					shot_new = true
	print("  %d placements: frond really touched %d; old rule hit %d times without a touch; new rule hits %d, %d without a touch, %d touches missed" % [cases, real_touches, old_false, new_hits, new_false, missed])
	check(new_false == 0, "the lash never hurts without the frond touching you")
	# Touches of only your flagellum or feelers don't count (ArtShape.body_pieces)
	check(missed * 5 <= real_touches, "the lash lands on most real touches (%d of %d brushed only a feeler or tail)" % [missed, real_touches])
