# TreeFall.gd
# A falling scale tree (data/SpecialRooms.gd "treefall"): the giant club
# mosses of the coal swamps, Lepidodendron and its kin, stood 30 m tall on
# shallow, spreading roots (Stigmaria) in waterlogged peat, and came down
# easily. Fossil forests are strewn with their fallen trunks.
# A few seconds into the fight the trunk creaks and its shadow marks where it
# will land: get clear, and lure the animals under it. Whatever it lands on
# is crushed. Then it lies across the room as a wall, and the cockroaches that
# lived in its bark run out of it, a meal.
extends Node2D

const INK = Color(0.24, 0.15, 0.08)
const WAIT := 6.0          # seconds into the fight before it creaks
const TELL := 2.6          # creaking, shadow showing
const FALL := 0.45         # the fall itself
const LENGTH := 1250.0
const HALF_W := 46.0       # half the trunk's width
const CRUSH := 14.0        # damage to animals under it
const ROACHES := 6

var floor_num: int = 4
var room: Node2D = null
var state: Dictionary = {}
var first: bool = true
var player: Node2D = null
var time: float = 0.0
var phase: String = "wait" # wait, tell, fall, down
var t: float = 0.0
var base: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var leaves: Array = []     # falling leaf specks during the tell

func _ready():
	z_index = 2 # the trunk lies over the floor and the animals' feet
	player = get_tree().get_first_node_in_group("player")
	if state.has("base"):
		base = state.base
		dir = state.dir
	else:
		# Rooted by one side wall, falling across the room
		var left = randf() < 0.5
		base = Vector2(250.0 if left else 1670.0, randf_range(330.0, 750.0))
		var target = Vector2(1670.0 if left else 250.0, randf_range(330.0, 750.0))
		target.y = clamp(1080.0 - base.y + randf_range(-120, 120), 260.0, 820.0) # cross the middle
		dir = (target - base).normalized()
		state["base"] = base
		state["dir"] = dir
	if state.get("down", false):
		phase = "down"
		_make_wall()
		_clear_obstacles()

func tip() -> Vector2:
	return base + dir * LENGTH

func _clear_obstacles():
	for c in room.get_children():
		if c.is_in_group("obstacles") and c is Node2D and _under(c.position, HALF_W + 50.0):
			c.queue_free()

# Does the trunk land on any part of your drawn body (Player.touched_by_gap)?
func _crushes_player() -> bool:
	if not player.has_method("touched_by_gap"):
		return _under(player.global_position - global_position, HALF_W + 10.0)
	# The trunk as drawn in _trunk: 0.8 of HALF_W at the root, tapering to 0.6
	var a: Vector2 = to_global(base)
	var b: Vector2 = to_global(tip())
	var trunk = func(p: Vector2) -> float:
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var u: float = a.distance_to(q) / maxf(1.0, a.distance_to(b))
		return max(0.0, p.distance_to(q) - HALF_W * 0.8 * (1.0 - 0.25 * u))
	return player.touched_by_gap(trunk, (a + b) * 0.5, a.distance_to(b) * 0.5 + HALF_W)

# Is a point under the trunk's line?
func _under(p: Vector2, half: float) -> bool:
	var rel = p - base
	var along = rel.dot(dir)
	if along < -20.0 or along > LENGTH + 20.0:
		return false
	return absf(rel.cross(dir)) <= half

func _process(delta: float):
	time += delta
	t += delta
	match phase:
		"wait":
			if t >= WAIT and (room.get("room_data") == null or not room.room_data.cleared):
				phase = "tell"
				t = 0.0
				if player and is_instance_valid(player):
					player.popup_text(base + room.global_position + Vector2(0, -80), "CREAK...", Color(0.98, 0.82, 0.5))
				var sm = get_node_or_null("/root/SoundManager")
				if sm:
					sm.play_sfx("hit_glance", 0.5)
		"tell":
			if randf() < delta * 14.0:
				leaves.append([base + dir * randf_range(200.0, LENGTH) + Vector2(randf_range(-80, 80), randf_range(-80, 80)), 0.0])
			if t >= TELL:
				phase = "fall"
				t = 0.0
		"fall":
			if t >= FALL:
				_land()
	for l in leaves:
		l[1] += delta
	leaves = leaves.filter(func(l): return l[1] < 1.6)
	queue_redraw()

func _land():
	phase = "down"
	state["down"] = true
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("shake_camera"):
		main.shake_camera(16.0)
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sfx("hit_bone" if sm.sound_streams.has("hit_bone") else "hit", 0.45)
	var crushed := 0
	for e in room.active_enemies.duplicate():
		if is_instance_valid(e) and not e.dead and _under(e.global_position - global_position, HALF_W + 24.0):
			crushed += 1
			e.take_damage(CRUSH)
	if player and is_instance_valid(player) and player.health > 0 and _crushes_player():
		player.take_damage(2, "a falling tree")
		# Thrown clear of the trunk
		var side = signf((player.global_position - global_position - base).cross(dir))
		if side == 0.0:
			side = 1.0
		player.global_position += dir.orthogonal() * -side * (HALF_W + 50.0)
	if crushed > 0 and player and is_instance_valid(player):
		player.popup_text(tip() * 0.5 + base * 0.5 + room.global_position + Vector2(0, -60), "CRUSHED!", Color(0.98, 0.76, 0.38))
	_clear_obstacles()
	_make_wall()
	# The bark was full of cockroaches
	for i in ROACHES:
		var at = base + dir * randf_range(250.0, LENGTH - 100.0) + dir.orthogonal() * (HALF_W + 30.0) * (1.0 if i % 2 else -1.0)
		room.spawn_enemy(room.free_spot(at, 30.0), "skittish@Archimylacris", floor_num)
		var r = room.active_enemies.back()
		r.flee_timer = randf_range(0.2, 0.8)

