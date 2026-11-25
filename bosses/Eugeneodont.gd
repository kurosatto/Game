# Eugeneodont.gd
# Shared body for the two sea-world bosses of floors 4 and 5 (data/Worlds.gd):
# Edestus (Carboniferous seas) and Helicoprion (Permian seas). Both were
# eugeneodonts, big shark-shaped fish closer to living ratfish than to true
# sharks, known mostly from their extraordinary teeth. Their bodies are
# reconstructed as streamlined, with a tall forked tail and long pectoral
# fins. This script draws that body seen from above, swimming with a wave
# that grows toward the tail, and leaves the teeth and the attacks to each
# boss (draw_teeth, think).
extends "res://bosses/BossBase.gd"

var BODY := Color(0.52, 0.55, 0.6)
var BELLY := Color(0.82, 0.82, 0.78)
const TOOTH := Color(0.97, 0.93, 0.82)
var LENGTH := 420.0
var GIRTH := 46.0

var vel: Vector2 = Vector2.ZERO
var swim: float = 0.0          # wave phase
var swim_rate: float = 6.0
var swim_amp: float = 1.0
var bend: float = 0.0          # body curve while turning
var gape: float = 0.0          # 0 shut, 1 wide open
var orbit_dir: float = 1.0
var did_hit: bool = false

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 52.0

func burst_color() -> Color:
	return BODY.lerp(Color(0.8, 0.3, 0.25), 0.3)

# Turning bends the body; call every frame from think
func steer(dir: Vector2, rate: float, delta: float):
	var before = facing.angle()
	turn_toward(dir, rate, delta)
	var turn = wrapf(facing.angle() - before, -PI, PI) / max(delta, 0.001)
	bend = lerp(bend, clamp(turn * 0.25, -0.6, 0.6), clamp(delta * 6.0, 0.0, 1.0))

func tick_swim(delta: float):
	swim += delta * swim_rate
	gape = clamp(gape, 0.0, 1.0)

func head_pos(extra: float = 0.0) -> Vector2:
	return global_position + facing * (LENGTH * 0.28 + extra)

# Points along the body, head (i = 0) to tail, in local space facing +X
func spine_pts() -> Array:
	var pts := []
	for i in 17:
		var f = i / 16.0
		var x = LENGTH * (0.3 - f)
		var wave = sin(swim - f * 4.2) * 26.0 * swim_amp * f * f
		var curve = bend * 120.0 * f * f
		pts.append(Vector2(x, wave + curve))
	return pts

func girth_at(f: float) -> float:
	# Pointed snout, deep chest, narrow tail stalk
	if f < 0.12:
		return GIRTH * (0.35 + 0.65 * f / 0.12)
	return GIRTH * lerp(1.0, 0.18, pow((f - 0.12) / 0.88, 1.2))

func body_hit_circles():
	var pts = spine_pts()
	var out := []
	for i in [2, 6, 10]:
		out.append(global_position + Vector2(pts[i]).rotated(facing.angle()))
	set_hit_circles(out, [52.0, 44.0, 30.0])

