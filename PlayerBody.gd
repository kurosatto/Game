# PlayerBody.gd
# Draws the player's current form in code every frame, the same way the era
# bosses are drawn (bosses/BossBase.gd): outlined, shaded shapes posed live,
# so legs step with the distance walked, fins and tails beat faster at speed,
# the body curves through turns, and claws, jaws and stings move on attack.
# Lives under the player's Sprite2D, so the sprite's rotation, squash, flash
# and blink all still apply. Local +X is the head end.
# tools/render_forms.gd renders these drawings into assets/lineages sheets for
# the menu and codex.
extends Node2D

const OUTLINE := Color(0.05, 0.07, 0.12, 1.0)
# Rim around the silhouette so the player always reads as the player
const HALO := Color(0.35, 0.93, 1.0, 1.0)
const OW := 2.0

var player: Node = null
var form_id: String = "ancestral_collar_cell"
var t: float = 0.0        # clock
var swim: float = 0.0     # stroke phase: fins, tails, flagella (faster at speed)
var gait: float = 0.0     # leg cycle, advanced by distance walked
var move: float = 0.0     # 0 idle .. 1 full speed
var bend: float = 0.0     # body curve while turning
var strike: float = 0.0   # 1 on attack, fades out
var dash: float = 0.0     # 1 while dashing
var tuck: float = 0.0     # 1 while withdrawn or hunkered (escape moves)
var preview: bool = false # driven by the sheet renderer instead of a player
var _last_rot: float = 0.0
var halo_pass: bool = false
# Attack timeline: seconds since the last strike (strike above is the pose
# it drives), plus the body's whole-body lunge, a hurt flinch and a damped
# spring that lets the body lag behind speed changes so it moves with weight
const ATTACK_TIME := 0.42
var atk: float = 99.0
var lunge: float = 0.0
var hurt: float = 0.0
var _last_hp: float = -1.0
var _last_vel: Vector2 = Vector2.ZERO
var _lag: Vector2 = Vector2.ZERO
var _lag_v: Vector2 = Vector2.ZERO
var _stretch: Vector2 = Vector2.ONE
# Colour of the biggest outlined part, used to tint attack trails
var main_color: Color = Color(0.5, 0.8, 0.9)
var _main_area: float = 0.0

# Spine of long bodies for the current drawing (see sp())
var head_x: float = 40.0
var body_len: float = 90.0
var wave_amp: float = 0.0
var wave_k: float = 3.0

static func has_form(id: String) -> bool:
	return FORMS.has(id)

func set_form(id: String):
	form_id = id
	queue_redraw()

func on_attack():
	atk = 0.0

# 0..1 smooth ease in and out
static func smooth(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

# Strike pose and lunge over the attack: a short wind-up (pulled back, pose
# closed), a fast snap open/out, a brief hold, then an eased recovery
func _attack_curve():
	var u = atk / ATTACK_TIME
	if u >= 1.0:
		strike = 0.0
		lunge = 0.0
		return
	var wind = 0.1
	var snap = 0.26
	var hold = 0.42
	if u < wind:
		strike = 0.0
		lunge = -smooth(u / wind)
	elif u < snap:
		var k = (u - wind) / (snap - wind)
		k = 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k) # fast out
		strike = k
		lunge = lerp(-1.0, 1.6, k)
	elif u < hold:
		strike = 1.0
		lunge = lerp(1.6, 1.2, (u - snap) / (hold - snap))
	else:
		var k = smooth((u - hold) / (1.0 - hold))
		strike = 1.0 - k
		lunge = 1.2 * (1.0 - k)

func _process(delta: float):
	if preview or player == null or not is_instance_valid(player):
		queue_redraw()
		return
	t += delta
	var dt: float = max(delta, 0.0001)
	var vel: Vector2 = player.velocity
	var v: float = vel.length()
	var top: float = max(player.speed, 1.0)
	# Frame-rate independent easing toward each target
	move = lerp(move, clamp(v / top, 0.0, 1.6), 1.0 - exp(-dt * 8.0))
	swim += delta * (2.4 + 8.5 * min(move, 1.3))
	gait += v * delta / 16.0
	var rot: float = get_parent().global_rotation
	var dr = wrapf(rot - _last_rot, -PI, PI)
	_last_rot = rot
	bend = lerp(bend, clamp(dr / dt * 0.18, -1.0, 1.0), 1.0 - exp(-dt * 7.0))
	atk += delta
	_attack_curve()
	dash = lerp(dash, 1.0 if player.is_dashing else 0.0, 1.0 - exp(-dt * (30.0 if player.is_dashing else 6.0)))
	tuck = lerp(tuck, 1.0 if player.rooted_time > 0 else 0.0, 1.0 - exp(-dt * 10.0))
	# Flinch when hurt
	var hp = float(player.health)
	if _last_hp >= 0.0 and hp < _last_hp:
		hurt = 1.0
	_last_hp = hp
	hurt = max(0.0, hurt - delta / 0.28)
	# Body lags behind speeding up and overshoots when stopping: a spring on
	# the drawing pulled by the acceleration, in the body's own frame
	var acc = (vel - _last_vel) / dt
	_last_vel = vel
	var target = (-acc * 0.0035).rotated(-rot).limit_length(5.0)
	_lag_v += ((target - _lag) * 160.0 - _lag_v * 16.0) * dt
	_lag += _lag_v * dt
	# Stretch along the body while dashing, a slight breath while still
	var breath = sin(t * 2.6) * 0.012 * (1.0 - clamp(move, 0.0, 1.0))
	var want = Vector2(1.0 + 0.16 * dash + breath, 1.0 - 0.1 * dash - breath) * (1.0 - 0.07 * hurt)
	_stretch = _stretch.lerp(want, 1.0 - exp(-dt * 20.0))
	queue_redraw()

func _draw():
	if not FORMS.has(form_id):
		return
	var spec: Array = FORMS[form_id]
	# Whole-body motion: lunge into strikes, lag behind acceleration, shake
	# when hurt
	var off = Vector2(lunge * 4.0, 0) + _lag
	if hurt > 0.0:
		off += Vector2(sin(t * 70.0), cos(t * 53.0)) * 2.2 * hurt
	# Soft drop shadow, always cast down the screen
	var down = Vector2(3, 9).rotated(-global_rotation)
	draw_set_transform(down + off * 0.6, 0.0, _stretch)
	halo_pass = true
	_draw_shadow_pass(spec)
	draw_set_transform(off, 0.0, _stretch)
	_draw_form(spec)
	halo_pass = false
	_main_area = 0.0
	_draw_form(spec)

var shadow_pass: bool = false
func _draw_shadow_pass(spec: Array):
	shadow_pass = true
	_draw_form(spec)
	shadow_pass = false

func _draw_form(spec: Array):
	if spec.size() > 1:
		call(spec[0], spec[1])
	else:
		call(spec[0])

# ───────────────────────── drawing helpers ─────────────────────────
static func shade(c: Color, k: float) -> Color:
	if k < 1.0:
		return Color(c.r * k, c.g * k, c.b * k, c.a)
	return Color(c.r + (1.0 - c.r) * (k - 1.0), c.g + (1.0 - c.g) * (k - 1.0), c.b + (1.0 - c.b) * (k - 1.0), c.a)

static func c8(r: int, g: int, b: int, a: int = 255) -> Color:
	return Color8(r, g, b, a)

static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a = TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

func _rim_col() -> Color:
	return Color(0, 0, 0, 0.22) if shadow_pass else HALO

func _rim_w() -> float:
	return 0.0 if shadow_pass else 3.6

# Outlined filled polygon. The halo and shadow passes draw the silhouette only.
func shape(pts: PackedVector2Array, col: Color, w: float = OW) -> bool:
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return false
	if halo_pass:
		if w <= 0.0 or col.a < 0.5:
			return true
		var rim := pts.duplicate()
		rim.append(pts[0])
		if shadow_pass:
			draw_colored_polygon(pts, _rim_col())
		else:
			draw_polyline(rim, HALO, w + _rim_w(), true)
		return true
	draw_colored_polygon(pts, col)
	if w > 0 and col.a > 0.8:
		var r := Rect2(pts[0], Vector2.ZERO)
		for q in pts:
			r = r.expand(q)
		if r.get_area() > _main_area:
			_main_area = r.get_area()
			main_color = col
	if w > 0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, OUTLINE, w, true)
	return true

func fill(pts: PackedVector2Array, col: Color):
	if halo_pass or pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, col)
	# A hairline in the same colour smooths the polygon's jagged edge
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, col, 1.0, true)

func oval(c: Vector2, rx: float, ry: float, rot: float, col: Color, w: float = OW):
	shape(ellipse_pts(c, rx, ry, rot), col, w)

func blob(c: Vector2, rx: float, ry: float, rot: float, col: Color):
	fill(ellipse_pts(c, rx, ry, rot, 16), col)

func disc(c: Vector2, r: float, col: Color, w: float = OW):
	if halo_pass:
		if w > 0:
			draw_circle(c, r + w * 0.5 + (0.0 if shadow_pass else 2.5), _rim_col(), true, -1.0, true)
		return
	if w > 0:
		draw_circle(c, r + w * 0.5, OUTLINE, true, -1.0, true)
	draw_circle(c, r, col, true, -1.0, true)

func dot(c: Vector2, r: float, col: Color):
	if not halo_pass:
		draw_circle(c, r, col, true, -1.0, true)

func line(a: Vector2, b: Vector2, col: Color, w: float = 1.5):
	if not halo_pass:
		draw_line(a, b, col, w, true)

func pline(pts: PackedVector2Array, col: Color, w: float = 1.5):
	if not halo_pass and pts.size() > 1:
		draw_polyline(pts, col, w, true)

# A round-jointed stroke with an outline (legs, antennae, tentacles)
func limb(pts: PackedVector2Array, w: float, col: Color, outline: bool = true):
	if pts.size() < 2:
		return
	if halo_pass:
		if not outline:
			return
		var hw = w + 3.0 + _rim_w()
		draw_polyline(pts, _rim_col(), hw, true)
		for p in pts:
			draw_circle(p, hw * 0.5, _rim_col(), true, -1.0, true)
		return
	if outline:
		draw_polyline(pts, OUTLINE, w + 3.0, true)
		for p in pts:
			draw_circle(p, (w + 3.0) * 0.5, OUTLINE, true, -1.0, true)
	draw_polyline(pts, col, w, true)
	for p in pts:
		draw_circle(p, w * 0.5, col, true, -1.0, true)

# Tapered limb: each piece thinner than the last
func taper(pts: PackedVector2Array, w0: float, w1: float, col: Color, outline: bool = true):
	var n = pts.size()
	if n < 2:
		return
	if halo_pass:
		if not outline:
			return
		for i in n - 1:
			var w = lerp(w0, w1, i / float(max(n - 2, 1)))
			draw_line(pts[i], pts[i + 1], _rim_col(), w + 3.0 + _rim_w(), true)
			draw_circle(pts[i], (w + 3.0 + _rim_w()) * 0.5, _rim_col(), true, -1.0, true)
		draw_circle(pts[n - 1], (w1 + 3.0 + _rim_w()) * 0.5, _rim_col(), true, -1.0, true)
		return
	if outline:
		for i in n - 1:
			var w = lerp(w0, w1, i / float(max(n - 2, 1)))
			draw_line(pts[i], pts[i + 1], OUTLINE, w + 3.0, true)
			draw_circle(pts[i], (w + 3.0) * 0.5, OUTLINE, true, -1.0, true)
		draw_circle(pts[n - 1], (w1 + 3.0) * 0.5, OUTLINE, true, -1.0, true)
	for i in n - 1:
		var w = lerp(w0, w1, i / float(max(n - 2, 1)))
		draw_line(pts[i], pts[i + 1], col, w, true)
		draw_circle(pts[i], w * 0.5, col, true, -1.0, true)
	draw_circle(pts[n - 1], w1 * 0.5, col, true, -1.0, true)

func tube_pts(spine: Array, widths: Array) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n = spine.size()
	for i in n:
		var a: Vector2 = spine[max(i - 1, 0)]
		var b: Vector2 = spine[min(i + 1, n - 1)]
		var tn = (b - a).normalized()
		var nm = Vector2(-tn.y, tn.x)
		left.append(spine[i] + nm * widths[i])
		right.append(spine[i] - nm * widths[i])
	right.reverse()
	left.append_array(right)
	return left

func tube(spine: Array, widths: Array, col: Color, w: float = OW):
	if not shape(tube_pts(spine, widths), col, w):
		var avg = 0.0
		for x in widths:
			avg += x
		limb(PackedVector2Array(spine), 2.0 * avg / max(widths.size(), 1), col, w > 0)

# Tube with a shadowed belly side and a lit back, so round bodies read round
func tube_shaded(spine: Array, widths: Array, col: Color, w: float = OW):
	tube(spine, widths, col, 0.0 if not halo_pass else w)
	if halo_pass:
		return
	band(spine, widths, 1.0, 0.42, shade(col, 0.78))
	band(spine, widths, -1.0, 0.3, shade(col, 1.22), 0.25)
	if w > 0:
		var loop := tube_pts(spine, widths)
		loop.append(loop[0])
		draw_polyline(loop, OUTLINE, w, true)

func band(spine: Array, widths: Array, side: float, depth: float, col: Color, inset: float = 0.0):
	if halo_pass:
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n = spine.size()
	for i in n:
		var a: Vector2 = spine[max(i - 1, 0)]
		var b: Vector2 = spine[min(i + 1, n - 1)]
		var tn = (b - a).normalized()
		var nm = Vector2(-tn.y, tn.x) * side
		outer.append(spine[i] + nm * widths[i] * (1.0 - inset))
		inner.append(spine[i] + nm * widths[i] * (1.0 - inset - depth))
	inner.reverse()
	outer.append_array(inner)
	fill(outer, col)

# Glossy eye: outline, iris, pupil and a highlight
func eye(p: Vector2, r: float, iris: Color = Color(0.1, 0.1, 0.12), pupil: bool = true):
	if halo_pass:
		draw_circle(p, r + 1.5 + (0.0 if shadow_pass else 2.5), _rim_col(), true, -1.0, true)
		return
	draw_circle(p, r + 1.3, OUTLINE, true, -1.0, true)
	draw_circle(p, r, iris, true, -1.0, true)
	if pupil:
		draw_circle(p + Vector2(r * 0.15, 0), r * 0.5, Color(0.04, 0.04, 0.06), true, -1.0, true)
	draw_circle(p + Vector2(r * 0.25, -r * 0.35), max(r * 0.32, 0.8), Color(1, 1, 1, 0.9), true, -1.0, true)

# ── Spine of a long body ──
func spine_setup(hx: float, length: float, amp: float, k: float):
	head_x = hx
	body_len = length
	wave_amp = amp * (0.35 + 0.65 * clamp(move, 0.0, 1.2))
	wave_k = k