func _make_wall():
	var body = StaticBody2D.new()
	body.collision_layer = 4 # with obstacles: fliers go over
	body.collision_mask = 0
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(LENGTH, HALF_W * 1.6)
	col.shape = shape
	body.add_child(col)
	body.position = base + dir * LENGTH * 0.5
	body.rotation = dir.angle()
	add_child(body)

func _draw():
	match phase:
		"wait":
			return
		"tell":
			# The shadow of where it will land, darker as it leans
			var k = t / TELL
			_band(Color(INK, 0.28 + 0.22 * k), HALF_W)
			_band_outline(Color(INK, 0.75 + 0.25 * sin(time * 14.0)))
			for l in leaves:
				var p = l[0] + Vector2(sin(l[1] * 5.0) * 10.0, l[1] * 40.0)
				draw_line(p, p + Vector2(7, 3).rotated(l[1] * 4.0), Color(INK, 0.7 * (1.0 - l[1] / 1.6)), 2.0, true)
		"fall":
			# Sweeping down: the trunk grows along its line from the root
			var k2 = clamp(t / FALL, 0.0, 1.0)
			_band(Color(INK, 0.24), HALF_W)
			_trunk(LENGTH * k2 * k2)
		"down":
			_trunk(LENGTH)

func _band(col: Color, half: float):
	var n = dir.orthogonal() * half
	draw_colored_polygon(PackedVector2Array([base + n, tip() + n, tip() - n, base - n]), col)

func _band_outline(col: Color):
	var n = dir.orthogonal() * HALF_W
	var pts = [base + n, tip() + n, tip() - n, base - n, base + n]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var segs = int(a.distance_to(b) / 26.0)
		for s in segs:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / segs), a.lerp(b, float(s + 1) / segs), col, 4.0, true)

# Lepidodendron: a straight trunk patterned all over with diamond leaf
# scars, Stigmaria roots spreading at the base, a forked crown at the top
func _trunk(length: float):
	var n = dir.orthogonal()
	var w = HALF_W * 0.8
	var end = base + dir * length
	var bark = Color(0.42, 0.3, 0.2)
	if length < 1.0:
		return # not grown out yet: nothing to draw
	draw_colored_polygon(PackedVector2Array([base + n * w, end + n * w * 0.75, end - n * w * 0.75, base - n * w]), bark)
	draw_line(base + n * w, end + n * w * 0.75, INK, 3.0, true)
	draw_line(base - n * w, end - n * w * 0.75, INK, 3.0, true)
	# Diamond leaf cushions in spiral rows
	var step = 34.0
	var rows = int(length / step)
	for i in rows:
		var along = (i + 0.5) * step
		var taper = 1.0 - 0.25 * along / LENGTH
		for j in [-1.0, -0.33, 0.33, 1.0]:
			var c = base + dir * (along + (step * 0.5 if int(j * 3) % 2 == 0 else 0.0)) + n * w * taper * j * 0.72
			var a = dir * 13.0
			var b = n * 7.0 * taper
			draw_polyline(PackedVector2Array([c - a, c + b, c + a, c - b, c - a]), Color(INK, 0.7), 1.5, true)
			draw_circle(c, 1.6, Color(INK, 0.8))
	# Stigmaria: roots spreading flat from the base
	for r in 6:
		var g = dir.angle() + PI + (r - 2.5) * 0.42
		var p0 = base
		var p1 = base + Vector2.from_angle(g) * 70.0 + Vector2.from_angle(g + 1.0) * 10.0
		var p2 = base + Vector2.from_angle(g) * 120.0
		draw_polyline(PackedVector2Array([p0, p1, p2]), INK, 4.0 - r % 2, true)
	# The crown: branches forking two by two
	if length >= LENGTH * 0.95:
		_fork(end, dir.angle(), 90.0, 3)

func _fork(p: Vector2, ang: float, l: float, depth: int):
	if depth <= 0:
		# Grass-like leaves on the last twigs
		for k in 5:
			var a = ang + (k - 2) * 0.35
			draw_line(p, p + Vector2.from_angle(a) * 14.0, Color(INK, 0.8), 1.4, true)
		return
	for s in [-1.0, 1.0]:
		var a2 = ang + s * 0.42
		var q = p + Vector2.from_angle(a2) * l
		draw_line(p, q, INK, 1.5 + depth * 1.3, true)
		_fork(q, a2, l * 0.62, depth - 1)
