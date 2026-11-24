# BrachiopodBed.gd
# A brachiopod bed (data/SpecialRooms.gd "brachiopods"): lamp shells packed
# on the sea floor, each gaping a little to feed with its coiled lophophore.
# They have no eyes worth the name, but feel the water move: anything coming
# fast and every shell nearby snaps shut a moment later. Creep up, wait for
# them to gape again, then lunge and take one before it reacts. In the Permian reef seas they included the
# strangest of all, Richthofenia, a horn-shaped shell with a lid, built
# like a coral.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)
const SHELLS := 14
const FEEL := 260.0      # px: how far they feel the water moving
const FAST := 170.0      # px/s: faster than this and they feel you
const SHUT := 3.0        # seconds a startled shell stays shut
const REACT := 0.25      # seconds between feeling you and snapping shut
const EAT_R := 44.0      # touching an open one takes it
const UNITS := 0.45

var floor_num: int = 7
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0
var last_pp: Vector2 = Vector2.INF
var speed: float = 0.0   # how fast you're moving, from where you were
var shells: Array = []   # {pos, size, gape (0..1), shut (seconds), eaten, phase}

func _ready():
	z_index = -2
	player = get_tree().get_first_node_in_group("player")
	if not state.has("shells"):
		state["shells"] = _lay()
	shells = state.shells
	for s in shells:
		s["shut"] = 0.0
		s["warn"] = 0.0
		s["gape"] = 0.0 if s.eaten else 1.0
	for c in room.get_children():
		if c.is_in_group("obstacles") and c is Node2D and shells.any(func(s): return s.pos.distance_to(c.position) < 90.0):
			c.queue_free()

# A few clumps, as they grow on one another's shells
func _lay() -> Array:
	var out: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = int(room.room_data.grid_pos.x * 71 + room.room_data.grid_pos.y * 13 + 3)
	var area = room.interior_rect(190.0)
	var doors = [Vector2(960, 128), Vector2(960, 952), Vector2(128 - room.side_margin, 540), Vector2(1792 + room.side_margin, 540)]
	var clumps: Array = []
	for attempt in 60:
		if clumps.size() >= 4:
			break
		var c = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if clumps.any(func(q): return q.distance_to(c) < 380.0) or doors.any(func(d): return d.distance_to(c) < 280.0):
			continue
		clumps.append(c)
	for i in SHELLS:
		var c = clumps[i % clumps.size()] if not clumps.is_empty() else Vector2(960, 540)
		for attempt in 20:
			var p = c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 120.0)
			if out.all(func(s): return s.pos.distance_to(p) > 56.0):
				out.append({"pos": p, "size": rng.randf_range(22.0, 30.0), "eaten": false, "phase": rng.randf() * TAU, "rot": rng.randf() * TAU})
				break
	return out

func open_count() -> int:
	return shells.filter(func(s): return not s.eaten and s.shut <= 0.0).size()

func _physics_process(delta: float):
	time += delta
	var pp = Vector2(-9999, -9999)
	var fast = false
	if player and is_instance_valid(player) and player.health > 0:
		pp = player.global_position - global_position
		# A jump of more than a dash's step is a teleport (a door), not a rush
		if last_pp != Vector2.INF and delta > 0.0 and pp.distance_to(last_pp) < 60.0:
			speed = lerp(speed, pp.distance_to(last_pp) / delta, 0.5)
		last_pp = pp
		fast = speed > FAST or player.get("is_dashing") == true
	var snapped := false
	for s in shells:
		if s.eaten:
			continue
		s.shut = max(0.0, s.shut - delta)
		var d = s.pos.distance_to(pp)
		# Felt the water move: a moment later, shut tight. Creep close while
		# they gape, then lunge before they react
		if fast and d < FEEL and s.shut <= 0.0 and s.warn <= 0.0:
			s.warn = REACT
		if s.warn > 0.0:
			s.warn -= delta
			if s.warn <= 0.0:
				s.warn = 0.0
				s.shut = SHUT * randf_range(0.85, 1.15)
				snapped = true
		var want = 0.0 if s.shut > 0.0 else 1.0
		s.gape = move_toward(s.gape, want, delta * (14.0 if want < s.gape else 0.8))
		# Taken while it still gapes
		if d < EAT_R + s.size * 0.5 and s.gape > 0.35:
			s.eaten = true
			s.gape = 1.0
			SR.spill(room, s.pos, ["Ca", "P"], UNITS, 2)
			if player:
				player.popup_text(player.global_position + Vector2(0, -70), "TAKEN OPEN", Color(0.9, 0.85, 0.65))
	if snapped:
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play_sfx("hit_glance", randf_range(1.3, 1.5))
	queue_redraw()

func _draw():
	for s in shells:
		_draw_shell(s)

# Richthofenia from above: a ribbed horn-shaped cup, its round lid lifting
# to show the coiled lophophore inside; eaten, an empty cup
func _draw_shell(s: Dictionary):
	var p: Vector2 = s.pos
	var r: float = s.size
	var rot: float = s.rot
	draw_circle(p, r, Color(INK, 0.22))
	draw_arc(p, r, 0.0, TAU, 28, INK, 2.6, true)
	# Ribs running up the cup
	for k in 14:
		var a = rot + TAU * k / 14.0
		draw_line(p + Vector2.from_angle(a) * r * 0.72, p + Vector2.from_angle(a) * r, Color(INK, 0.6), 1.2, true)
	if s.eaten:
		draw_circle(p, r * 0.68, Color(INK, 0.5))
		return
	var g: float = s.gape
	# Inside: the dark gape and, when open, the lophophore's coils
	draw_circle(p, r * 0.68, Color(INK, 0.55 * g + 0.1))
	if g > 0.3:
		for k in 2:
			var c = p + Vector2.from_angle(rot + PI * k) * r * 0.25
			var pts = PackedVector2Array()
			for j in 14:
				var u = j / 13.0
				pts.append(c + Vector2.from_angle(rot + u * TAU * 1.6 + time * 0.6 + s.phase) * r * 0.25 * u)
			draw_polyline(pts, Color(0.95, 0.88, 0.74, g), 1.6, true)
	# The lid: closed it sits square on the cup; open it hinges back
	var lid_c = p + Vector2.from_angle(rot) * r * 0.55 * g + (Vector2(sin(time * 60.0), 0) * 2.0 if s.warn > 0.0 else Vector2.ZERO)
	var lid_r = r * (0.7 - 0.12 * g)
	draw_circle(lid_c, lid_r, Color(0.55, 0.42, 0.3))
	draw_arc(lid_c, lid_r, 0.0, TAU, 24, INK, 2.2, true)
	for k in 3:
		draw_arc(lid_c, lid_r * (0.3 + 0.22 * k), rot - 1.2, rot + 1.2, 10, Color(INK, 0.45), 1.0, true)
	# Just snapped: a ring in the water
	if s.shut > SHUT - 0.35:
		var t = (SHUT - s.shut) / 0.35
		draw_arc(p, r * (1.1 + 0.6 * t), 0.0, TAU, 24, Color(INK, 0.6 * (1.0 - t)), 2.0, true)
