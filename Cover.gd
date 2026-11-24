# Cover.gd
# A patch of growth you can slip into and hide (Room.spawn_covers), drawn per
# era: rangeomorph fronds (Ediacaran), a sponge garden (Cambrian), a meadow of
# sea lilies (Ordovician), a thicket of ferns and horsetails (Carboniferous),
# seed-fern scrub (Permian). Small animals have always hidden in growth like
# this. Inside it animals notice you far later, and ones hunting you from
# across the room lose track of you after a moment. The growth sways as you
# push through and thins so you can still see yourself.
extends Node2D

const INK = Color(0.24, 0.15, 0.08)
const HIDE := 0.35        # notice range while hidden
const LOSE_AFTER := 1.4   # seconds inside before far hunters lose you
const LOSE_RANGE := 300.0 # hunters closer than this still see you go in

var floor_num: int = 2
var size: Vector2 = Vector2(150, 105) # half extents
var seed_val: int = 0
var player: Node2D = null
var time: float = 0.0
var inside: float = -1.0 # seconds the player has been inside, -1 when out
var stems: Array = []    # [base, height, lean, phase, kind]
var push: float = 0.0    # sway from something moving through
var fade: float = 1.0

func _ready():
	z_index = 2 # over animals and you: you are in it
	add_to_group("covers")
	player = get_tree().get_first_node_in_group("player")
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var n = 22
	for i in n:
		var a = rng.randf() * TAU
		var r = sqrt(rng.randf())
		var base = Vector2.from_angle(a) * size * r * 0.92
		stems.append([base, rng.randf_range(46.0, 82.0), rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randi() % 3])
	stems.sort_custom(func(a, b): return a[0].y < b[0].y)

func contains(world: Vector2) -> bool:
	var l = (world - global_position) / size
	return l.length() < 1.0

func _process(delta: float):
	time += delta
	push = max(0.0, push - delta * 1.5)
	var want_fade = 1.0
	if player and is_instance_valid(player) and player.health > 0 and contains(player.global_position):
		if inside < 0.0:
			inside = 0.0
			push = 1.0
			if player.has_method("popup_text"):
				player.popup_text(player.global_position + Vector2(0, -70), "HIDDEN", Color(0.8, 0.9, 0.7))
		inside += delta
		if player.velocity.length() > 30.0:
			push = max(push, 0.5)
		player.cover_time = 0.15
		want_fade = 0.62
		if inside >= LOSE_AFTER and inside - delta < LOSE_AFTER:
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.has_method("lose_track") and e.get("mood") == "hostile" \
						and e.global_position.distance_to(player.global_position) > LOSE_RANGE:
					e.lose_track()
	else:
		inside = -1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.velocity.length() > 40.0 and contains(e.global_position):
			push = max(push, 0.4)
			break
	fade = lerp(fade, want_fade, 1.0 - exp(-delta * 8.0))
	queue_redraw()

func _draw():
	var a = fade
	# The ground under it: a soft darker patch
	var pts := PackedVector2Array()
	for i in 24:
		var t = TAU * i / 24.0
		pts.append(Vector2.from_angle(t) * size * (1.0 + 0.05 * sin(t * 5.0 + seed_val)))
	draw_colored_polygon(pts, Color(0.3, 0.26, 0.16, 0.14 * a))
	for s in stems:
		var base: Vector2 = s[0]
		var h: float = s[1]
		var sway = sin(time * 1.3 + s[3]) * 0.12 + sin(time * 9.0 + s[3]) * 0.18 * push
		var dir = Vector2.UP.rotated(s[2] + sway)
		var tip = base + dir * h
		match clampi(floor_num, 1, 5):
			1: _frond(base, tip, dir, a)
			2: _sponge(base, tip, h, s[4], a)
			3: _crinoid(base, tip, dir, a)
			4: _fern(base, tip, dir, s[4], a)
			_: _scrub(base, tip, dir, a)

func _line(a: Vector2, b: Vector2, alpha: float, w: float = 2.0):
	draw_line(a, b, Color(INK, min(1.0, alpha)), w * 1.5, true)