# Point on the body's midline at forward position x (head_x is the snout)
func sp(x: float) -> Vector2:
	var d = clamp((head_x - x) / body_len, 0.0, 1.4)
	var y = sin(swim - d * wave_k) * wave_amp * (0.12 + 0.88 * d * d) - bend * body_len * 0.3 * d * d
	return Vector2(x, y)

func sp_dir(x: float) -> Vector2:
	return (sp(x + 1.0) - sp(x - 1.0)).normalized()

# Point beside the midline: side > 0 is the right flank
func spo(x: float, side_dist: float) -> Vector2:
	var tn = sp_dir(x)
	return sp(x) + Vector2(-tn.y, tn.x) * side_dist

func sp_ang(x: float) -> float:
	return sp_dir(x).angle()

# Body outline along the spine: widths from a callable f(0 at head .. 1 at tail)
func spine_body(x0: float, x1: float, n: int, wfn: Callable, col: Color, w: float = OW):
	var spine := []
	var widths := []
	for i in n + 1:
		var f = i / float(n)
		var x = lerp(x0, x1, f)
		spine.append(sp(x))
		widths.append(max(0.4, wfn.call(f)))
	tube_shaded(spine, widths, col, w)

# Overlapping body segments (tergites) from tail to head along the spine
func segments(xs: Array, ws: Array, col: Color, alt: float = 0.86, rx: float = -1.0):
	var n = xs.size()
	for k in n:
		var i = n - 1 - k
		var x: float = xs[i]
		var len_ = rx if rx > 0 else (abs(xs[0] - xs[1]) * 0.78 if n > 1 else 6.0)
		var c = shade(col, 1.0 if i % 2 == 0 else alt)
		var a = sp_ang(x)
		oval(sp(x), len_, ws[i], a, c, OW)
		if not halo_pass:
			blob(sp(x) + Vector2(len_ * 0.2, -ws[i] * 0.3).rotated(a), len_ * 0.55, ws[i] * 0.42, a, shade(c, 1.2))
			draw_arc(sp(x), ws[i] * 0.86, a + PI * 0.6, a + PI * 1.4, 8, shade(c, 0.72), 1.2, true)

# Jointed leg: hip at `root`, sideways on `side`, stepping with the gait.
# rake > 0 sweeps the leg back, < 0 forward.
func leg(root: Vector2, side: float, length: float, phase: float, rake: float, w: float, col: Color, stride: float = 0.32):
	var cyc = gait + phase
	var amt = clamp(move * 1.3 + 0.05, 0.0, 1.0)
	var swing = sin(cyc) * length * stride * amt
	var lift = max(0.0, cos(cyc)) * amt
	var d1 = Vector2(-sin(rake), side * cos(rake))
	var d2 = Vector2(-sin(rake * 1.7 + sign(rake) * 0.15), side * cos(rake * 1.7 + sign(rake) * 0.15))
	var knee = root + d1 * length * 0.52 + Vector2(swing * 0.45, 0)
	var foot = knee + d2 * length * 0.56 * (1.0 - 0.18 * lift) + Vector2(swing * 0.55, 0)
	taper(PackedVector2Array([root, knee, foot]), w, w * 0.6, col)
	return foot

# Feeler from `root`: bows outwards on `side` and sways
func antenna(root: Vector2, side: float, length: float, spread: float, col: Color, w: float = 1.4, n: int = 7):
	var pts := PackedVector2Array()
	var a = side * spread
	var p = root
	pts.append(p)
	for i in n:
		var f = (i + 1) / float(n)
		a += side * 0.07 + sin(t * 3.0 + side + f * 2.0) * 0.05 * f - bend * 0.04
		p += Vector2.RIGHT.rotated(a) * (length / n)
		pts.append(p)
	limb(pts, w, col, true)
	return p

func soft_glow(r: float):
	if halo_pass:
		return
	for k in 3:
		draw_circle(Vector2.ZERO, r * (1.0 - k * 0.22), Color(HALO.r, HALO.g, HALO.b, 0.045), true, -1.0, true)

static func pv(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)

static func side_ph(side: float) -> float:
	return 0.0 if side < 0 else PI

func eyestalk(base: Vector2, side: float, length: float, r: float, col: Color, iris: Color):
	var a = sp_ang(base.x) + side * 0.95 + sin(t * 1.7 + side) * 0.12
	var tip = base + Vector2.RIGHT.rotated(a) * length
	taper(pv([base, tip]), 2.6, 2.2, col)
	eye(tip, r, iris)

# Tail fan of uropods and telson spreading back from x
func tail_fan(x: float, w: float, len_: float, col: Color, lobes: int = 5, spread: float = 0.62):
	var base = sp(x)
	var a = sp_ang(x) + PI
	var open = 0.85 + 0.15 * sin(swim * 1.3) + 0.2 * dash
	for k in lobes:
		var f = (k - (lobes - 1) / 2.0) / max((lobes - 1) / 2.0, 1.0)
		var aa = a + f * spread * open
		var tip = base + Vector2.RIGHT.rotated(aa) * len_ * (1.0 - 0.12 * abs(f))
		shape(ellipse_pts(base.lerp(tip, 0.55), len_ * 0.5, w, aa, 12), shade(col, 1.0 + 0.1 * abs(f)))
		line(base.lerp(tip, 0.15), base.lerp(tip, 0.9), shade(col, 0.72), 1.0)

# Pincer: arm from `base` reaching along `ang`, claw opening by `open` (0..1)
func chela(base: Vector2, ang: float, side: float, size: float, open: float, col: Color):
	var elbow = base + Vector2(9, side * 11).rotated(ang) * size
	var wrist = elbow + Vector2(11, -side * 3).rotated(ang) * size
	taper(pv([base, elbow, wrist]), 3.6 * size, 4.4 * size, col)
	var pa = ang - side * 0.15
	var palm = wrist + Vector2(7, 0).rotated(pa) * size
	# Movable finger (dactyl) on the inner side swings open
	var hinge = palm + Vector2(6, -side * 3.2).rotated(pa) * size
	var da = pa - side * (0.08 + 0.75 * open)
	var dtip = hinge + Vector2(13, side * 1.5).rotated(da) * size
	shape(pv([hinge + Vector2(0, -2.6).rotated(da) * size, dtip, hinge + Vector2(0, 2.6).rotated(da) * size]), shade(col, 1.15))
	# Fixed finger on the outer side
	var froot = palm + Vector2(6, side * 3.0).rotated(pa) * size
	var ftip = froot + Vector2(13, -side * 1.5).rotated(pa) * size
	shape(pv([froot + Vector2(0, -2.8).rotated(pa) * size, ftip, froot + Vector2(0, 2.8).rotated(pa) * size]), shade(col, 1.05))
	oval(palm, 9 * size, 6.2 * size, pa, shade(col, 1.08))
	blob(palm + Vector2(1, -side * 2).rotated(pa) * size, 5 * size, 2.5 * size, pa, shade(col, 1.3))

func head_shine(c: Vector2, rx: float, ry: float, a: float, col: Color):
	blob(c + Vector2(rx * 0.2, -ry * 0.35).rotated(a), rx * 0.5, ry * 0.32, a, shade(col, 1.3))

# ───────────────────────── arthropods ─────────────────────────
func early_arthropod():
	# Fuxianhuia-like stem arthropod: head shield, one pair of antennae,
	# stalked eyes, 11 trunk segments with a pair of limbs each, tail fan.
	var body = c8(90, 150, 190)
	var lc = c8(205, 165, 135)
	spine_setup(42, 90, 3.0, 2.2)
	var xs := []
	var ws := []
	for i in 11:
		xs.append(22.0 - i * 5.0)
		ws.append(14.0 - i * 0.75)
	for i in 11:
		for side in [-1.0, 1.0]:
			leg(spo(xs[i], side * ws[i] * 0.6), side, 12.0 - i * 0.3, i * 0.7, 0.25, 2.2, lc, 0.4)
	tail_fan(-31, 3.5, 13.0, shade(body, 1.15), 3)
	segments(xs, ws, body)
	var a = sp_ang(30)
	oval(sp(30), 11, 17, a, shade(body, 1.08))
	head_shine(sp(30), 11, 17, a, shade(body, 1.08))
	for side in [-1.0, 1.0]:
		antenna(spo(39, side * 3.5), side, 24, 0.25, c8(150, 230, 220), 1.5)
		eyestalk(spo(37, side * 6), side, 6, 2.8, shade(body, 0.9), c8(30, 40, 50))

func chelicerate():
	# Early chelicerate (eurypterid-like): no antennae, small pincer-like
	# chelicerae, a prosoma shield carrying the walking legs, 8 segments
	# behind it and a spine-like telson.
	var body = c8(150, 110, 170)
	spine_setup(40, 90, 2.5, 2.0)
	var xs := []
	var ws := []
	for i in 8:
		xs.append(6.0 - i * 4.6)
		ws.append(12.0 - i * 1.0)
	for i in 4:
		for side in [-1.0, 1.0]:
			leg(spo(24 - i * 4.5, side * 8), side, 20 + i * 2.0, i * 1.4 + side_ph(side), -0.35 + i * 0.3, 2.4, shade(body, 0.82))
	var tb = sp(xs[7] - 2)
	var ta = sp_ang(xs[7]) + PI + sin(t * 2.0) * 0.12
	taper(pv([tb, tb + Vector2.RIGHT.rotated(ta) * 9, tb + Vector2.RIGHT.rotated(ta) * 20]), 3.6, 1.0, shade(body, 1.15))
	segments(xs, ws, body)
	var a = sp_ang(22)
	for side in [-1.0, 1.0]:
		var b = spo(33, side * 4)
		var ca = a + side * (0.2 + 0.5 * strike)
		var tip = b + Vector2.RIGHT.rotated(ca) * 9
		taper(pv([b, tip]), 3.2, 2.2, shade(body, 1.1))
		line(tip, tip + Vector2.RIGHT.rotated(ca - side * 1.2) * 4, OUTLINE, 1.6)
	oval(sp(22), 14, 15, a, shade(body, 1.05))
	head_shine(sp(22), 14, 15, a, shade(body, 1.05))
	for side in [-1.0, 1.0]:
		eye(spo(26, side * 9), 2.6, c8(255, 140, 200))
		dot(spo(29, side * 1.5), 1.1, c8(255, 200, 230))

func mandibulate():
	# Early mandibulate: long antennae, mandibles, a long trunk of 12
	# segments with one leg pair each.
	var body = c8(110, 160, 110)
	var lc = c8(210, 190, 140)
	spine_setup(44, 92, 4.0, 3.0)
	var xs := []
	var ws := []
	for i in 12:
		xs.append(28.0 - i * 5.4)
		ws.append(10.5 - i * 0.38)
	for i in 12:
		for side in [-1.0, 1.0]:
			leg(spo(xs[i], side * ws[i] * 0.6), side, 12.0, i * 0.9 + side_ph(side), 0.15, 2.0, lc)
	segments(xs, ws, body)
	var a = sp_ang(36)
	oval(sp(36), 7, 9.5, a, shade(body, 1.1))
	head_shine(sp(36), 7, 9.5, a, shade(body, 1.1))
	for side in [-1.0, 1.0]:
		var m = spo(42, side * 3)
		line(m, m + Vector2(4, -side * (1.5 + 2.0 * strike)).rotated(a), c8(250, 220, 150), 2.2)
		eye(spo(38, side * 5), 2.3)
		antenna(spo(42, side * 2.5), side, 30, 0.3, c8(150, 230, 220), 1.4)

func arachnid():
	# Early arachnid (trigonotarbid-like): chelicerae, short pedipalps,
	# four pairs of walking legs, prosoma and a segmented opisthosoma.
	var body = c8(140, 100, 80)
	spine_setup(34, 70, 1.5, 1.5)
	var rk = [-0.75, -0.25, 0.25, 0.7]
	var ln = [24.0, 26.0, 25.0, 27.0]
	for i in 4:
		for side in [-1.0, 1.0]:
			leg(spo(22 - i * 3.0, side * 7), side, ln[i], i * 1.6 + side_ph(side), rk[i], 2.4, shade(body, 0.85), 0.36)
	var xs := []
	var ws := []
	for i in 6:
		xs.append(6.0 - i * 5.2)
		ws.append(13.0 - i * 1.3)
	segments(xs, ws, body, 0.82)
	var a = sp_ang(18)
	for side in [-1.0, 1.0]:
		var b = spo(26, side * 5)
		taper(pv([b, b + Vector2(7, side * 5).rotated(a), b + Vector2(13, side * 3).rotated(a)]), 2.6, 2.0, shade(body, 1.2))
	oval(sp(19), 11, 10, a, shade(body, 1.1))
	head_shine(sp(19), 11, 10, a, shade(body, 1.1))
	for side in [-1.0, 1.0]:
		eye(spo(25, side * 2.2), 1.7, c8(255, 120, 90))

func horseshoe_crab(p: Dictionary = {}):
	# Xiphosuran: broad horseshoe prosoma with lateral compound eyes, a
	# hinged opisthosoma with movable edge spines and a long tail spine.
	var body: Color = p.get("col", c8(120, 110, 80))
	spine_setup(42, 90, 0.8, 1.0)
	for i in 5:
		for side in [-1.0, 1.0]:
			leg(spo(12 - i * 3.5, side * 10), side, 21, i * 1.3 + side_ph(side), 0.1 + i * 0.12, 2.2, shade(body, 0.65))
	var tb = sp(-14)
	var ta = sp_ang(-14) + PI + sin(t * 1.4) * 0.18 + bend * 0.4
	taper(pv([tb, tb + Vector2.RIGHT.rotated(ta) * 18, tb + Vector2.RIGHT.rotated(ta) * 42]), 4.2, 1.6, shade(body, 0.92))
	var o = sp(-3)
	var oa = sp_ang(-3) + bend * 0.15
	var op := []
	for q in [Vector2(10, -18), Vector2(-5, -16), Vector2(-13, -8), Vector2(-15, 0), Vector2(-13, 8), Vector2(-5, 16), Vector2(10, 18)]:
		op.append(o + q.rotated(oa))
	for k in 6:
		for side in [-1.0, 1.0]:
			var e = o + Vector2(7 - k * 3.4, side * (17.5 - k * 1.4)).rotated(oa)
			limb(pv([e, e + Vector2(-2.5, side * (4.0 + sin(t * 3 + k) * 0.6)).rotated(oa)]), 1.4, shade(body, 0.8))
	shape(pv(op), shade(body, 0.9))
	line(o + Vector2(8, 0).rotated(oa), o + Vector2(-12, 0).rotated(oa), shade(body, 1.25), 2.0)
	var c = sp(12)
	var a = sp_ang(12)
	var pro := []
	for k in 17:
		var g = -PI / 2 + PI * k / 16.0
		pro.append(c + Vector2(cos(g) * 31, sin(g) * 29).rotated(a))
	pro.append(c + Vector2(-5, 22).rotated(a))
	pro.append(c + Vector2(-3, 0).rotated(a))
	pro.append(c + Vector2(-5, -22).rotated(a))
	shape(pv(pro), body)
	var inner := []
	for k in 13:
		var g = -PI / 2 + PI * k / 12.0
		inner.append(c + Vector2(cos(g) * 20, sin(g) * 13).rotated(a))
	pline(pv(inner), shade(body, 0.72), 1.6)
	line(c + Vector2(29, 0).rotated(a), c + Vector2(-2, 0).rotated(a), shade(body, 1.3), 2.0)
	blob(c + Vector2(14, -14).rotated(a), 9, 5, a + 0.5, shade(body, 1.25))
	for side in [-1.0, 1.0]:
		eye(c + Vector2(10, side * 17).rotated(a), 2.6, p.get("eye", c8(180, 230, 255)))
		dot(c + Vector2(24, side * 1.6).rotated(a), 1.0, c8(180, 230, 255))
	if p.get("crust", false):
		for k in 9:
			dot(c + Vector2(cos(k * 2.3) * 20, sin(k * 2.3) * 18).rotated(a), 1.3, c8(120, 140, 90))

