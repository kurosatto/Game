# MatGround.gd
# A microbial mat ground (data/SpecialRooms.gd "mat"): before burrowing
# animals churned up the sea floor, Ediacaran sea beds were carpeted with
# mats of bacteria, wrinkled like elephant skin. Rest on a mat to graze it
# (choanoflagellates, your nearest cousins, still live on bacteria) and it
# gives up its phosphorus and sulfur. A few Dickinsonia graze here too:
# each glides to a mat, lies on it and digests it through its underside,
# leaving an oval feeding scar, the trace fossil Epibaion. What they eat is
# gone, so get there first.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)
const MATS := 7
const GRAZE_TIME := 2.4     # seconds of resting to graze a whole mat
const STILL := 150.0        # px/s: slower than this counts as resting
const UNITS := 0.9          # elements a mat gives up
const GRAZERS := 2
const GLIDE := 24.0         # px/s, a Dickinsonia between meals
const LIE_RATE := 0.14      # of a mat eaten per second by a Dickinsonia
const LIE_TIME := 3.0       # seconds before it shifts to a new spot

var floor_num: int = 1
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var mats: Array = []        # {pos, r, left, seed}
var scars: Array = []       # [pos, angle, size]
var grazers: Array = []     # {e, target, lie}
var time: float = 0.0
var grazing: float = 0.0    # how far through the mat under you, for the ring
var ring: Node2D = null

func _ready():
	z_index = -4 # under the traces and everyone
	player = get_tree().get_first_node_in_group("player")
	ring = Node2D.new()
	ring.z_as_relative = false
	ring.z_index = 3
	ring.draw.connect(_draw_ring)
	add_child(ring)
	if not state.has("mats"):
		state["mats"] = _lay_mats()
		state["scars"] = []
	mats = state.mats
	# Rocks don't lie on a living mat
	for c in room.get_children():
		if c.is_in_group("obstacles") and c is Node2D:
			if mats.any(func(m): return m.pos.distance_to(c.position) < m.r + 50.0):
				c.queue_free()
	scars = state.scars
	var n = int(state.get("grazers", GRAZERS))
	state["grazers"] = n
	for i in n:
		var m = _pick_mat(null)
		var at = room.free_spot(m.pos + Vector2(m.r + 60.0, 0).rotated(randf() * TAU) if m else Vector2(960, 540), 50.0)
		room.spawn_enemy(at, "tank@Dickinsonia", floor_num)
		var e = room.active_enemies.back()
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
		# Feeding, it pays you no attention and does no harm
		e.set_meta("graze_damage", e.damage)
		e.damage = 0
		e.enemy_died.connect(_on_grazer_died)
		grazers.append({"e": e, "target": m, "lie": 0.0})

func _lay_mats() -> Array:
	var out: Array = []
	var area = room.interior_rect(150.0)
	var doors = [Vector2(960, 128), Vector2(960, 952), Vector2(128 - room.side_margin, 540), Vector2(1792 + room.side_margin, 540)]
	var rng = RandomNumberGenerator.new()
	rng.seed = int(room.room_data.grid_pos.x * 97 + room.room_data.grid_pos.y * 31 + 5)
	for attempt in 200:
		if out.size() >= MATS:
			break
		var p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var r = rng.randf_range(80.0, 120.0)
		if out.any(func(m): return m.pos.distance_to(p) < m.r + r + 70.0):
			continue
		if doors.any(func(d): return d.distance_to(p) < 230.0):
			continue
		var sd = rng.randi()
		out.append({"pos": p, "r": r, "left": 1.0, "seed": sd, "shape_seed": sd})
	return out

# The fullest mat that no other Dickinsonia is lying on
func _pick_mat(from) -> Variant:
	var best = null
	var best_score = -INF
	for m in mats:
		if m.left < 0.15 or grazers.any(func(g): return g.target == m):
			continue
		var score = m.left * 400.0 - (from.distance_to(m.pos) if from != null else 0.0) * 0.5
		if score > best_score:
			best_score = score
			best = m
	return best

func _process(delta: float):
	time += delta
	_graze_player(delta)
	_graze_animals(delta)
	queue_redraw()
	ring.queue_redraw()

func _graze_player(delta: float):
	grazing = 0.0
	if player == null or not is_instance_valid(player) or player.health <= 0:
		return
	var pp = player.global_position - global_position
	for m in mats:
		if m.left <= 0.0 or pp.distance_to(m.pos) > m.r:
			continue
		if player.velocity.length() > STILL:
			grazing = 1.0 - m.left
			return
		m.left = max(0.0, m.left - delta / GRAZE_TIME)
		grazing = 1.0 - m.left
		if m.left <= 0.0:
			var els = ["P", "S"]
			SR.spill(room, m.pos, els, UNITS, 3)
			player.popup_text(player.global_position + Vector2(0, -70), "GRAZED", Color(0.9, 0.85, 0.65))
		return