# Rangeomorph frond: a quilted leaf on a stalk
func _frond(base: Vector2, tip: Vector2, dir: Vector2, a: float):
	var side = dir.orthogonal()
	var mid = base.lerp(tip, 0.35)
	var leaf = PackedVector2Array([mid, mid.lerp(tip, 0.5) + side * 12.0, tip, mid.lerp(tip, 0.5) - side * 12.0])
	draw_colored_polygon(leaf, Color(0.78, 0.72, 0.56, 0.75 * a))
	leaf.append(leaf[0])
	draw_polyline(leaf, Color(INK, 0.85 * a), 1.6, true)
	_line(base, tip, a, 1.4)
	for k in 4:
		var p = mid.lerp(tip, (k + 1) / 5.0)
		_line(p, p + side * 9.0 + dir * 4.0, a * 0.7, 1.0)
		_line(p, p - side * 9.0 + dir * 4.0, a * 0.7, 1.0)

# Cambrian sponges: vases and branching tubes
func _sponge(base: Vector2, tip: Vector2, h: float, kind: int, a: float):
	var w = 10.0 + kind * 4.0
	var top = base + Vector2(0, -h * 0.7)
	var body = PackedVector2Array([base + Vector2(-w * 0.6, 0), top + Vector2(-w, 0), top + Vector2(w, 0), base + Vector2(w * 0.6, 0)])
	draw_colored_polygon(body, Color(0.82, 0.74, 0.58, 0.8 * a))
	body.append(body[0])
	draw_polyline(body, Color(INK, 0.85 * a), 1.6, true)
	draw_arc(top, w, PI, TAU, 10, Color(INK, 0.8 * a), 1.4, true)
	for k in 3:
		var y = lerp(base.y, top.y, (k + 1) / 4.0)
		draw_circle(Vector2(base.x + (k - 1) * w * 0.4, y), 1.6, Color(INK, 0.6 * a))

# Sea lilies: a stalk and a cup of feathery arms
func _crinoid(base: Vector2, tip: Vector2, dir: Vector2, a: float):
	_line(base, tip, a, 1.8)
	for k in 5:
		var arm = dir.rotated(-0.9 + k * 0.45)
		var end = tip + arm * 22.0
		draw_polyline(PackedVector2Array([tip, tip.lerp(end, 0.5) + arm.orthogonal() * 3.0, end]), Color(INK, 0.85 * a), 1.3, true)
	draw_circle(tip, 4.0, Color(0.8, 0.72, 0.55, a))

# Ferns and horsetails
func _fern(base: Vector2, tip: Vector2, dir: Vector2, kind: int, a: float):
	var side = dir.orthogonal()
	_line(base, tip, a, 1.6)
	if kind == 0:
		# Horsetail: jointed stem with whorls
		for k in 4:
			var p = base.lerp(tip, (k + 1) / 5.0)
			_line(p - side * 8.0, p + side * 8.0, a * 0.8, 1.2)
		return
	for k in 7:
		var u = (k + 1) / 8.0
		var p = base.lerp(tip, u)
		var l = 16.0 * (1.0 - u * 0.6)
		_line(p, p + (side + dir * 0.4).normalized() * l, a * 0.85, 1.2)
		_line(p, p + (-side + dir * 0.4).normalized() * l, a * 0.85, 1.2)

# Seed-fern scrub: forked stems with tongue-shaped leaves
func _scrub(base: Vector2, tip: Vector2, dir: Vector2, a: float):
	var fork = base.lerp(tip, 0.5)
	_line(base, fork, a, 1.6)
	for k in [-1, 1]:
		var end = fork + dir.rotated(0.5 * k) * (tip - base).length() * 0.55
		_line(fork, end, a, 1.4)
		var side = dir.rotated(0.5 * k).orthogonal()
		var leaf = PackedVector2Array([end, end + dir * 6.0 + side * 6.0, end + dir * 16.0, end + dir * 6.0 - side * 6.0])
		draw_colored_polygon(leaf, Color(0.76, 0.7, 0.5, 0.8 * a))
		leaf.append(leaf[0])
		draw_polyline(leaf, Color(INK, 0.85 * a), 1.2, true)