func myriapod():
	# Early myriapod: one pair of antennae, 16 trunk segments, one leg pair
	# per segment rippling in a wave.
	var body = c8(170, 120, 70)
	spine_setup(44, 92, 6.0, 4.5)
	var xs := []
	var ws := []
	for i in 16:
		xs.append(34.0 - i * 4.6)
		ws.append(7.0 - i * 0.12)
	for i in 16:
		for side in [-1.0, 1.0]:
			leg(spo(xs[i], side * 4), side, 9.0, i * 0.7, 0.2, 1.8, shade(body, 0.72))
	segments(xs, ws, body)
	oval(sp(40), 6, 7, sp_ang(40), shade(body, 1.15))
	for side in [-1.0, 1.0]:
		eye(spo(42, side * 3.5), 1.6)
		antenna(spo(44, side * 2), side, 16, 0.3, c8(150, 230, 220), 1.3)

func malacostracan():
	# Shrimp-like malacostracan: two pairs of antennae, stalked eyes,
	# carapace, 5 walking leg pairs, 6-segment abdomen and tail fan.
	var body = c8(200, 120, 90)
	spine_setup(44, 92, 3.0, 2.0)
	for i in 5:
		for side in [-1.0, 1.0]:
			leg(spo(26 - i * 3.5, side * 8), side, 15, i * 1.3 + side_ph(side), -0.15 + i * 0.15, 2.0, shade(body, 0.85))
	var xs := []
	var ws := []
	for i in 6:
		xs.append(4.0 - i * 5.2)
		ws.append(10.0 - i * 0.8)
	for i in 6:
		for side in [-1.0, 1.0]:
			var pr = spo(xs[i], side * ws[i] * 0.8)
			limb(pv([pr, pr + Vector2(-3 + sin(swim * 2 - i) * 2, side * 4).rotated(sp_ang(xs[i]))]), 1.4, shade(body, 1.2))
	tail_fan(-28, 3.6, 13.0, shade(body, 1.12), 5)
	segments(xs, ws, body)
	var a = sp_ang(18)
	shape(pv([sp(30) + Vector2(0, -3).rotated(a), sp(42), sp(30) + Vector2(0, 3).rotated(a)]), shade(body, 1.1))
	oval(sp(18), 16, 12, a, body)
	head_shine(sp(18), 16, 12, a, body)
	line(sp(32), sp(6), shade(body, 0.75), 1.2)
	for side in [-1.0, 1.0]:
		antenna(spo(33, side * 3), side, 14, 0.15, c8(250, 200, 160), 1.3, 5)
		antenna(spo(32, side * 5), side, 36, 0.55, c8(250, 200, 160), 1.3, 8)
		eyestalk(spo(32, side * 4), side, 6, 2.8, shade(body, 0.9), c8(30, 30, 30))

func hexapod():
	# Wingless early hexapod (silverfish-like): one pair of long antennae,
	# 3 thorax segments with one leg pair each, a tapering abdomen and
	# three tail filaments.
	var body = c8(200, 175, 110)
	spine_setup(40, 86, 3.0, 2.5)
	for i in 3:
		for side in [-1.0, 1.0]:
			leg(spo(26 - i * 6.5, side * 7), side, 17, i * 2.1 + side_ph(side), -0.5 + i * 0.55, 2.2, shade(body, 0.78), 0.4)
	var xs := []
	var ws := []
	for i in 9:
		xs.append(7.0 - i * 3.9)
		ws.append(8.5 - i * 0.65)
	var tb = sp(xs[8] - 2)
	for k in [-0.35, 0.0, 0.35]:
		var a2 = sp_ang(xs[8]) + PI + k + sin(t * 3 + k * 4) * 0.08
		limb(pv([tb, tb + Vector2.RIGHT.rotated(a2) * 10, tb + Vector2.RIGHT.rotated(a2 + k * 0.3) * 20]), 1.2, shade(body, 1.15))
	segments(xs, ws, body)
	segments([26.0, 19.5, 13.0], [9.5, 10.0, 9.5], shade(body, 0.95), 0.88, 4.5)
	var a = sp_ang(34)
	oval(sp(34), 6.5, 7, a, shade(body, 1.1))
	for side in [-1.0, 1.0]:
		eye(spo(35, side * 4.5), 1.8, c8(60, 40, 20))
		antenna(spo(39, side * 2), side, 30, 0.25, c8(230, 210, 150), 1.3)

func decapod():
	# Lobster-like decapod: stalked eyes, two pairs of antennae, the first
	# legs as big claws (crusher bigger than cutter) snapping on attack,
	# 4 walking leg pairs, 6-segment abdomen and tail fan.
	var body = c8(190, 60, 45)
	spine_setup(42, 92, 2.5, 1.8)
	for i in 4:
		for side in [-1.0, 1.0]:
			leg(spo(20 - i * 3.5, side * 7), side, 15, i * 1.3 + side_ph(side), -0.1 + i * 0.18, 2.0, shade(body, 0.85))
	var xs := []
	var ws := []
	for i in 6:
		xs.append(0.0 - i * 5.0)
		ws.append(9.5 - i * 0.5)
	tail_fan(-30, 3.8, 13.0, shade(body, 1.12), 5)
	segments(xs, ws, body)
	var a = sp_ang(14)
	var snap = clamp(strike * 1.5, 0.0, 1.0)
	var open = 0.2 + 0.25 * sin(t * 2.0) * 0.5 + 0.6 * (1.0 - abs(snap - 0.5) * 2.0)
	chela(spo(24, -7), a - 0.35, -1.0, 1.15, open, shade(body, 1.0))
	chela(spo(24, 7), a + 0.35, 1.0, 0.92, open, shade(body, 1.0))
	shape(pv([sp(26) + Vector2(0, -3).rotated(a), sp(36), sp(26) + Vector2(0, 3).rotated(a)]), shade(body, 1.1))
	oval(sp(14), 15, 11, a, body)
	head_shine(sp(14), 15, 11, a, body)
	line(sp(27), sp(2), shade(body, 0.7), 1.2)
	for side in [-1.0, 1.0]:
		antenna(spo(28, side * 2), side, 10, 0.12, c8(250, 180, 140), 1.2, 4)
		antenna(spo(27, side * 4), side, 40, 0.6, c8(250, 180, 140), 1.4, 8)
		eyestalk(spo(27, side * 3), side, 5, 2.6, shade(body, 0.85), c8(30, 30, 30))

func scorpion():
	# Scorpion: pedipalps with big claws, 4 pairs of legs, 7-segment
	# mesosoma, 5-segment tail and a stinging telson that strikes on attack.
	var body = c8(70, 68, 80)
	var lc = shade(body, 1.45)
	spine_setup(30, 70, 1.6, 1.5)
	var rk = [-0.5, -0.15, 0.2, 0.5]
	for i in 4:
		for side in [-1.0, 1.0]:
			leg(spo(20 - i * 3.5, side * 7), side, 22, i * 1.5 + side_ph(side), rk[i], 2.2, lc, 0.36)
	var xs := []
	var ws := []
	for i in 7:
		xs.append(8.0 - i * 4.2)
		ws.append(10.5 - i * 0.25 - (i * 0.6 if i > 4 else 0.0))
	# Tail curls round to one side; an attack whips it further round
	var p = sp(xs[6] - 3)
	var ang = sp_ang(xs[6]) + PI
	var curl = 0.42 + 0.06 * sin(t * 2.0) + strike * 0.35 - bend * 0.2
	var tail := []
	for k in 5:
		ang += curl
		var np = p + Vector2.RIGHT.rotated(ang) * 7.5
		tail.append([p.lerp(np, 0.5), ang])
		p = np
	segments(xs, ws, body, 0.8)
	for k in 5:
		oval(tail[k][0], 4.8, 4.2 - k * 0.2, tail[k][1], shade(body, 1.25 if k % 2 else 1.12))
	var sa = ang + curl
	oval(p + Vector2.RIGHT.rotated(sa) * 3, 4.6, 3.6, sa, c8(220, 180, 70))
	var barb = p + Vector2.RIGHT.rotated(sa) * 7
	shape(pv([barb + Vector2(0, -1.6).rotated(sa), barb + Vector2.RIGHT.rotated(sa + 0.6) * 6, barb + Vector2(0, 1.6).rotated(sa)]), c8(40, 30, 30), 1.0)
	var a = sp_ang(20)
	var open = 0.25 + 0.15 * sin(t * 1.6) + 0.4 * strike
	for side in [-1.0, 1.0]:
		chela(spo(24, side * 6), a + side * 0.55, side, 0.85, open, lc)
	oval(sp(20), 11, 10, a, shade(body, 1.2))
	head_shine(sp(20), 11, 10, a, shade(body, 1.2))
	for side in [-1.0, 1.0]:
		eye(spo(23, side * 2.0), 1.6, c8(120, 255, 200))

func spider():
	# Spider: two body parts (cephalothorax and an unsegmented abdomen with
	# spinnerets), 8 long legs, short pedipalps, fanged chelicerae, 8 eyes.
	var body = c8(90, 70, 110)
	spine_setup(28, 60, 0.6, 1.0)
	var rk = [-0.95, -0.35, 0.35, 0.9]
	var ln = [32.0, 30.0, 28.0, 33.0]
	for i in 4:
		for side in [-1.0, 1.0]:
			var ph = (0.0 if i % 2 == 0 else PI) + side_ph(side)
			leg(spo(13 - i * 2.2, side * 5), side, ln[i], ph, rk[i], 2.4, shade(body, 0.8), 0.32)
	var ab = sp(-12)
	var aa = sp_ang(-12) - bend * 0.3
	oval(ab, 16, 13, aa, body)
	head_shine(ab, 16, 13, aa, body)
	for k in 3:
		var y0 = ab + Vector2(6 - k * 6, 0).rotated(aa)
		pline(pv([y0 + Vector2(-3, -5).rotated(aa), y0, y0 + Vector2(-3, 5).rotated(aa)]), c8(240, 200, 80), 1.8)
	for side in [-1.0, 1.0]:
		dot(ab + Vector2(-16, side * 1.5).rotated(aa), 1.4, OUTLINE)
	var a = sp_ang(10)
	for side in [-1.0, 1.0]:
		var b = spo(18, side * 4)
		taper(pv([b, b + Vector2(5, side * 5).rotated(a), b + Vector2(10, side * 4).rotated(a)]), 2.4, 2.0, shade(body, 1.2))
		var f0 = spo(20, side * 2)
		oval(f0, 3.2, 2.4, a, shade(body, 0.9), 1.4)
		line(f0 + Vector2(2, 0).rotated(a), f0 + Vector2(5, -side * (1.0 + 2.0 * strike)).rotated(a), c8(240, 240, 240), 1.4)
	oval(sp(9), 11, 9.5, a, shade(body, 1.15))
	head_shine(sp(9), 11, 9.5, a, shade(body, 1.15))
	for q in [Vector2(15, -2), Vector2(15, 2)]:
		eye(at(9, q), 1.8, c8(40, 220, 210))
	for q in [Vector2(13, -4.5), Vector2(13, 4.5), Vector2(12.5, -1.3), Vector2(12.5, 1.3), Vector2(10.5, -5), Vector2(10.5, 5)]:
		dot(at(9, q), 0.9, c8(120, 255, 240))

func centipede():
	# Centipede: flattened, one leg pair per segment (15 pairs), venom
	# claws (forcipules) that snap on attack, long antennae and long
	# backward-pointing last legs.
	var body = c8(200, 90, 50)
	var lc = c8(240, 190, 90)
	spine_setup(44, 94, 7.0, 4.0)
	var xs := []
	var ws := []
	for i in 15:
		xs.append(33.0 - i * 5.0)
		ws.append(7.5 - i * 0.12)
	for i in 15:
		for side in [-1.0, 1.0]:
			leg(spo(xs[i], side * 4), side, 12.0, i * 0.8, 0.35, 1.8, lc, 0.42)
	var last = xs[14]
	for side in [-1.0, 1.0]:
		var b = spo(last, side * 4)
		var la = sp_ang(last) + PI + side * 0.35
		taper(pv([b, b + Vector2.RIGHT.rotated(la) * 9, b + Vector2.RIGHT.rotated(la - side * 0.15) * 20]), 2.0, 1.2, lc)
	segments(xs, ws, body, 0.72)
	var a = sp_ang(39)
	for side in [-1.0, 1.0]:
		var b = spo(41, side * 3)
		var o = side * (0.5 - 0.45 * strike)
		pline(pv([b, b + Vector2(4, side * 3).rotated(a + o), b + Vector2(8, side * 0.5).rotated(a + o)]), OUTLINE, 3.0)
		pline(pv([b, b + Vector2(4, side * 3).rotated(a + o), b + Vector2(8, side * 0.5).rotated(a + o)]), c8(60, 30, 25), 1.6)
	oval(sp(39), 6.5, 7.5, a, shade(body, 1.1))
	head_shine(sp(39), 6.5, 7.5, a, shade(body, 1.1))
	for side in [-1.0, 1.0]:
		antenna(spo(43, side * 2), side, 22, 0.35, lc, 1.4)

