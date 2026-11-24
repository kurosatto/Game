# DroughtPool.gd
# A drying pool (data/SpecialRooms.gd "drought"): Permian lowlands had
# monsoon seasons, and in the dry months ponds shrank to puddles. Fish
# crowded into what water was left, and those caught on the mud flapped
# and died there; whole beds of them are found that way. Lungfish dug
# down into the mud, sealed themselves in and slept until the rain came
# back, and their burrows (Gnathorhiza, with the fish still inside) are
# found in Permian red beds by the hundred.
# Here the pool shrinks while you are in the room: fish stranded on the
# mud are an easy meal, and as the mud dries the lungfish burrows show,
# to be dug out by standing on them.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)
const CENTRE := Vector2(960, 540)
const FULL := Vector2(380, 215)   # the pool's half-axes when you arrive
const LOW := Vector2(120, 72)     # what's left at the end
const DRY_TIME := 45.0            # seconds from full to puddle
const FISH := 8
const STRANDED_MULT := 2.5        # flapping on the mud, it can't get away
const BURROWS := 4
const DIG_TIME := 1.4             # seconds of standing on a burrow to dig it
const BURROW_UNITS := 1.2

var floor_num: int = 5
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0
var dry: float = 0.0              # 0 full .. 1 puddle
var fish: Array = []              # {e, home (unit offset), stranded}
var burrows: Array = []           # {pos, at (dry when it shows), dug}
var digging: float = 0.0
var dig_at: int = -1
var ring: Node2D = null
var cracks: Array = []            # [a, b] crack lines in the dried ring

func _ready():
	z_index = -4
	player = get_tree().get_first_node_in_group("player")
	ring = Node2D.new()
	ring.z_as_relative = false
	ring.z_index = 3
	ring.draw.connect(_draw_ring)
	add_child(ring)
	dry = float(state.get("dry", 0.0))
	# Nothing grows on the pool bed
	for c in room.get_children():
		if c.is_in_group("obstacles") and c is Node2D and _inside(c.position, FULL * 1.15):
			c.queue_free()
	var rng = RandomNumberGenerator.new()
	rng.seed = int(room.room_data.grid_pos.x * 53 + room.room_data.grid_pos.y * 29 + 11)
	if not state.has("burrows"):
		var list: Array = []
		for i in BURROWS:
			# In the band of mud that dries out, spread round the pool
			var a = TAU * (i + rng.randf_range(0.15, 0.85)) / BURROWS
			var k = rng.randf_range(0.5, 0.8)
			var axes = LOW.lerp(FULL, k)
			list.append({"pos": CENTRE + Vector2(cos(a) * axes.x, sin(a) * axes.y), "at": 1.0 - (k - 0.32) / 0.68, "dug": false})
		state["burrows"] = list
	burrows = state.burrows
	# Mud cracks: a net of short straight lines, drawn where the mud is dry
	for i in 170:
		var a = rng.randf() * TAU
		var k = rng.randf_range(0.3, 1.1)
		var p = CENTRE + Vector2(cos(a) * FULL.x * k, sin(a) * FULL.y * k)
		var d = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(18.0, 40.0)
		cracks.append([p, p + d])
	var n = int(state.get("fish", FISH))
	state["fish"] = n
	for i in n:
		var home = Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 0.85
		room.spawn_enemy(_pool_point(home), "fly@Palaeoniscum", 7)
		var e = room.active_enemies.back()
		e.set_physics_process(false)
		e.damage = 0
		e.enemy_died.connect(_on_fish_died)
		# Some are caught out by the falling water, at their own moment
		var fate = rng.randf_range(0.1, 0.6) if i % 2 == 0 else 2.0
		fish.append({"e": e, "home": home, "stranded": false, "phase": rng.randf() * TAU, "fate": fate})

func axes() -> Vector2:
	return FULL.lerp(LOW, dry)

func _inside(p: Vector2, ax: Vector2) -> bool:
	var q = (p - CENTRE) / ax
	return q.length() <= 1.0

func _pool_point(unit: Vector2) -> Vector2:
	return CENTRE + unit * axes()

func _process(delta: float):
	time += delta
	if dry < 1.0:
		dry = min(1.0, dry + delta / DRY_TIME)
		state["dry"] = dry
	_move_fish(delta)
	_dig(delta)
	queue_redraw()
	ring.queue_redraw()

func _move_fish(delta: float):
	var ax = axes()
	for f in fish:
		var e = f.e
		if not is_instance_valid(e) or e.dead:
			continue
		var spr: Sprite2D = e.get_node("Sprite2D")
		if f.stranded:
			# Flapping on the mud, it flips about where it lies
			f.phase += delta * 9.0
			spr.rotation = f.get("lie", 0.0) + sin(f.phase) * 0.9
			e.position += Vector2(sin(f.phase * 1.7), cos(f.phase * 1.3)) * 30.0 * delta
			continue
		# Caught in the shallows: it stays put as the water goes from under it
		if dry >= f.fate:
			f.phase += delta * 3.0
			spr.rotation += sin(f.phase) * delta
			if not _inside(e.position, ax):
				f.stranded = true
				f["lie"] = spr.rotation
				e.set_meta("hit_mult", STRANDED_MULT)
				if player and is_instance_valid(player):
					player.popup_text(e.global_position + Vector2(0, -40), "STRANDED", Color(0.9, 0.85, 0.65))
			continue
		# Swimming: round its own patch of the pool, which shrinks with it
		f.phase += delta * 0.9
		var target = _pool_point(f.home.rotated(f.phase * 0.25) * 0.9)
		var v = (target - e.position).limit_length(90.0 * delta)
		e.position += v
		if v.length() > 0.1:
			spr.rotation = lerp_angle(spr.rotation, v.angle() + PI / 2, delta * 4.0)