func _graze_animals(delta: float):
	for g in grazers:
		var e = g.e
		if not is_instance_valid(e) or e.dead:
			continue
		# Hurt, it stops feeding and acts like any other Dickinsonia
		if e.health < e.max_health:
			if not e.is_physics_processing():
				e.set_physics_process(true)
				e.damage = e.get_meta("graze_damage", e.damage)
				g.target = null
			continue
		var m = g.target
		if m == null or m.left <= 0.0:
			g.target = _pick_mat(e.position)
			g.lie = 0.0
			continue
		var to = m.pos + Vector2.from_angle(float(m.seed % 628) / 100.0) * m.r * 0.35 - e.position
		if g.lie > 0.0 or to.length() < 18.0:
			# Lying on the mat, feeding through its underside
			g.lie += delta
			e.velocity = Vector2.ZERO
			m.left = max(0.0, m.left - LIE_RATE * delta)
			if g.lie >= LIE_TIME or m.left <= 0.0:
				var spr: Sprite2D = e.get_node("Sprite2D")
				scars.append([e.position, spr.rotation, e.base_scale])
				if scars.size() > 40:
					scars.pop_front()
				# Shift along a little and lie down again
				m.seed = (int(m.seed) * 1103515245 + 12345) & 0x7fffffff
				g.lie = 0.0
				if m.left <= 0.0:
					g.target = null
			continue
		e.velocity = to.normalized() * GLIDE
		e.position += e.velocity * delta
		var spr2: Sprite2D = e.get_node("Sprite2D")
		spr2.rotation = lerp_angle(spr2.rotation, to.angle() + PI / 2, delta * 1.5)

func _on_grazer_died():
	state["grazers"] = max(0, int(state.get("grazers", 0)) - 1)

func _draw():
	for m in mats:
		_draw_mat(m)
	# Epibaion: where a Dickinsonia lay and fed, a shallow oval with the
	# ghost of its segments
	for s in scars:
		var w = 34.0 * s[2]
		var h = 46.0 * s[2]
		var pts = PackedVector2Array()
		for i in 25:
			var a = TAU * i / 24.0
			pts.append(s[0] + Vector2(cos(a) * w, sin(a) * h).rotated(s[1]))
		draw_colored_polygon(pts.slice(0, 24), Color(0.95, 0.9, 0.8, 0.35))
		draw_polyline(pts, Color(INK, 0.32), 2.0, true)
		draw_line(s[0] + Vector2(0, -h * 0.85).rotated(s[1]), s[0] + Vector2(0, h * 0.85).rotated(s[1]), Color(INK, 0.22), 1.5, true)
		for k in range(-3, 4):
			var y = k * h * 0.24
			var hw = w * sqrt(max(0.0, 1.0 - pow(y / h, 2))) * 0.85
			draw_line(s[0] + Vector2(-hw, y).rotated(s[1]), s[0] + Vector2(hw, y).rotated(s[1]), Color(INK, 0.16), 1.2, true)

# A mat: a low, wrinkled skin on the sand, with the "elephant skin" ridges
# that Ediacaran mats left in the rock. Grazed, it thins from the middle out.
func _draw_mat(m: Dictionary):
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.shape_seed)
	var outline = PackedVector2Array()
	var radii: Array = []
	for i in 21:
		radii.append(m.r * rng.randf_range(0.82, 1.08))
	for i in 41:
		var a = TAU * i / 40.0
		var k = float(i) / 2.0
		var rr = lerp(radii[int(k) % 20], radii[(int(k) + 1) % 20], k - int(k))
		outline.append(m.pos + Vector2.from_angle(a) * rr)
	var left = float(m.left)
	if left > 0.0:
		draw_colored_polygon(outline.slice(0, 40), Color(INK, 0.1 + 0.14 * left))
		# Ridges in a loose net, faded where it has been eaten
		var ridge = Color(INK, 0.25 + 0.5 * left)
		for j in 26:
			var p = m.pos + Vector2.from_angle(rng.randf() * TAU) * m.r * sqrt(rng.randf()) * 0.85
			var a2 = rng.randf() * TAU
			var l = rng.randf_range(14.0, 26.0)
			var q = p + Vector2.from_angle(a2) * l
			var mid = (p + q) / 2.0 + Vector2.from_angle(a2 + PI / 2) * rng.randf_range(-5.0, 5.0)
			draw_polyline(PackedVector2Array([p, mid, q]), ridge, 2.2, true)
			# Little side-wrinkles off each ridge make the net
			draw_line(mid, mid + Vector2.from_angle(a2 + PI / 2 * (1 if j % 2 else -1)) * l * 0.45, ridge, 1.6, true)
		# The bare patch where it has been grazed
		if left < 0.95:
			var bare = outline.slice(0, 40)
			for i in bare.size():
				bare[i] = m.pos + (bare[i] - m.pos) * (1.0 - left) * 0.95
			draw_colored_polygon(bare, Color(0.95, 0.9, 0.8, 0.45))
	draw_polyline(outline, Color(INK, 0.18 + 0.32 * left), 2.0 + left, true)

# How far through the mat under you
func _draw_ring():
	if grazing <= 0.0 or player == null or not is_instance_valid(player):
		return
	var c = player.global_position - global_position + Vector2(0, -64)
	ring.draw_arc(c, 16.0, 0.0, TAU, 24, Color(INK, 0.35), 2.0, true)
	ring.draw_arc(c, 16.0, -PI / 2, -PI / 2 + TAU * grazing, 24, Color(INK, 0.95), 5.0, true)