func millipede():
	# Millipede: rounded body, two leg pairs per segment, short elbowed
	# antennae, slow leg ripple.
	var body = c8(80, 70, 90)
	spine_setup(44, 92, 3.5, 3.0)
	var xs := []
	var ws := []
	for i in 14:
		xs.append(32.0 - i * 5.4)
		ws.append(7.5 if i < 12 else 7.5 - (i - 11) * 1.3)
	for i in 14:
		for k in 2:
			for side in [-1.0, 1.0]:
				var x = xs[i] + k * 2.6 - 1.3
				leg(spo(x, side * 4.5), side, 7.0, i * 0.6 + k * 0.3, 0.1, 1.4, c8(230, 200, 160), 0.4)
	segments(xs, ws, body, 0.8)
	for i in 14:
		for side in [-1.0, 1.0]:
			dot(spo(xs[i], side * ws[i] * 0.72), 1.3, c8(230, 140, 70))
	var a = sp_ang(38)
	oval(sp(39), 6.5, 7, a, shade(body, 1.15))
	for side in [-1.0, 1.0]:
		var b = spo(43, side * 2.5)
		limb(pv([b, b + Vector2(3, side * 3).rotated(a), b + Vector2(7, side * 2).rotated(a)]), 1.4, c8(230, 200, 160))

func dragonfly_line():
	# Odonata: four wings beating out of phase, huge compound eyes, three
	# leg pairs tucked under the thorax, a 10-segment abdomen with claspers.
	var body = c8(60, 140, 200)
	spine_setup(30, 80, 1.5, 1.2)
	var beat_rate = 9.0 + 24.0 * clamp(move, 0.0, 1.2)
	for row in 2:
		var x0 = 16.0 - row * 7.0
		var ph = row * PI * 0.5
		var beat = sin(t * beat_rate + ph)
		for side in [-1.0, 1.0]:
			var span = (38.0 - row * 2.0) * (0.8 + 0.2 * beat)
			var root = spo(x0, side * 3)
			var a = sp_ang(x0) + side * (PI * 0.5 + (0.12 if row == 0 else -0.05)) + side * beat * 0.06
			var tip = root + Vector2.RIGHT.rotated(a) * span
			var wing = ellipse_pts(root.lerp(tip, 0.5), span * 0.5, 5.5 - row * 0.3, a, 18)
			fill(wing, Color(0.86, 0.95, 1.0, 0.55))
			if not halo_pass:
				var loop = wing.duplicate()
				loop.append(wing[0])
				draw_polyline(loop, Color(0.12, 0.22, 0.3, 1.0), 1.6, true)
				line(root, tip, Color(0.25, 0.4, 0.5, 0.8), 1.0)
				line(root.lerp(tip, 0.2), root.lerp(tip, 0.95) + Vector2(0, 2).rotated(a), Color(0.25, 0.4, 0.5, 0.5), 0.8)
				blob(root.lerp(tip, 0.86) + Vector2(0, -1.5).rotated(a), 2.4, 1.2, a, Color(0.12, 0.2, 0.3))
	var xs := []
	var ws := []
	for i in 10:
		xs.append(5.0 - i * 4.4)
		ws.append(3.1 - (0.0 if i < 8 else 0.4))
	segments(xs, ws, body, 0.75, 2.6)
	var cl = sp(xs[9] - 3)
	for side in [-1.0, 1.0]:
		line(cl, cl + Vector2(-4, side * 2).rotated(sp_ang(xs[9])), OUTLINE, 1.4)
	var a = sp_ang(14)
	oval(sp(13), 7.5, 6.5, a, shade(body, 0.9))
	head_shine(sp(13), 7.5, 6.5, a, shade(body, 0.9))
	oval(sp(23), 4.5, 6, a, body)
	for side in [-1.0, 1.0]:
		eye(spo(25, side * 4.2), 4.6, c8(90, 230, 160), false)

func beetle():
	# Beetle: hard wing cases (elytra) meeting in a straight line, which lift
	# to let the flying wings out during a dash; pronotum, clubbed antennae,
	# 3 leg pairs.
	var body = c8(40, 120, 90)
	spine_setup(30, 70, 0.5, 1.0)
	var rk = [-0.6, 0.0, 0.6]
	for i in 3:
		for side in [-1.0, 1.0]:
			var ph = (0.0 if i % 2 == 0 else PI) + side_ph(side)
			leg(spo(16 - i * 8.0, side * 9), side, 17, ph, rk[i], 2.4, c8(30, 40, 40), 0.36)
	var c = sp(-4)
	var a = sp_ang(-4)
	var lift = dash
	if lift > 0.05:
		for side in [-1.0, 1.0]:
			var root = c + Vector2(10, side * 2).rotated(a)
			var wa = a + side * (PI * 0.62 + sin(t * 40.0) * 0.15)
			fill(ellipse_pts(root + Vector2.RIGHT.rotated(wa) * 16 * lift, 16 * lift, 5, wa, 14), Color(0.85, 0.9, 0.95, 0.45))
	for side in [-1.0, 1.0]:
		var open = side * lift * 0.5
		var hinge = c + Vector2(12, side * 0.5).rotated(a)
		var pts := []
		for k in 13:
			var g = PI * k / 12.0
			pts.append(Vector2(12 - (1.0 - cos(g)) * 15.0, side * sin(g) * 13.0))
		var ep := []
		for q in pts:
			ep.append(hinge + (q - Vector2(12, 0)).rotated(open).rotated(a))
		shape(pv(ep), body)
		blob(hinge + Vector2(-12, side * 6).rotated(a + open), 8, 3, a + open + side * 0.2, shade(body, 1.45))
		pline(pv([hinge + Vector2(-4, side * 7).rotated(a + open), hinge + Vector2(-22, side * 8).rotated(a + open)]), shade(body, 0.75), 1.0)
	var pa = sp_ang(12)
	oval(sp(12), 6.5, 11, pa, shade(body, 0.85))
	head_shine(sp(12), 6.5, 11, pa, shade(body, 0.85))
	oval(sp(20), 4.5, 6.5, pa, shade(body, 0.72))
	for side in [-1.0, 1.0]:
		var tip = antenna(spo(23, side * 3), side, 13, 0.35, c8(60, 60, 50), 1.3, 5)
		disc(tip, 2.0, c8(70, 70, 60), 1.2)
		eye(spo(21, side * 4.2), 1.7, c8(200, 255, 120))
		line(spo(24.5, side * 1.5), spo(26.5, side * (0.5 + strike * 2.0)), OUTLINE, 1.8)