func _dig(delta: float):
	digging = 0.0
	if player == null or not is_instance_valid(player) or player.health <= 0:
		return
	var pp = player.global_position - global_position
	for i in burrows.size():
		var b = burrows[i]
		if b.dug or dry < b.at or pp.distance_to(b.pos) > 46.0:
			continue
		if dig_at != i:
			dig_at = i
			b["progress"] = 0.0
		b["progress"] = float(b.get("progress", 0.0)) + delta / DIG_TIME
		digging = b.progress
		if b.progress >= 1.0:
			b.dug = true
			SR.spill(room, b.pos, ["P", "Ca"], BURROW_UNITS, 3)
			player.popup_text(player.global_position + Vector2(0, -70), "LUNGFISH BURROW", Color(0.9, 0.85, 0.65))
		return
	dig_at = -1

func _on_fish_died():
	state["fish"] = max(0, int(state.get("fish", 0)) - 1)

func _ellipse(ax: Vector2, n: int = 48) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in n:
		var a = TAU * i / n
		pts.append(CENTRE + Vector2(cos(a) * ax.x, sin(a) * ax.y) * (1.0 + 0.04 * sin(a * 5.0 + 1.3)))
	return pts

func _draw():
	var ax = axes()
	# The old shoreline, and the mud inside it
	var full = _ellipse(FULL * 1.04)
	draw_colored_polygon(full, Color(INK, 0.1))
	full.append(full[0])
	draw_polyline(full, Color(INK, 0.35), 2.0, true)
	# Dried mud: cracks where the water has gone
	for c in cracks:
		var mid = (c[0] + c[1]) / 2.0
		if not _inside(mid, ax * 1.05) and _inside(mid, FULL):
			draw_line(c[0], c[1], Color(INK, 0.5), 1.8, true)
	# The water: a darker wash with a few ripples
	var water = _ellipse(ax)
	draw_colored_polygon(water, Color(INK, 0.34))
	water.append(water[0])
	draw_polyline(water, Color(INK, 0.85), 3.2, true)
	# Wavelets: short wavy strokes across the open water
	for j in 14:
		var u = Vector2(fposmod(j * 0.618, 1.0) * 1.4 - 0.7, fposmod(j * 0.382, 1.0) * 1.2 - 0.6)
		if u.length() > 0.75:
			continue
		var p0 = CENTRE + u * ax + Vector2(sin(time * 0.8 + j) * 6.0, 0)
		var wl = PackedVector2Array()
		for q in 7:
			wl.append(p0 + Vector2(q * 6.0 - 18.0, sin(q * 1.2 + time * 2.0 + j) * 2.5))
		draw_polyline(wl, Color(INK, 0.45), 1.6, true)
	for k in 3:
		var r = fposmod(time * 0.25 + k / 3.0, 1.0)
		var w = _ellipse(ax * (0.25 + 0.6 * r), 32)
		w.append(w[0])
		draw_polyline(w, Color(INK, 0.22 * (1.0 - r)), 1.4, true)
	# Lungfish burrows: a round plug of mud with a breathing hole
	for b in burrows:
		if dry < b.at:
			continue
		var a = clamp((dry - b.at) * 6.0, 0.0, 1.0)
		if b.dug:
			draw_circle(b.pos, 22.0, Color(INK, 0.35 * a))
			draw_arc(b.pos, 24.0, 0.0, TAU, 20, Color(INK, 0.5 * a), 1.5, true)
		else:
			draw_circle(b.pos, 20.0, Color(INK, 0.16 * a))
			draw_arc(b.pos, 20.0, 0.0, TAU, 20, Color(INK, 0.75 * a), 2.4, true)
			draw_circle(b.pos, 5.0, Color(INK, 0.85 * a))
			for s in 3:
				var g = TAU * s / 3.0 + 0.4
				draw_line(b.pos + Vector2.from_angle(g) * 9.0, b.pos + Vector2.from_angle(g) * 17.0, Color(INK, 0.5 * a), 1.5, true)

# How far through digging out a burrow
func _draw_ring():
	if digging <= 0.0 or player == null or not is_instance_valid(player):
		return
	var c = player.global_position - global_position + Vector2(0, -64)
	ring.draw_arc(c, 16.0, 0.0, TAU, 24, Color(INK, 0.35), 2.0, true)
	ring.draw_arc(c, 16.0, -PI / 2, -PI / 2 + TAU * min(1.0, digging), 24, Color(INK, 0.95), 5.0, true)