func draw_shark():
	pen_xf(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	var pts = spine_pts()
	shadow(Vector2(-LENGTH * 0.15, 18), LENGTH * 0.5, GIRTH * 1.3)
	# Tall forked tail (seen from above: two lobes trailing the stalk)
	var tail: Vector2 = pts[16]
	var tdir = (pts[16] - pts[14]).normalized()
	var tside = tdir.orthogonal()
	var sweep = sin(swim - 4.2) * 0.5 * swim_amp
	for s in [-1.0, 1.0]:
		var lobe = PackedVector2Array([tail - tdir * 6.0, tail + (tdir * 70.0 + tside * s * 46.0).rotated(sweep * 0.4), tail + (tdir * 40.0 + tside * s * 12.0).rotated(sweep * 0.4)])
		shape(lobe, BODY.darkened(0.08), 2.5)
	# Pectoral fins: long, swept back
	for s in [-1.0, 1.0]:
		var root: Vector2 = pts[3]
		var flap = sin(swim * 0.5 + s) * 0.08
		var fin = PackedVector2Array([root + Vector2(12, s * GIRTH * 0.6), root + Vector2(-60, s * (GIRTH + 66.0)).rotated(flap * s), root + Vector2(-50, s * (GIRTH + 30.0)).rotated(flap * s), root + Vector2(-30, s * GIRTH * 0.6)])
		shape(fin, BODY.darkened(0.12), 2.5)
	# Small pelvic fins
	for s in [-1.0, 1.0]:
		var root2: Vector2 = pts[10]
		shape(PackedVector2Array([root2 + Vector2(6, s * 12.0), root2 + Vector2(-26, s * 34.0), root2 + Vector2(-16, s * 10.0)]), BODY.darkened(0.12), 2.0)
	# The body
	var widths := []
	for i in pts.size():
		widths.append(girth_at(i / 16.0))
	tube(pts, widths, BODY)
	# Darker back down the middle (countershading), and the dorsal fin
	# seen from above: a narrow blade raked back
	var back_w := []
	for i in pts.size():
		back_w.append(girth_at(i / 16.0) * 0.42)
	tube(pts.slice(1, 15), back_w.slice(1, 15), BODY.darkened(0.22), 0.0)
	var d0: Vector2 = pts[5]
	var d1: Vector2 = pts[8]
	tube([d0, d0.lerp(d1, 0.5), d1], [7.0, 6.0, 1.5], BODY.darkened(0.35), 2.0)
	# Gill slits behind the head
	for k in 5:
		var gp: Vector2 = pts[2].lerp(pts[3], k / 4.0)
		for s in [-1.0, 1.0]:
			pen_line(gp + Vector2(0, s * GIRTH * 0.55), gp + Vector2(-6, s * GIRTH * 0.85), Color(Shading.ink(BODY), 0.8), 2.0, true)
	# Eyes
	var head: Vector2 = pts[0]
	for s in [-1.0, 1.0]:
		var eye = head + Vector2(-34, s * GIRTH * 0.42)
		pen_circle(eye, 7.0, OUTLINE, true, -1.0, true)
		pen_circle(eye, 5.0, Color(0.85, 0.8, 0.55), true, -1.0, true)
		pen_circle(eye + Vector2(1.5, 0), 2.6, Color(0.05, 0.05, 0.08), true, -1.0, true)
	draw_teeth(head)
	pen_xf(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

# Each boss draws its own teeth at the snout (local space, facing +X)
func draw_teeth(_snout: Vector2):
	pass

# A row of teeth along a path: a jaw blade. side (+1/-1) is the way the
# teeth point, across the path.
func tooth_row(path: PackedVector2Array, n: int, tooth_len: float, side: float):
	pen_polyline(path, Shading.ink(BODY), 10.0, true)
	pen_polyline(path, BODY.lightened(0.3), 6.0, true)
	for i in n:
		var f = (i + 0.5) / n * (path.size() - 1)
		var k = mini(int(f), path.size() - 2)
		var base = path[k].lerp(path[k + 1], f - k)
		var along = (path[k + 1] - path[k]).normalized()
		var dir = along.orthogonal() * side
		var tl = tooth_len * (0.6 + 0.6 * float(i) / n)
		var tooth = PackedVector2Array([base - along * tl * 0.4, base + dir * tl - along * tl * 0.1, base + along * tl * 0.4])
		pen_polygon(tooth, TOOTH)
		tooth.append(tooth[0])
		pen_polyline(tooth, OUTLINE, 1.5, true)

# A curved row of teeth along an arc, for the tooth whorls
func tooth_arc(center: Vector2, r: float, a0: float, a1: float, n: int, tooth_len: float, outward: bool = true):
	var pts := PackedVector2Array()
	for i in 25:
		var a = lerp(a0, a1, i / 24.0)
		pts.append(center + Vector2.from_angle(a) * r)
	pen_polyline(pts, Shading.ink(BODY), 9.0, true)
	pen_polyline(pts, BODY.lightened(0.2), 5.0, true)
	for i in n:
		var a = lerp(a0, a1, (i + 0.5) / n)
		var dir = Vector2.from_angle(a) * (1.0 if outward else -1.0)
		var base = center + Vector2.from_angle(a) * r
		var side = dir.orthogonal()
		var tooth = PackedVector2Array([base - side * tooth_len * 0.42, base + dir * tooth_len + side * tooth_len * 0.15, base + side * tooth_len * 0.42])
		pen_polygon(tooth, TOOTH)
		tooth.append(tooth[0])
		pen_polyline(tooth, OUTLINE, 1.5, true)