func mantis_shrimp_line():
	# Stomatopod: stalked eyes, raptorial clubs folded under the head that
	# punch out on attack, short carapace, broad abdomen with swimmerets
	# and a colourful tail fan.
	var body = c8(70, 170, 120)
	var pink = c8(240, 120, 160)
	spine_setup(40, 88, 3.0, 2.0)
	var xs := []
	var ws := []
	for i in 6:
		xs.append(6.0 - i * 5.0)
		ws.append(10.5 + i * 0.2)
	for i in 6:
		for side in [-1.0, 1.0]:
			var pr = spo(xs[i], side * ws[i] * 0.85)
			limb(pv([pr, pr + Vector2(-2 + sin(swim * 2 - i) * 2.5, side * 4).rotated(sp_ang(xs[i]))]), 1.6, pink)
	for i in 3:
		for side in [-1.0, 1.0]:
			leg(spo(13 - i * 3.0, side * 7), side, 10, i * 1.5 + side_ph(side), 0.1, 1.6, pink)
	tail_fan(-26, 4.0, 11.0, pink, 4, 0.8)
	oval(sp(-27), 6, 6.5, sp_ang(-27), shade(body, 1.15))
	segments(xs, ws, body)
	var a = sp_ang(18)
	var punch = clamp(strike * 1.6, 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var b = spo(24, side * 6)
		var elbow = b + Vector2(9 + 8 * punch, side * 6).rotated(a)
		var club = elbow + Vector2(-7 + 22 * punch, side * (1.0 - punch)).rotated(a)
		taper(pv([b, elbow, club]), 3.6, 3.0, pink)
		disc(club, 3.4, c8(255, 170, 200), 1.6)
	oval(sp(17), 11, 10.5, a, shade(body, 1.05))
	head_shine(sp(17), 11, 10.5, a, shade(body, 1.05))
	for side in [-1.0, 1.0]:
		oval(spo(28, side * 7), 4, 2.4, a + side * 0.6, c8(250, 170, 70), 1.4)
		antenna(spo(28, side * 2), side, 12, 0.1, c8(250, 200, 120), 1.2, 4)
		eyestalk(spo(27, side * 2.5), side, 6, 3.0, shade(body, 0.9), c8(120, 220, 255))

# Point at (x, y) in the frame of the body at spine position x0
func at(x0: float, q: Vector2) -> Vector2:
	return sp(x0) + Vector2(q.x - x0, q.y).rotated(sp_ang(x0))

# ───────────────────────── fish and kin ─────────────────────────
func fin_lobe(root: Vector2, ang: float, length: float, width: float, col: Color, rays: int = 3):
	var tip = root + Vector2.RIGHT.rotated(ang) * length
	shape(ellipse_pts(root.lerp(tip, 0.5), length * 0.55, width, ang, 14), col)
	for k in rays:
		var f = (k + 1.0) / (rays + 1.0)
		line(root, tip + Vector2(0, (f - 0.5) * width * 1.4).rotated(ang), shade(col, 0.8), 1.0)

# Streamlined fish seen from above. Keys: col, len, w, tail (fork, hetero,
# round, whip), pect, pelv, gill (slits per side), armour, scales, scutes,
# barbels, spine (fin spine), eye, eye_col, fin, shark (pointed snout and
# dorsal fin), shovel (sturgeon snout), shield (osteostracan head shield)
func fish(p: Dictionary):
	var col: Color = p.col
	var L: float = p.get("len", 84.0)
	var W: float = p.get("w", 12.0) * 1.3
	var fc: Color = p.get("fin", shade(col, 1.18))
	var hx = L * 0.5
	spine_setup(hx, L, p.get("amp", 8.0), 2.4)
	var tx = hx - L
	var tb = sp(tx + 4)
	var ta = sp_ang(tx + 4) + PI
	match p.get("tail", "fork"):
		"fork":
			var t1 = tb + Vector2.RIGHT.rotated(ta - 0.6) * 17
			var t2 = tb + Vector2.RIGHT.rotated(ta + 0.6) * 17
			shape(pv([tb + Vector2(0, -2.5).rotated(ta), t1, tb + Vector2.RIGHT.rotated(ta) * 7, t2, tb + Vector2(0, 2.5).rotated(ta)]), fc)
			line(tb, tb.lerp(t1, 0.8), shade(fc, 0.8), 1.0)
			line(tb, tb.lerp(t2, 0.8), shade(fc, 0.8), 1.0)
		"hetero":
			var t1 = tb + Vector2.RIGHT.rotated(ta - 0.32) * 21
			var t2 = tb + Vector2.RIGHT.rotated(ta + 0.55) * 11
			shape(pv([tb + Vector2(0, -2.5).rotated(ta), t1, tb + Vector2.RIGHT.rotated(ta) * 8, t2, tb + Vector2(0, 2.5).rotated(ta)]), fc)
			line(tb, tb.lerp(t1, 0.85), shade(fc, 0.8), 1.0)
		"round":
			oval(tb + Vector2.RIGHT.rotated(ta) * 7, 9, 7, ta, fc)
		"whip":
			var w2 = tb + Vector2.RIGHT.rotated(ta + sin(swim - 1.0) * 0.3) * 13
			var w3 = w2 + Vector2.RIGHT.rotated(ta + sin(swim - 2.0) * 0.5) * 14
			taper(pv([tb, w2, w3]), 3.0, 0.8, fc)
	var pect: float = p.get("pect", 14.0)
	if pect > 0:
		for side in [-1.0, 1.0]:
			var x = hx - L * 0.3
			var flap = sin(swim * 0.9 + side) * 0.22
			if p.get("shark", false):
				# Stiff swept-back triangle
				var r = spo(x, side * W * 0.6)
				var fa = sp_ang(x) + side * (PI * 0.72 + flap * 0.4)
				shape(pv([r + Vector2(4, 0).rotated(sp_ang(x)), r + Vector2.RIGHT.rotated(fa) * pect, r + Vector2(-9, side * 1.0).rotated(sp_ang(x))]), fc)
			else:
				fin_lobe(spo(x, side * W * 0.75), sp_ang(x) + side * (PI * 0.7 + flap), pect, pect * 0.32, fc, 3)
	var pelv: float = p.get("pelv", 0.0)
	if pelv > 0:
		for side in [-1.0, 1.0]:
			var x = hx - L * 0.6
			fin_lobe(spo(x, side * W * 0.5), sp_ang(x) + side * (PI * 0.78 + sin(swim + side) * 0.15), pelv, pelv * 0.35, fc, 2)
	var shark: bool = p.get("shark", false)
	var shovel: bool = p.get("shovel", false)
	var nose = 0.75 if (shark or shovel) else 0.5
	var wfn = func(f):
		if f < 0.33:
			return max(2.4, W * pow(sin(PI * 0.5 * f / 0.33), nose))
		return max(2.0, W * (1.0 - 0.82 * smoothstep(0.33, 1.0, f)))
	spine_body(hx, tx + 3, 18, wfn, col)
	# Back: dorsal ridge and lateral highlights
	if shark:
		var d0 = hx - L * 0.4
		shape(pv([spo(d0 + 6, -1.6), spo(d0 - 9, 0), spo(d0 + 6, 1.6), spo(d0 + 9, 0)]), shade(col, 0.8), 1.4)
	else:
		pline(pv([sp(hx - L * 0.32), sp(hx - L * 0.45), sp(hx - L * 0.6)]), shade(col, 0.72), 2.2)
	if p.get("scales", false):
		for i in range(3, 13):
			var x = hx - L * i / 16.0
			var w = W * 0.5 * (1.0 - 0.5 * i / 16.0)
			for k in [-1.0, 0.0, 1.0]:
				var c = spo(x, k * w)
				if not halo_pass:
					draw_arc(c, 2.2, sp_ang(x) - 1.2, sp_ang(x) + 1.2, 5, shade(col, 0.82), 1.0, true)
	if p.get("scutes", false):
		for i in range(3, 14):
			var x = hx - L * i / 16.0
			var w = W * 0.62 * (1.0 - 0.6 * i / 16.0)
			for k in [-1.0, 0.0, 1.0]:
				var c = spo(x, k * w)
				shape(pv([c + Vector2(2, 0).rotated(sp_ang(x)), c + Vector2(0, 1.4).rotated(sp_ang(x)), c + Vector2(-2, 0).rotated(sp_ang(x)), c + Vector2(0, -1.4).rotated(sp_ang(x))]), c8(235, 225, 200), 1.0)
	if p.get("armour", false):
		var plate := []
		for q in [Vector2(hx - 2, -W * 0.5), Vector2(hx - L * 0.32, -W * 0.98), Vector2(hx - L * 0.36, 0), Vector2(hx - L * 0.32, W * 0.98), Vector2(hx - 2, W * 0.5), Vector2(hx + 1, 0)]:
			plate.append(spo(q.x, q.y))
		shape(pv(plate), shade(col, 1.2), 1.6)
		line(spo(hx - 3, 0), spo(hx - L * 0.35, 0), shade(col, 0.75), 1.2)
		line(spo(hx - L * 0.18, -W * 0.8), spo(hx - L * 0.18, W * 0.8), shade(col, 0.75), 1.2)
	if p.get("shield", false):
		var c = sp(hx - L * 0.17)
		var a = sp_ang(hx - L * 0.17)
		var sh := []
		for k in 15:
			var g = -PI * 0.5 + PI * k / 14.0
			sh.append(c + Vector2(cos(g) * L * 0.2, sin(g) * W * 1.9).rotated(a))
		sh.append(c + Vector2(-L * 0.12, W * 2.0).rotated(a))
		sh.append(c + Vector2(-L * 0.08, W * 0.6).rotated(a))
		sh.append(c + Vector2(-L * 0.08, -W * 0.6).rotated(a))
		sh.append(c + Vector2(-L * 0.12, -W * 2.0).rotated(a))
		shape(pv(sh), shade(col, 1.1))
		head_shine(c, L * 0.12, W, a, shade(col, 1.1))
		for side in [-1.0, 1.0]:
			blob(c + Vector2(-L * 0.02, side * W * 1.2).rotated(a), 4, 2, a, shade(col, 0.8))
	for k in p.get("gill", 0):
		for side in [-1.0, 1.0]:
			var x = hx - L * 0.2 - k * 2.6
			line(spo(x, side * W * 0.5), spo(x - 1.2, side * W * 0.85), shade(col, 0.55), 1.3)
	if p.get("spine", false):
		var x = hx - L * 0.3
		limb(pv([sp(x - 3), sp(x + 5)]), 1.6, c8(240, 230, 200))
	var nb = p.get("barbels", 0)
	for k in nb:
		var off = (k - (nb - 1) / 2.0) * 2.4
		var b = spo(hx - 4, off * 0.6)
		limb(pv([b, b + Vector2(5, off * 0.9 + sin(t * 3 + k) * 0.6).rotated(sp_ang(hx))]), 1.0, c8(230, 210, 170))
	var er: float = p.get("eye", 2.6)
	var ex = hx - L * (0.07 if not shark else 0.11)
	for side in [-1.0, 1.0]:
		var ew = wfn.call((hx - ex) / L) * 0.62 if not p.get("shield", false) else W * 0.35
		eye(spo(ex, side * ew), er, p.get("eye_col", c8(255, 240, 160)))
	if p.get("jaw", true):
		var m = strike
		var mo = sp(hx - 1.5)
		var a = sp_ang(hx)
		pline(pv([mo + Vector2(-2, -3 - m * 2).rotated(a), mo + Vector2(m * 1.5, 0).rotated(a), mo + Vector2(-2, 3 + m * 2).rotated(a)]), OUTLINE, 1.6)

func jawed_fish():
	fish({"col": c8(110, 120, 150), "w": 13.0, "tail": "hetero", "pect": 12.0, "pelv": 7.0, "armour": true})

func jawless_fish():
	fish({"col": c8(150, 140, 110), "w": 9.5, "tail": "hetero", "pect": 0.0, "scales": true, "jaw": false, "shield": true, "eye": 2.2})

func early_shark():
	fish({"col": c8(110, 130, 150), "w": 11.0, "tail": "fork", "pect": 17.0, "gill": 5, "shark": true})

func ray_finned_fish():
	fish({"col": c8(160, 170, 190), "w": 10.0, "tail": "hetero", "pect": 11.0, "pelv": 6.0, "scales": true, "fin": c8(220, 200, 150)})

func shark_line():
	fish({"col": c8(100, 120, 140), "w": 11.5, "len": 90.0, "tail": "hetero", "pect": 18.0, "pelv": 5.0, "gill": 5, "shark": true, "eye": 2.4})

func chimaera():
	fish({"col": c8(170, 160, 190), "w": 11.0, "tail": "whip", "pect": 21.0, "eye": 4.0, "spine": true, "eye_col": c8(160, 255, 240), "len": 74.0})

func sturgeon_line():
	fish({"col": c8(120, 130, 110), "len": 94.0, "w": 9.5, "tail": "hetero", "pect": 10.0, "pelv": 5.0, "scutes": true, "barbels": 4, "jaw": false, "shovel": true, "eye": 2.0})

func teleost_line():
	fish({"col": c8(225, 160, 60), "len": 70.0, "w": 14.0, "tail": "fork", "pect": 10.0, "pelv": 6.0, "scales": true, "fin": c8(250, 220, 120), "eye": 3.4})

# Long undulating body. Keys: col, len, w, head_w, mouth (disc, none),
# gill_pores, barbels, eyes, fringe, pores, myomeres, tentacles, pouch, gill_row
func eel(p: Dictionary):
	var col: Color = p.col
	var L: float = p.get("len", 94.0)
	var W: float = p.get("w", 5.8)
	var HW: float = p.get("head_w", W)
	var hx = L * 0.5
	spine_setup(hx, L, 9.0, 5.5)
	var wfn = func(f):
		return (HW + (W - HW) * min(1.0, f * 3.0)) * (1.0 - 0.75 * max(0.0, f - 0.6) / 0.4) + 0.6
	if p.get("fringe", true):
		var ffn = func(f):
			return wfn.call(0.45 + f * 0.55) + 2.8 * sin(PI * min(1.0, f * 1.4))
		spine_body(hx - L * 0.45, hx - L, 12, ffn, shade(col, 1.25), 1.4)
	spine_body(hx, hx - L, 24, wfn, col)
	if p.get("myomeres", false):
		for i in range(3, 20):
			var x = hx - L * i / 22.0
			var w = wfn.call(i / 22.0) * 0.8
			pline(pv([spo(x - 1.5, -w), spo(x + 1.5, 0), spo(x - 1.5, w)]), shade(col, 0.72), 1.1)
	for k in p.get("gill_pores", 0):
		for side in [-1.0, 1.0]:
			disc(spo(hx - 10 - k * 2.8, side * W * 0.62), 0.9, c8(40, 35, 35), 0.0)
	if p.get("gill_row", false):
		for k in 6:
			for side in [-1.0, 1.0]:
				dot(spo(hx - 20 - k * 3.0, side * W * 0.7), 1.0, c8(60, 30, 30))
	if p.get("pores", false):
		for i in range(4, 20, 2):
			var x = hx - L * i / 22.0
			for side in [-1.0, 1.0]:
				dot(spo(x, side * wfn.call(i / 22.0) * 0.75), 0.9, c8(250, 250, 230))
	if p.get("pouch", false):
		oval(spo(hx - 8, 0), 5, W + 2.5, sp_ang(hx - 8), c8(150, 170, 210), 1.4)
	var a = sp_ang(hx)
	match p.get("mouth", "none"):
		"disc":
			var mc = sp(hx + 1)
			var open = 1.0 + 0.4 * strike
			disc(mc, HW * 0.95 * open, shade(col, 0.75), 1.6)
			dot(mc, HW * 0.45 * open, c8(70, 30, 35))
			for k in 8:
				var g = k * TAU / 8.0
				dot(mc + Vector2(cos(g), sin(g)) * HW * 0.7 * open, 0.7, c8(250, 240, 200))
	var nb = p.get("barbels", 0)
	for k in nb:
		var off = (k - (nb - 1) / 2.0) * 1.8
		var b = spo(hx - 1, off * 0.7)
		limb(pv([b, b + Vector2(5, off * 1.3 + sin(t * 3 + k) * 0.8).rotated(a)]), 1.0, shade(col, 1.3))
	if p.get("tentacles", false):
		for side in [-1.0, 1.0]:
			var b = spo(hx - 1, side * 1.5)
			limb(pv([b, b + Vector2(4, side * 3).rotated(a), b + Vector2(7, side * (4.0 + sin(t * 2.5) * 1.0)).rotated(a)]), 1.0, shade(col, 1.3))
	if p.get("eyes", true):
		for side in [-1.0, 1.0]:
			eye(spo(hx - 5, side * HW * 0.55), 1.7, c8(255, 240, 160))

func pikaia_chordate():
	eel({"col": c8(220, 190, 160), "w": 5.5, "head_w": 3.8, "len": 86.0, "eyes": false, "myomeres": true, "tentacles": true})

func lamprey(p: Dictionary = {}):
	eel({"col": p.get("col", c8(120, 110, 100)), "w": 6.0, "mouth": "disc", "gill_pores": 7, "pouch": p.get("pouch", false)})

func hagfish(p: Dictionary = {}):
	eel({"col": p.get("col", c8(210, 140, 150)), "w": 6.0, "barbels": 6, "eyes": false, "pores": true, "gill_row": p.get("gill_row", false)})

# Sprawling four-legged animal. Keys: col, hl, hw, bl, bw, tl, tw, leg,
# toes, snout, scaly, spots, sail, flat, fins (lobed fins instead of feet),
# belly
func tetrapod(p: Dictionary):
	var col: Color = p.col
	var hl: float = p.hl
	var hw: float = p.hw
	var bl: float = p.bl
	var bw: float = p.bw
	var tl: float = p.tl
	var tw: float = p.tw
	var total = hl + bl + tl
	var hx = total * 0.48
	var keep = swim
	# A sprawling walker bends its body in time with its steps
	swim = gait + PI * 0.5 if not p.get("fins", false) else swim
	spine_setup(hx, total, 6.0, 2.0)
	var shoulder = hx - hl * 0.95
	var hip = shoulder - bl * 0.82
	var lc = shade(col, 0.86)
	for front in [true, false]:
		var x = shoulder if front else hip
		for side in [-1.0, 1.0]:
			var ph = side_ph(side) + (0.0 if front else PI)
			var root = spo(x, side * bw * 0.65)
			if p.get("fins", false):
				var fa = sp_ang(x) + side * (PI * (0.62 if front else 0.75) + sin(gait + ph) * 0.3)
				fin_lobe(root, fa, p.leg * 1.2, 4.0, shade(col, 1.12), 4)
			else:
				var foot = leg(root, side, p.leg, ph, -0.12 if front else 0.3, 5.0, lc, 0.5)
				disc(foot, 2.6, lc, 1.6)
				var fa = sp_ang(x) + (0.3 if front else -0.3) * side
				for k in p.get("toes", 5):
					var g = (k - (p.get("toes", 5) - 1) / 2.0) * 0.42
					limb(pv([foot, foot + Vector2.RIGHT.rotated(fa + side * PI * 0.35 + g) * 4.5]), 1.3, lc)
	spine_body(hip + 2, hx - total, 12, func(f): return tw * (1.0 - f) + 0.6, shade(col, 0.95))
	spine_body(shoulder + 6, hip - 6, 12, func(f): return bw * (0.82 + 0.18 * sin(PI * f)), col)
	if p.get("sail", false):
		var sp_pts := []
		for i in 9:
			var x = lerp(shoulder + 1, hip - 1, i / 8.0)
			sp_pts.append(sp(x))
		limb(pv(sp_pts), 4.0, c8(230, 120, 90))
		for i in 9:
			var x = lerp(shoulder + 1, hip - 1, i / 8.0)
			var h = sin(PI * (i + 0.5) / 9.0) * 4.0 + 1.0
			line(spo(x, -h), spo(x, h), c8(150, 60, 45), 1.4)
	if p.get("scaly", false):
		for i in 7:
			var x = lerp(shoulder + 2, hip - 2, i / 6.0)
			for k in [-1.0, 0.0, 1.0]:
				if not halo_pass:
					draw_arc(spo(x, k * bw * 0.45), 1.8, sp_ang(x) - 1.3, sp_ang(x) + 1.3, 5, shade(col, 0.75), 1.0, true)
	if p.get("spots", false):
		for q in [Vector2(0.15, -0.5), Vector2(0.35, 0.45), Vector2(0.6, -0.3), Vector2(0.8, 0.4), Vector2(0.5, 0.05), Vector2(1.1, -0.2), Vector2(1.35, 0.15)]:
			var x = shoulder + 4 - q.x * (bl - 4)
			disc(spo(x, q.y * bw), 1.8, c8(240, 200, 60), 0.0)
	var hc = hx - hl * 0.45
	var a = sp_ang(hc)
	var head := []
	var sn: float = p.get("snout", 0.0)
	for k in 20:
		var g = TAU * k / 20.0
		var r = Vector2(cos(g) * hl * 0.55, sin(g) * hw)
		if cos(g) > 0:
			r.x *= 1.0 + sn * cos(g)
			r.y *= 1.0 - sn * 0.45 * cos(g) * cos(g)
		head.append(sp(hc) + r.rotated(a))
	# Jaw opens on attack: a dark gape at the front
	shape(pv(head), shade(col, 1.04))
	head_shine(sp(hc), hl * 0.5, hw, a, shade(col, 1.04))
	if strike > 0.05:
		var tip = sp(hc) + Vector2(hl * 0.55 * (1.0 + sn), 0).rotated(a)
		shape(pv([tip, tip + Vector2(-hl * 0.45, -hw * 0.35 * strike).rotated(a), tip + Vector2(-hl * 0.5, 0).rotated(a), tip + Vector2(-hl * 0.45, hw * 0.35 * strike).rotated(a)]), c8(140, 50, 60), 1.2)
	var ey = hw * (0.42 if p.get("flat", false) else 0.6)
	for side in [-1.0, 1.0]:
		eye(sp(hc) + Vector2(hl * 0.05, side * ey).rotated(a), 2.4, c8(255, 210, 120))
		dot(sp(hc) + Vector2(hl * 0.5 * (1.0 + sn), side * 1.6).rotated(a), 0.8, OUTLINE)
	swim = keep

func lobe_finned_shorewalker():
	tetrapod({"col": c8(110, 130, 90), "hl": 20.0, "hw": 10.0, "bl": 40.0, "bw": 10.5, "tl": 30.0, "tw": 6.0, "leg": 13.0, "snout": 0.35, "scaly": true, "flat": true, "fins": true})

func synapsid():
	tetrapod({"col": c8(150, 110, 90), "hl": 19.0, "hw": 7.5, "bl": 34.0, "bw": 9.5, "tl": 32.0, "tw": 4.5, "leg": 13.0, "snout": 0.3, "sail": true})

func lissamphibian():
	tetrapod({"col": c8(48, 58, 62), "hl": 15.0, "hw": 9.5, "bl": 34.0, "bw": 8.0, "tl": 36.0, "tw": 4.5, "leg": 13.0, "toes": 4, "spots": true, "flat": true})

func sauropsid():
	tetrapod({"col": c8(110, 150, 70), "hl": 17.0, "hw": 7.0, "bl": 30.0, "bw": 8.0, "tl": 42.0, "tw": 4.5, "leg": 12.0, "snout": 0.3, "scaly": true})

# ───────────────────────── molluscs ─────────────────────────
func coiled_shell(c: Vector2, r: float, col: Color, turns: float = 2.6, stripes: Color = Color(0, 0, 0, 0), rot: float = 0.0):
	disc(c, r, col)
	if halo_pass:
		return
	draw_circle(c + Vector2(r * 0.12, r * 0.12).rotated(rot), r * 0.86, shade(col, 0.9), true, -1.0, true)
	if stripes.a > 0:
		for k in 9:
			var g = rot + k * TAU / 9.0
			var pts := PackedVector2Array()
			for j in 5:
				var f = j / 4.0
				pts.append(c + Vector2.RIGHT.rotated(g + f * 0.7) * r * (0.95 - f * 0.45))
			draw_polyline(pts, stripes, 2.4, true)
	var sp_pts := PackedVector2Array()
	for i in 48:
		var f = i / 47.0
		var a = rot + f * turns * TAU
		sp_pts.append(c + Vector2.RIGHT.rotated(a) * r * (1.0 - f) * 0.94)
	draw_polyline(sp_pts, shade(col, 0.55), 1.6, true)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.35).rotated(rot), r * 0.22, Color(1, 1, 1, 0.35), true, -1.0, true)

# Fan of arms reaching forward from `base`; streamlined at speed
func arms(base: Vector2, a0: float, n: int, length: float, spread: float, col: Color, w: float = 2.6, suckers: bool = false, long_pair: float = 0.0):
	var sprd = spread * (1.0 - 0.45 * clamp(move, 0.0, 1.0)) + 0.6 * strike
	for k in n:
		var f = (k - (n - 1) / 2.0) / max((n - 1) / 2.0, 1.0)
		var ln = length * (0.85 + 0.15 * (1.0 - abs(f)))
		if long_pair > 0 and abs(k - (n - 1) / 2.0) < 0.6 + (0 if n % 2 == 1 else 0.0):
			ln = length * long_pair
		var pts := PackedVector2Array([base])
		var a = a0 + f * sprd * 0.5
		var p = base
		for i in 6:
			var g = (i + 1) / 6.0
			a += sin(t * 2.6 + k * 0.9 + g * 2.2) * 0.16 * g - bend * 0.05
			p += Vector2.RIGHT.rotated(a) * ln / 6.0
			pts.append(p)
		taper(pts, w, w * 0.35, col)
		if suckers and not halo_pass:
			for i in range(2, 6, 1):
				draw_circle(pts[i], w * 0.22, shade(col, 1.45), true, -1.0, true)

func long_pair_tentacles(base: Vector2, a0: float, length: float, col: Color):
	var reach = length * (1.0 + 0.5 * strike)
	for side in [-1.0, 1.0]:
		var a = a0 + side * 0.08
		var pts := PackedVector2Array([base])
		var p = base
		for i in 7:
			var g = (i + 1) / 7.0
			a += sin(t * 2.0 + side + g * 3.0) * 0.08
			p += Vector2.RIGHT.rotated(a) * reach / 7.0
			pts.append(p)
		taper(pts, 1.8, 1.2, col)
		oval(p, 3.5, 2.2, a, shade(col, 1.15), 1.4)

func cephalopod():
	# Earliest cephalopods (Plectronoceras-like): a straight chambered shell
	# with septa behind a soft head ringed with arms.
	var shell = c8(225, 205, 165)
	var skin = c8(220, 140, 120)
	spine_setup(30, 80, 1.5, 1.0)
	var a = sp_ang(10)
	var c = sp(8)
	arms(sp(26), sp_ang(26), 10, 20, 1.5, skin, 2.4)
	var cone := pv([c + Vector2(12, -11).rotated(a), c + Vector2(-44, -3).rotated(a), c + Vector2(-46, 0).rotated(a), c + Vector2(-44, 3).rotated(a), c + Vector2(12, 11).rotated(a)])
	shape(cone, shell)
	for k in 7:
		var x = 6 - k * 7.0
		var w = 11.0 * (1.0 - (12 - x) / 58.0)
		pline(pv([c + Vector2(x + 2, -w).rotated(a), c + Vector2(x - 1, 0).rotated(a), c + Vector2(x + 2, w).rotated(a)]), shade(shell, 0.68), 1.3)
	blob(c + Vector2(-10, -5).rotated(a), 18, 2.5, a, shade(shell, 1.3))
	oval(sp(20), 8, 10, sp_ang(20), skin)
	for side in [-1.0, 1.0]:
		eye(spo(21, side * 6), 2.4, c8(40, 40, 40))

func sea_snail():
	# Gastropod: coiled shell on a muscular foot, one pair of head
	# tentacles with eyes at their bases.
	var foot = c8(200, 180, 150)
	spine_setup(36, 76, 1.2, 1.0)
	var creep = sin(gait * 0.5) * 2.0
	oval(sp(0) + Vector2(creep * 0.3, 0), 36 + creep, 13, sp_ang(0), foot)
	blob(sp(10), 20, 5, sp_ang(10), shade(foot, 1.15))
	var a = sp_ang(30)
	for side in [-1.0, 1.0]:
		var b = spo(30, side * 4)
		limb(pv([b, b + Vector2(7, side * 5).rotated(a), b + Vector2(13, side * (7.0 + sin(t * 2 + side) * 1.5)).rotated(a)]), 1.8, shade(foot, 1.05))
		eye(spo(31, side * 5), 1.4)
	coiled_shell(sp(-6), 19 * (1.0 + 0.04 * tuck), c8(190, 120, 80), 2.6, Color(0, 0, 0, 0), a)

func bivalve():
	# Clam from above: two valves hinged down the middle with growth lines,
	# siphons out the back and the foot in front.
	var shell = c8(205, 185, 160)
	var flesh = c8(230, 160, 150)
	spine_setup(30, 70, 0.0, 1.0)
	var gape = (0.5 + 0.5 * sin(swim)) * 2.5 * (1.0 - tuck) + 3.0 * strike
	oval(sp(31 + sin(gait * 0.5) * 3.0), 6, 5, 0, flesh)
	for side in [-1.0, 1.0]:
		limb(pv([spo(-27, side * 2), spo(-36, side * (2.5 + sin(t * 2 + side) * 1.5))]), 3.2, flesh)
	for side in [-1.0, 1.0]:
		var c = Vector2(0, side * gape * 0.5)
		var pts := []
		for k in 17:
			var g = PI * k / 16.0
			pts.append(c + Vector2(cos(g) * 30, side * sin(g) * 25))
		shape(pv(pts), shell)
		for r in [0.35, 0.6, 0.82]:
			var arc := []
			for k in 13:
				var g = PI * k / 12.0
				arc.append(c + Vector2(cos(g) * 30 * r, side * sin(g) * 25 * r))
			pline(pv(arc), shade(shell, 0.75), 1.2)
		blob(c + Vector2(4, side * 12), 10, 5, 0.0, shade(shell, 1.25))

func nautilus(p: Dictionary = {}):
	# Nautilus: coiled chambered shell with tiger stripes, a leathery hood,
	# many slender suckerless tentacles and pinhole eyes.
	var shell: Color = p.get("shell", c8(240, 230, 210))
	var skin: Color = p.get("skin", c8(220, 170, 150))
	spine_setup(30, 70, 0.6, 1.0)
	arms(sp(18), sp_ang(18), 14, 19, 1.7, skin, 1.6)
	oval(sp(16), 8, 12, sp_ang(16), shade(skin, 0.9))
	for side in [-1.0, 1.0]:
		eye(spo(18, side * 9), 2.2, c8(30, 30, 30))
	coiled_shell(sp(-6), 23, shell, 1.5, p.get("stripes", c8(160, 80, 40)), sp_ang(0) + PI)
	if p.get("crust", false) and not halo_pass:
		for k in 26:
			var a = k * 2.4
			var r = 4.0 + (k % 6) * 3.3
			draw_circle(sp(-6) + Vector2(cos(a), sin(a)) * r, 1.6, Color(0.43, 0.51, 0.31, 0.9), true, -1.0, true)
	oval(sp(13), 7, 11, sp_ang(13), shade(skin, 0.75), 1.6)

func coleoid():
	# Belemnite-like early coleoid: internal bullet-shaped guard inside the
	# mantle, side fins, ten hooked arms.
	var body = c8(180, 120, 150)
	spine_setup(36, 80, 2.0, 1.5)
	arms(sp(18), sp_ang(18), 10, 28, 1.0, shade(body, 1.1), 2.8)
	var flap = sin(swim * 1.2) * 0.3
	for side in [-1.0, 1.0]:
		fin_lobe(spo(-24, side * 6), sp_ang(-24) + side * (PI * 0.72 + flap), 13, 5, shade(body, 1.15), 2)
	spine_body(16, -38, 12, func(f): return 9.5 * (1.0 - 0.75 * f * f), body)
	fill(pv([spo(-6, -2), spo(-36, 0), spo(-6, 2)]), shade(body, 0.7))
	for side in [-1.0, 1.0]:
		eye(spo(18, side * 6.5), 2.8, c8(255, 230, 120))

func cone_shell(p: Dictionary):
	# Cone snail: cone-shaped patterned shell, siphon, and an extendable
	# proboscis carrying a venom harpoon that shoots out on attack.
	var shell: Color = p.get("shell", c8(230, 200, 150))
	var pat: Color = p.get("pat", c8(140, 70, 40))
	spine_setup(32, 76, 0.5, 1.0)
	var a = sp_ang(20)
	var reach = 6.0 + 18.0 * strike + 2.0 * sin(t * 2.0)
	var pb = sp(22)
	taper(pv([pb, pb + Vector2(reach, 0).rotated(a)]), 2.6, 2.0, c8(230, 120, 140))
	if strike > 0.2:
		limb(pv([pb + Vector2(reach, 0).rotated(a), pb + Vector2(reach + 5, 0).rotated(a)]), 1.2, c8(255, 255, 240))
	limb(pv([spo(20, 5), spo(30, 8)]), 2.4, c8(230, 150, 140))
	var c = sp(8)
	shape(pv([c + Vector2(12, -15).rotated(a), c + Vector2(-38, -2.5).rotated(a), c + Vector2(-38, 2.5).rotated(a), c + Vector2(12, 15).rotated(a), c + Vector2(15, 0).rotated(a)]), shell)
	oval(c + Vector2(11, 0).rotated(a), 4.5, 15, a, shade(shell, 1.1))
	if not halo_pass:
		for k in 6:
			var x = 4 - k * 7.0
			var w = 14.0 * (1.0 - (12 - x) / 52.0)
			for j in range(-2, 3):
				var q = c + Vector2(x + (j % 2) * 2.0, j * w / 2.6).rotated(a)
				draw_colored_polygon(pv([q + Vector2(0, -1.6).rotated(a), q + Vector2(-2.2, 0).rotated(a), q + Vector2(0, 1.6).rotated(a), q + Vector2(2.2, 0).rotated(a)]), pat)
		blob(c + Vector2(-6, -6).rotated(a), 16, 2.5, a, Color(1, 1, 1, 0.3))

func predatory_sea_snail():
	cone_shell({})

func cone_snail():
	cone_shell({"shell": c8(240, 225, 205), "pat": c8(160, 60, 30)})

func sea_slug(p: Dictionary):
	# Nudibranch: shell-less, two rhinophores in front and rows of cerata
	# (finger-like gills) down the back; very colourful.
	var body: Color = p.get("col", c8(120, 80, 200))
	var cer: Color = p.get("cer", c8(255, 160, 60))
	var edge: Color = p.get("edge", c8(250, 220, 90))
	spine_setup(38, 80, 2.5, 2.0)
	spine_body(38, -40, 16, func(f): return 11.0 * pow(sin(PI * clamp(f * 0.9 + 0.08, 0.0, 1.0)), 0.6) + 1.0, body)
	pline(pv([sp(32), sp(0), sp(-34)]), edge, 2.0)
	for i in 7:
		var x = 22 - i * 8.0
		for side in [-1.0, 1.0]:
			var r = spo(x, side * (4.0 + (i % 2) * 2.5))
			var wob = sin(t * 2.5 + i + side) * 0.25 + bend * 0.2
			var tip = r + Vector2(-3, side * 7).rotated(sp_ang(x) + wob * side)
			taper(pv([r, tip]), 3.4, 2.4, cer)
			dot(tip, 1.3, c8(255, 245, 210))
	var a = sp_ang(34)
	for side in [-1.0, 1.0]:
		var b = spo(32, side * 3)
		taper(pv([b, b + Vector2(5, side * 4).rotated(a), b + Vector2(10, side * 5).rotated(a)]), 2.6, 1.8, edge)

func sea_slug_line():
	sea_slug({})

func nudibranch():
	sea_slug({"col": c8(60, 70, 210), "cer": c8(255, 110, 170), "edge": c8(255, 240, 120)})

func scallop(p: Dictionary = {}):
	# Scallop: fan-shaped valve with radiating ribs, two "ears" at the hinge
	# and a row of small blue eyes on the mantle edge. Swims by clapping.
	var shell: Color = p.get("col", c8(230, 140, 100))
	spine_setup(30, 70, 0.0, 1.0)
	var clap = 0.5 + 0.5 * sin(swim * 1.4)
	var r = 30.0 * (0.94 + 0.06 * clap)
	var hinge = Vector2(-16, 0)
	if not halo_pass:
		for k in 12:
			var g = -1.25 + 2.5 * k / 11.0
			draw_circle(hinge + Vector2.RIGHT.rotated(g) * (r + 2.5), 1.6, OUTLINE, true, -1.0, true)
			draw_circle(hinge + Vector2.RIGHT.rotated(g) * (r + 2.5), 1.1, c8(80, 170, 255), true, -1.0, true)
	var fan := [hinge]
	for k in 19:
		var g = -1.3 + 2.6 * k / 18.0
		var bump = 1.0 + 0.04 * cos(k * PI)
		fan.append(hinge + Vector2.RIGHT.rotated(g) * r * bump)
	shape(pv(fan), shell)
	for k in 10:
		var g = -1.2 + 2.4 * k / 9.0
		line(hinge + Vector2.RIGHT.rotated(g) * 4, hinge + Vector2.RIGHT.rotated(g) * r * 0.97, shade(shell, 0.75), 1.4)
	blob(hinge + Vector2(16, -8), 9, 4, -0.4, shade(shell, 1.3))
	shape(pv([hinge + Vector2(-2, -10), hinge + Vector2(6, -10), hinge + Vector2(6, 10), hinge + Vector2(-2, 10)]), shade(shell, 1.1), 1.6)

func true_scallop():
	scallop({"col": c8(240, 175, 90)})

func burrowing_clam():
	# Razor clam: long narrow valves, a digging foot in front and a paired
	# siphon at the back.
	var shell = c8(210, 190, 140)
	var flesh = c8(230, 170, 150)
	spine_setup(40, 86, 0.8, 1.0)
	var dig = sin(gait * 0.6) * 3.0 + 6.0 * strike
	oval(sp(38 + dig), 5, 5.5, 0, flesh)
	for side in [-1.0, 1.0]:
		limb(pv([spo(-36, side * 1.6), spo(-46 - dig * 0.3, side * (1.6 + sin(t * 2.0) * 1.0))]), 2.6, flesh)
	for side in [-1.0, 1.0]:
		var pts := []
		for q in [Vector2(36, 0), Vector2(33, 8.5), Vector2(-36, 8.5), Vector2(-38, 0)]:
			pts.append(spo(q.x, side * q.y))
		shape(pv(pts), shade(shell, 1.0 if side < 0 else 0.92))
		for k in 6:
			var x = 28 - k * 12.0
			line(spo(x, side * 1.0), spo(x - 3, side * 7.5), shade(shell, 0.78), 1.2)
	line(sp(36), sp(-38), OUTLINE, 1.6)

func squid_line():
	# Squid: torpedo mantle with two rear fins, eight arms plus two longer
	# feeding tentacles with clubs that shoot out on attack, big eyes.
	var body = c8(230, 120, 110)
	spine_setup(40, 90, 2.0, 1.5)
	long_pair_tentacles(sp(16), sp_ang(16), 38, shade(body, 1.1))
	arms(sp(16), sp_ang(16), 8, 26, 1.0, shade(body, 1.1), 3.0, true)
	var flap = sin(swim * 1.3) * 0.35
	for side in [-1.0, 1.0]:
		var r = spo(-30, side * 3)
		var fa = sp_ang(-30) + side * (PI * 0.62 + flap)
		shape(pv([spo(-20, side * 4), r + Vector2.RIGHT.rotated(fa) * 15, spo(-42, 0)]), shade(body, 1.12))
	spine_body(14, -42, 14, func(f): return 9.0 * (1.0 - 0.8 * pow(f, 2.2)) + 0.5, body)
	if not halo_pass:
		for k in 9:
			dot(spo(6 - k * 5.0, ((k % 3) - 1) * 3.5), 1.3, shade(body, 0.7))
	oval(sp(15), 6, 8, sp_ang(15), shade(body, 1.05))
	for side in [-1.0, 1.0]:
		eye(spo(15, side * 6.5), 3.2, c8(255, 240, 140))

func octopus_line():
	# Octopus: rounded mantle, eight arms with suckers curling in a slow
	# wave, no fins, no shell.
	var body = c8(200, 100, 70)
	spine_setup(20, 60, 0.0, 1.0)
	var c = sp(8)
	for k in 8:
		var a = (k - 3.5) / 3.5 * 1.35 * (1.0 - 0.35 * clamp(move, 0.0, 1.0))
		var pts := PackedVector2Array([c + Vector2.RIGHT.rotated(a) * 6])
		var p = pts[0]
		var aa = a
		for i in 7:
			var g = (i + 1) / 7.0
			aa += sin(t * 2.2 + k * 0.8 + g * 2.5) * 0.28 * g
			p += Vector2.RIGHT.rotated(aa) * (5.0 + 1.0 * strike)
			pts.append(p)
		taper(pts, 5.0, 1.6, body)
		if not halo_pass:
			for i in range(1, 6):
				draw_circle(pts[i], 1.0, c8(255, 220, 200), true, -1.0, true)
	var pulse = 1.0 + 0.06 * sin(swim)
	oval(sp(-10), 15 * pulse, 13 / pulse, sp_ang(-10), body)
	head_shine(sp(-10), 15, 13, sp_ang(-10), body)
	oval(sp(7), 9, 10, 0, shade(body, 1.05))
	for side in [-1.0, 1.0]:
		eye(spo(6, side * 7), 2.8, c8(255, 230, 120))

func moon_snail():
	# Naticid: round glossy shell and a huge foot spread around it; the
	# proboscis drills prey and reaches out on attack.
	var shell = c8(200, 180, 160)
	var foot = c8(230, 190, 180)
	spine_setup(30, 70, 0.0, 1.0)
	var spread = 1.0 + 0.05 * sin(gait * 0.5)
	oval(Vector2(2, 0), 31 * spread, 28 * spread, 0, foot)
	blob(Vector2(10, -8), 14, 8, 0, shade(foot, 1.15))
	var reach = 4.0 + 12.0 * strike
	taper(pv([Vector2(28, 0), Vector2(30 + reach, 0)]), 3.4, 2.6, c8(240, 150, 150))
	coiled_shell(Vector2(-3, 0), 18, shell, 1.2, Color(0, 0, 0, 0), PI)
	dot(Vector2(-3, 0), 1.6, c8(90, 70, 60))

func land_snail():
	# Land snail: coiled shell on the back, a soft foot, two pairs of
	# tentacles, the upper pair carrying the eyes.
	var body = c8(170, 150, 120)
	spine_setup(42, 84, 0.6, 1.0)
	var stretch = sin(gait * 0.5) * 2.5
	spine_body(42 + stretch, -40, 16, func(f): return 8.5 * pow(sin(PI * clamp(f * 0.92 + 0.06, 0.0, 1.0)), 0.45) * (1.0 - 0.35 * f) + 0.8, body)
	var a = sp_ang(40)
	var pull = 1.0 - tuck
	for side in [-1.0, 1.0]:
		var b = spo(40 + stretch, side * 3)
		var tip = b + Vector2(14 * pull, side * 6).rotated(a + sin(t * 1.5 + side) * 0.12)
		taper(pv([b, tip]), 2.4, 1.6, body)
		eye(tip, 1.5)
		taper(pv([spo(41 + stretch, side * 2), spo(46 + stretch, side * 4)]), 1.8, 1.4, body)
	coiled_shell(sp(-6), 20, c8(190, 130, 60), 3.0, c8(110, 60, 30), a)

func oyster():
	# Oyster: thick, rough, irregular valve with layered frilly growth
	# lines; narrower hinge end.
	var shell = c8(170, 165, 150)
	spine_setup(30, 70, 0.0, 1.0)
	var pts = [Vector2(30, -8), Vector2(28, 7), Vector2(8, 20), Vector2(-14, 24), Vector2(-34, 13), Vector2(-38, -6), Vector2(-20, -22), Vector2(8, -20)]
	shape(pv(pts), shell)
	var gape = 0.02 * sin(swim)
	for k in [0.78, 0.58, 0.38]:
		var ring := []
		for q in pts:
			ring.append(Vector2(30, 0) + (q - Vector2(30, 0)) * (k + gape))
		ring.append(ring[0])
		pline(pv(ring), shade(shell, 0.72 + k * 0.2), 1.6)
	blob(Vector2(-4, -8), 14, 5, -0.3, shade(shell, 1.25))
	dot(Vector2(27, 0), 1.6, c8(90, 80, 70))

func giant_clam():
	# Giant clam: two heavy wavy valves gaping to show a bright mantle full
	# of the algae it farms.
	var shell = c8(220, 215, 200)
	spine_setup(30, 70, 0.0, 1.0)
	oval(Vector2.ZERO, 32, 25, 0, shell)
	for k in 5:
		var x = -24 + k * 12.0
		for side in [-1.0, 1.0]:
			if not halo_pass:
				draw_arc(Vector2(x, side * 18), 5.5, 0.0 if side < 0 else PI, PI if side < 0 else TAU, 8, shade(shell, 0.7), 1.6, true)
	var open = (10.0 + 1.5 * sin(t * 1.2)) * (1.0 - 0.7 * tuck)
	oval(Vector2.ZERO, 27, open, 0, c8(40, 120, 200), 1.6)
	if not halo_pass:
		for k in 11:
			draw_circle(Vector2(-22 + k * 4.4, ((k % 2) * 2 - 1) * open * 0.35), 1.4, c8(120, 240, 230), true, -1.0, true)
		draw_line(Vector2(-25, 0), Vector2(25, 0), c8(20, 60, 110), 1.2, true)
	oval(Vector2(4, 0), 2.5, 1.8, 0, c8(20, 40, 60), 1.0)

func shipworm():
	# Shipworm: a worm-shaped clam. Two small ridged valves at the head work
	# as a drill; two feathery pallets at the tail plug the burrow.
	var body = c8(230, 210, 190)
	spine_setup(34, 84, 6.0, 4.0)
	spine_body(30, -46, 18, func(f): return 5.5 * (1.0 - 0.3 * f) + 0.5, body)
	var tb = sp(-46)
	for side in [-1.0, 1.0]:
		var pa = sp_ang(-46) + PI + side * 0.5
		taper(pv([tb, tb + Vector2.RIGHT.rotated(pa) * 7]), 2.6, 3.2, c8(200, 170, 120))
	var rock = sin(t * 5.0) * 0.25 + strike * 0.5
	var a = sp_ang(32)
	for side in [-1.0, 1.0]:
		var c = spo(34, side * 4)
		oval(c, 5.5, 5.0, a + side * rock, c8(240, 235, 220), 1.6)
		for k in 3:
			line(c + Vector2(-3 + k * 2.5, -side * 3).rotated(a + side * rock), c + Vector2(-3 + k * 2.5, side * 4).rotated(a + side * rock), c8(170, 160, 140), 1.0)

# ───────────────────────── echinoderms ─────────────────────────
# Five-part (or more) star seen from above, one arm leading. Keys: col, arms,
# len, w, disc, thin, bumps, groove, wiggle, tipeye, madreporite
func star(p: Dictionary):
	var col: Color = p.col
	var n: int = p.get("arms", 5)
	var L: float = p.get("len", 34.0)
	var W: float = p.get("w", 10.0)
	var D: float = p.get("disc", 12.0)
	var thin: bool = p.get("thin", false)
	var wig: float = p.get("wiggle", 0.15)
	spine_setup(0, 60, 0.0, 1.0)
	for k in n:
		var base_a = k * TAU / n
		var spine := []
		var widths := []
		for i in 10:
			var f = i / 9.0
			# Arms ripple as the tube feet walk; brittle stars row with them
			var a = base_a + sin(gait * 0.7 + k * 1.3 + f * 1.5) * wig * f * clamp(move + 0.25, 0.0, 1.0) + sin(t * 0.8 + k) * 0.04 * f
			spine.append(Vector2.RIGHT.rotated(a) * (D * 0.5 + L * f * (1.0 - 0.25 * tuck)))
			widths.append(W * (1.0 - f * (0.8 if not thin else 0.5)) + (0.8 if thin else 1.0))
		if thin:
			taper(pv(spine), W * 2.0, 1.4, col)
			if not halo_pass:
				for i in range(1, 9):
					var tn = (spine[i + 1] - spine[i - 1]).normalized()
					draw_line(spine[i] + Vector2(-tn.y, tn.x) * widths[i] * 0.9, spine[i] - Vector2(-tn.y, tn.x) * widths[i] * 0.9, shade(col, 0.7), 1.0, true)
		else:
			tube_shaded(spine, widths, col)
			if p.get("groove", true):
				pline(pv(spine.slice(1)), shade(col, 0.7), 1.6)
			if p.get("bumps", true) and not halo_pass:
				for i in range(1, 8):
					var tn = (spine[i + 1] - spine[i - 1]).normalized()
					var nm = Vector2(-tn.y, tn.x)
					draw_circle(spine[i] + nm * widths[i] * 0.5, 1.2, shade(col, 1.35), true, -1.0, true)
					draw_circle(spine[i] - nm * widths[i] * 0.5, 1.2, shade(col, 1.35), true, -1.0, true)
		if p.get("tipeye", false):
			dot(spine[9], 1.6, c8(255, 80, 60))
	disc(Vector2.ZERO, D, shade(col, 1.06))
	if not halo_pass:
		draw_circle(Vector2(-D * 0.25, -D * 0.25), D * 0.45, shade(col, 1.2), true, -1.0, true)
		if p.get("bumps", true):
			for k in n:
				draw_circle(Vector2.RIGHT.rotated(k * TAU / n) * D * 0.55, 1.3, shade(col, 1.4), true, -1.0, true)
		if p.get("madreporite", false):
			draw_circle(Vector2(-3, 4), 2.2, c8(250, 230, 120), true, -1.0, true)

# Crinoid arms: each of `n` arms (forking from five) is a feather of pinnules
func feather_arms(n: int, L: float, col: Color, beat: float):
	for k in n:
		var a0 = k * TAU / n + (PI / n)
		var pts := PackedVector2Array([Vector2.RIGHT.rotated(a0) * 5])
		var p = pts[0]
		var a = a0
		for i in 7:
			var g = (i + 1) / 7.0
			a += sin(swim * 0.8 + k * 1.1 + g * 2.0) * beat * g
			p += Vector2.RIGHT.rotated(a) * L / 7.0 * (1.0 - 0.3 * tuck)
			pts.append(p)
		limb(pts, 2.4, col)
		if not halo_pass:
			for i in range(1, 7):
				var tn = (pts[i + 1] - pts[i - 1]).normalized()
				var nm = Vector2(-tn.y, tn.x)
				var lw = 4.5 * (1.0 - i / 9.0)
				draw_line(pts[i] + nm * lw - tn * 1.5, pts[i], shade(col, 1.25), 1.2, true)
				draw_line(pts[i] - nm * lw - tn * 1.5, pts[i], shade(col, 1.25), 1.2, true)

func sea_lily(p: Dictionary = {}):
	# Crinoid: a cup with five arms forking into ten feathery arms and a
	# jointed stalk trailing behind (whorls of cirri on stalked sea lilies).
	var col: Color = p.get("col", c8(190, 90, 120))
	spine_setup(0, 70, 4.0, 2.0)
	var stalk := []
	for i in 12:
		var x = -6.0 - i * 3.6
		stalk.append(sp(x))
	if p.get("cirri", false):
		for i in [3, 6, 9]:
			for side in [-1.0, 1.0]:
				var b: Vector2 = stalk[i]
				limb(pv([b, b + Vector2(-2, side * 6 + sin(t * 2 + i) * 0.8).rotated(sp_ang(b.x))]), 1.2, p.get("cirri_col", c8(240, 220, 160)))
	taper(pv(stalk), 4.6, 3.0, shade(col, 0.85))
	if not halo_pass:
		for i in range(1, 12):
			var b: Vector2 = stalk[i]
			var a = sp_ang(b.x)
			draw_line(b + Vector2(0, -2.2).rotated(a), b + Vector2(0, 2.2).rotated(a), shade(col, 0.6), 1.0, true)
	feather_arms(10, 34.0, col, 0.18 + 0.1 * move)
	disc(Vector2.ZERO, 8, shade(col, 1.1))
	dot(Vector2(-2, -2), 3, shade(col, 1.3))

func feather_star(p: Dictionary = {}):
	# Comatulid feather star: no stalk, a ring of grasping cirri under the
	# cup, and feathery arms that beat to swim.
	var col: Color = p.get("col", c8(220, 110, 160))
	if not halo_pass:
		for k in 12:
			var g = k * TAU / 12.0
			draw_line(Vector2.RIGHT.rotated(g) * 5, Vector2.RIGHT.rotated(g + 0.2) * 11, shade(col, 0.65), 1.6, true)
	feather_arms(p.get("arms", 10), 38.0 if p.get("arms", 10) <= 10 else 34.0, col, 0.3 + 0.25 * move)
	disc(Vector2.ZERO, 6.5, shade(col, 1.1))

func early_echinoderm():
	# Edrioasteroid-like: a plated disc with five curved food grooves
	# fringed with tube feet.
	var body = c8(200, 150, 170)
	spine_setup(0, 60, 0.0, 1.0)
	disc(Vector2.ZERO, 29, body)
	if halo_pass:
		return
	draw_circle(Vector2(-6, -6), 16, shade(body, 1.12), true, -1.0, true)
	for k in 22:
		var g = k * TAU / 22.0
		draw_circle(Vector2.RIGHT.rotated(g) * 25, 2.2, shade(body, 0.82), true, -1.0, true)
	for k in 5:
		var pts := PackedVector2Array()
		for i in 9:
			var f = i / 8.0
			pts.append(Vector2.RIGHT.rotated(k * TAU / 5 + f * 0.9) * (4 + f * 18))
		draw_polyline(pts, shade(body, 0.55), 3.0, true)
		for i in range(1, 9):
			var wave_ = sin(t * 4.0 + i + k + gait) * 1.2
			draw_circle(pts[i] + Vector2(wave_, 1.5).rotated(k), 1.1, c8(255, 230, 240), true, -1.0, true)
	draw_circle(Vector2.ZERO, 4.5, shade(body, 1.25), true, -1.0, true)

func free_moving_echinoderm():
	star({"col": c8(210, 140, 100), "len": 26.0, "w": 12.0, "disc": 15.0, "wiggle": 0.12})

func sea_star_line():
	star({"col": c8(230, 120, 70), "len": 34.0, "w": 10.0, "disc": 12.0, "madreporite": true})

func sea_star():
	star({"col": c8(200, 60, 90), "len": 33.0, "w": 11.0, "disc": 13.0, "tipeye": true})

func brittle_star():
	star({"col": c8(150, 120, 100), "len": 40.0, "w": 2.2, "disc": 10.0, "thin": true, "wiggle": 0.6, "groove": false, "bumps": false})

func spiny_echinozoan():
	# Early echinozoan: globe-shaped test with short spines and five double
	# rows of tube-foot pores.
	var body = c8(150, 100, 160)
	spine_setup(0, 60, 0.0, 1.0)
	for k in 22:
		var g = k * TAU / 22.0 + sin(t * 1.5 + k) * 0.05
		limb(pv([Vector2.RIGHT.rotated(g) * 18, Vector2.RIGHT.rotated(g) * (27 + 2.0 * tuck)]), 1.8, shade(body, 1.3))
	disc(Vector2.ZERO, 21, body)
	if not halo_pass:
		draw_circle(Vector2(-5, -5), 11, shade(body, 1.15), true, -1.0, true)
		for k in 5:
			for r in [6.0, 10.0, 14.0, 18.0]:
				for s in [-1.0, 1.0]:
					draw_circle(Vector2.RIGHT.rotated(k * TAU / 5 + s * 0.12) * r, 1.0, c8(240, 220, 250), true, -1.0, true)

func sea_urchin():
	# Sea urchin: round test bristling with long movable spines that sweep
	# as it walks and bristle on attack, five paired rows of tube feet.
	var body = c8(90, 50, 110)
	spine_setup(0, 60, 0.0, 1.0)
	var bristle = 1.0 + 0.15 * strike + 0.2 * tuck
	for k in 30:
		var g = k * TAU / 30.0 + sin(gait * 0.8 + k * 0.7) * 0.12 * clamp(move + 0.2, 0.0, 1.0)
		var ln = (35.0 if k % 2 else 29.0) * bristle
		taper(pv([Vector2.RIGHT.rotated(g) * 13, Vector2.RIGHT.rotated(g) * ln]), 2.4, 0.9, c8(170, 110, 200))
	disc(Vector2.ZERO, 17, body)
	if not halo_pass:
		draw_circle(Vector2(-4, -4), 9, shade(body, 1.2), true, -1.0, true)
		for k in 5:
			for r in [5.0, 9.0, 13.0]:
				for s in [-1.0, 1.0]:
					draw_circle(Vector2.RIGHT.rotated(k * TAU / 5 + s * 0.15) * r, 0.9, c8(220, 200, 240), true, -1.0, true)

func sea_cucumber():
	# Sea cucumber: soft sausage body, rows of tube feet, a ring of branched
	# feeding tentacles round the mouth and warty papillae on top.
	var body = c8(110, 80, 60)
	spine_setup(40, 84, 2.0, 1.5)
	var squash = sin(gait * 0.5) * 0.06 + 0.15 * tuck
	if not halo_pass:
		for i in 11:
			var x = 28 - i * 6.0
			for side in [-1.0, 1.0]:
				draw_circle(spo(x, side * (15.5 + sin(gait + i) * 0.8)), 1.4, c8(240, 210, 180), true, -1.0, true)
	for k in 10:
		var a = sp_ang(36) + (k - 4.5) / 4.5 * 1.4
		var b = sp(34)
		var ln = 9.0 + 2.0 * sin(t * 2.5 + k) + 4.0 * strike
		var tip = b + Vector2.RIGHT.rotated(a) * ln
		limb(pv([b, tip]), 1.4, c8(240, 220, 200))
		dot(tip, 1.6, c8(255, 235, 215))
	spine_body(36 * (1.0 - squash * 0.5), -40 * (1.0 - squash * 0.5), 14, func(f): return 13.0 * (1.0 + squash) * pow(sin(PI * clamp(f * 0.9 + 0.06, 0.0, 1.0)), 0.5) + 1.0, body)
	if not halo_pass:
		for q in [Vector2(20, -6), Vector2(10, 5), Vector2(0, -4), Vector2(-10, 6), Vector2(-20, -5), Vector2(-28, 3), Vector2(26, 4)]:
			draw_circle(spo(q.x, q.y), 2.2, shade(body, 1.4), true, -1.0, true)

# ───────────────────────── the first cell ─────────────────────────
func ancestral_collar_cell():
	# Choanoflagellate-like cell: an ovoid cell body, a collar of microvilli
	# behind it and one long flagellum whose travelling wave pushes it along.
	var body = Color(0.36, 0.82, 0.9)
	spine_setup(30, 60, 0.0, 1.0)
	var pts := PackedVector2Array()
	for k in 16:
		var f = k / 15.0
		pts.append(Vector2(-12 - f * 46, sin(swim * 1.5 - f * 7.0) * (1.0 + 8.0 * f) - bend * 18.0 * f * f))
	taper(pts, 2.8, 1.2, Color(0.78, 1.0, 0.97))
	fill(pv([Vector2(-4, -10), Vector2(-24, -17), Vector2(-24, 17), Vector2(-4, 10)]), Color(0.6, 1.0, 0.95, 0.22))
	if not halo_pass:
		for k in range(-6, 7):
			var a = k / 6.0
			draw_line(Vector2(-4, a * 10), Vector2(-24, a * 17 + sin(t * 2 + k) * 0.8), Color(0.75, 1.0, 0.96, 0.9), 1.4, true)
	var pulse = 1.0 + 0.04 * sin(t * 3.0) + 0.1 * strike
	oval(Vector2(6, 0), 21 * pulse, 17 / pulse, 0, Color(body.r, body.g, body.b, 0.95))
	if halo_pass:
		return
	draw_colored_polygon(ellipse_pts(Vector2(9, -3), 14, 10, 0), shade(body, 1.2))
	draw_circle(Vector2(9, 2), 7.5, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(9, 2), 6.5, Color(0.28, 0.38, 0.78), true, -1.0, true)
	draw_circle(Vector2(10, 3), 2.4, Color(0.5, 0.6, 0.95), true, -1.0, true)
	for k in 3:
		var g = t * 0.6 + k * 2.1
		draw_circle(Vector2(2 + cos(g) * 9, sin(g) * 8), 2.2 - k * 0.4, [Color(0.5, 0.9, 0.5), Color(0.95, 0.85, 0.45), Color(0.6, 0.95, 0.7)][k], true, -1.0, true)
	draw_colored_polygon(ellipse_pts(Vector2(16, -8), 5, 2.5, -0.5), Color(1, 1, 1, 0.6))

# id -> [drawing function, optional parameters]. Descendants that differ
# from their parent mostly in colour reuse its drawing with their own.
const FORMS = {
	"ancestral_collar_cell": ["ancestral_collar_cell"],
	"early_arthropod": ["early_arthropod"],
	"chelicerate": ["chelicerate"],
	"mandibulate": ["mandibulate"],
	"arachnid": ["arachnid"],
	"horseshoe_crab": ["horseshoe_crab"],
	"atlantic_horseshoe_crab": ["horseshoe_crab", {"col": Color(0.6, 0.5, 0.3)}],
	"mangrove_horseshoe_crab": ["horseshoe_crab", {"col": Color(0.28, 0.33, 0.24), "eye": Color(0.9, 0.9, 0.5)}],
	"myriapod": ["myriapod"],
	"malacostracan": ["malacostracan"],
	"hexapod": ["hexapod"],
	"decapod": ["decapod"],
	"scorpion": ["scorpion"],
	"spider": ["spider"],
	"centipede": ["centipede"],
	"millipede": ["millipede"],
	"dragonfly_line": ["dragonfly_line"],
	"beetle": ["beetle"],
	"mantis_shrimp_line": ["mantis_shrimp_line"],
	"pikaia_chordate": ["pikaia_chordate"],
	"jawed_fish": ["jawed_fish"],
	"jawless_fish": ["jawless_fish"],
	"early_shark": ["early_shark"],
	"ray_finned_fish": ["ray_finned_fish"],
	"shark_line": ["shark_line"],
	"chimaera": ["chimaera"],
	"sturgeon_line": ["sturgeon_line"],
	"teleost_line": ["teleost_line"],
	"lamprey": ["lamprey"],
	"sea_lamprey": ["lamprey", {"col": Color(0.5, 0.45, 0.32)}],
	"pouched_lamprey": ["lamprey", {"col": Color(0.3, 0.52, 0.62), "pouch": true}],
	"hagfish": ["hagfish"],
	"atlantic_hagfish": ["hagfish", {"col": Color(0.86, 0.66, 0.74)}],
	"pacific_hagfish": ["hagfish", {"col": Color(0.6, 0.42, 0.36), "gill_row": true}],
	"lobe_finned_shorewalker": ["lobe_finned_shorewalker"],
	"synapsid": ["synapsid"],
	"lissamphibian": ["lissamphibian"],
	"sauropsid": ["sauropsid"],
	"early_mollusc": ["early_mollusc"],
	"cephalopod": ["cephalopod"],
	"nautilus": ["nautilus"],
	"palau_nautilus": ["nautilus", {"stripes": Color(0.7, 0.25, 0.12)}],
	"crusty_nautilus": ["nautilus", {"stripes": Color(0.5, 0.35, 0.2), "crust": true, "skin": Color(0.75, 0.6, 0.5)}],
	"coleoid": ["coleoid"],
	"squid_line": ["squid_line"],
	"octopus_line": ["octopus_line"],
	"sea_snail": ["sea_snail"],
	"predatory_sea_snail": ["predatory_sea_snail"],
	"cone_snail": ["cone_snail"],
	"moon_snail": ["moon_snail"],
	"sea_slug_line": ["sea_slug_line"],
	"nudibranch": ["nudibranch"],
	"land_snail": ["land_snail"],
	"bivalve": ["bivalve"],
	"scallop": ["scallop"],
	"true_scallop": ["true_scallop"],
	"oyster": ["oyster"],
	"burrowing_clam": ["burrowing_clam"],
	"giant_clam": ["giant_clam"],
	"shipworm": ["shipworm"],
	"early_echinoderm": ["early_echinoderm"],
	"sea_lily": ["sea_lily"],
	"isocrinid_sea_lily": ["sea_lily", {"col": Color(0.85, 0.55, 0.35), "cirri": true}],
	"endoxocrinus": ["sea_lily", {"col": Color(0.9, 0.78, 0.45), "cirri": true}],
	"metacrinus": ["sea_lily", {"col": Color(0.62, 0.36, 0.62), "cirri": true}],
	"feather_star": ["feather_star"],
	"rosy_feather_star": ["feather_star", {"col": Color(0.94, 0.51, 0.59)}],
	"reef_feather_star": ["feather_star", {"col": Color(0.98, 0.75, 0.24), "arms": 20}],
	"free_moving_echinoderm": ["free_moving_echinoderm"],
	"sea_star_line": ["sea_star_line"],
	"sea_star": ["sea_star"],
	"brittle_star": ["brittle_star"],
	"spiny_echinozoan": ["spiny_echinozoan"],
	"sea_urchin": ["sea_urchin"],
	"sea_cucumber": ["sea_cucumber"],
}

func early_mollusc():
	# Early mollusc: one cap-shaped shell over a broad muscular foot and a
	# head with one pair of tentacles.
	var foot = c8(230, 150, 140)
	var shell = c8(220, 190, 120)
	spine_setup(34, 70, 0.0, 1.0)
	var ripple = sin(gait * 0.6) * 1.5
	oval(Vector2(ripple * 0.4, 0), 32 + ripple, 23, 0, foot)
	oval(Vector2(29, 0), 7, 9, 0, foot)
	for side in [-1.0, 1.0]:
		taper(pv([Vector2(32, side * 3), Vector2(38, side * 7), Vector2(42, side * (8 + sin(t * 2 + side)))]), 2.2, 1.4, shade(foot, 1.1))
		eye(Vector2(31, side * 5), 1.4)
	oval(Vector2(-3, 0), 26, 19, 0, shell)
	for k in [0.75, 0.5, 0.27]:
		if not halo_pass:
			var ring = ellipse_pts(Vector2(-3 - (1.0 - k) * 4, 0), 26 * k, 19 * k, 0)
			ring.append(ring[0])
			draw_polyline(ring, shade(shell, 0.78), 1.4, true)
	blob(Vector2(-8, -6), 8, 4, -0.3, shade(shell, 1.35))
