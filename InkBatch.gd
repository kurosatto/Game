# InkBatch.gd
# Draws a code-drawn animal (PlayerBody.gd, bosses/BossBase.gd) in ONE draw
# call instead of hundreds. Each draw_circle / draw_line / draw_polyline /
# draw_arc / draw_colored_polygon of a body used to become its own GPU draw
# call and its own vertex buffer, rebuilt every frame: a millipede cost over
# 2,000 draw calls a frame, which is what made the game lag on phones.
#
# This has the same functions with the same arguments, and builds exactly
# the triangles Godot itself would (ported from Godot 4.7's
# renderer_canvas_cull.cpp: same 64-segment circles, same antialiasing
# feathers and line joins), so the drawing looks the same. Everything goes
# into one triangle array that flush() sends at the end of _draw().
#
# Use:  var ink = InkBatch.new()
#       func _draw():
#           ink.begin(self)
#           ink.draw_circle(...)    # instead of draw_circle(...)
#           ink.flush()
extends RefCounted

const FEATHER := 1.25
# Circles: Godot always uses 64 segments; small ones use fewer, picked so
# the outline is never more than PRECISION screen pixels off a true circle
# (invisible, and the antialiased edge covers it)
const SEG_STEPS := [8, 12, 16, 24, 32, 48, 64]
const PRECISION := 0.1

# Per segment count: the unit circle, and the filled fan as a triangle list
static var _units := {}
static var _fans := {}
# Local triangles of antialiased circle feathers, by size (radius repeats)
static var _feathers := {}

var ci: RID
var item: CanvasItem
var xf := Transform2D.IDENTITY
var _ident := true
var _px := 1.0       # screen pixels per local unit of the item
var _xf_scale := 1.0 # extra scale of the current draw_set_transform
# One non-indexed triangle list: three vertices per triangle
var verts := PackedVector2Array()
var cols := PackedColorArray()
var _native_xf := false # a native command set a transform since the last flush
var _pattern := {}      # feather colour patterns used this frame
# Time spent drawing (tools/drawcount.gd reads it)
static var prof_us := 0
var _t0 := 0

# Where the vision fog is solid black this frame, in world coordinates
# (VisionFog.gd sets it), so animals standing wholly inside it can skip
# redrawing (nobody can see them). Radius -1 when off: caves and glowing
# rooms, where lights open up the dark, and outside a run.
static var fog_center := Vector2.ZERO
static var fog_radius := -1.0

static func hidden_by_fog(world_pos: Vector2, extent: float) -> bool:
	return fog_radius > 0.0 and world_pos.distance_to(fog_center) > fog_radius + extent

static func _unit(n: int) -> PackedVector2Array:
	if not _units.has(n):
		var u := PackedVector2Array()
		var step := TAU / n
		for i in n + 1:
			var a := i * step
			u.append(Vector2(cos(a), sin(a)))
		_units[n] = u
		var fan := PackedVector2Array()
		for i in n:
			fan.append(Vector2.ZERO)
			fan.append(u[i])
			fan.append(u[i + 1])
		_fans[n] = fan
	return _units[n]

func begin(target: CanvasItem):
	_t0 = Time.get_ticks_usec()
	item = target
	ci = target.get_canvas_item()
	xf = Transform2D.IDENTITY
	_ident = true
	_xf_scale = 1.0
	verts.resize(0)
	cols.resize(0)
	_native_xf = false
	_pattern.clear()
	var t := target.get_viewport().get_final_transform() * target.get_global_transform_with_canvas() if target.is_inside_tree() else Transform2D.IDENTITY
	var sc := t.get_scale()
	_px = max(abs(sc.x), abs(sc.y))

# Send everything drawn since begin() (or the last flush) as one draw call
func flush():
	prof_us += Time.get_ticks_usec() - _t0
	if verts.is_empty():
		return
	if _native_xf:
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
		_native_xf = false
	RenderingServer.canvas_item_add_triangle_array(ci, PackedInt32Array(), verts, cols)
	verts = PackedVector2Array()
	cols = PackedColorArray()
	if _feathers.size() > 6000:
		_feathers.clear()

func draw_set_transform(offset: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE):
	draw_set_transform_matrix(Transform2D(rot, scale, 0.0, offset))

func draw_set_transform_matrix(m: Transform2D):
	xf = m
	_ident = xf == Transform2D.IDENTITY
	var sc := xf.get_scale()
	_xf_scale = max(abs(sc.x), abs(sc.y))

# ── Low level ──
func _fill(c: Color, n: int):
	var tmp := PackedColorArray()
	tmp.resize(n)
	tmp.fill(c)
	cols.append_array(tmp)

# Already-built indexed triangles (Shading.lit_poly / lit_tube)
func add_triangles(tri: PackedInt32Array, pts: PackedVector2Array, c: PackedColorArray):
	var p := pts if _ident else xf * pts
	if c.size() == pts.size():
		for i in tri:
			verts.append(p[i])
			cols.append(c[i])
	else:
		for i in tri:
			verts.append(p[i])
		_fill(c[0] if c.size() > 0 else Color.WHITE, tri.size())

# A Godot quad primitive: triangles 0,1,2 and 0,2,3
func _quad(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, c0: Color, c1: Color, c2: Color, c3: Color):
	if not _ident:
		p0 = xf * p0
		p1 = xf * p1
		p2 = xf * p2
		p3 = xf * p3
	verts.append(p0)
	verts.append(p1)
	verts.append(p2)
	verts.append(p0)
	verts.append(p2)
	verts.append(p3)
	cols.append(c0)
	cols.append(c1)
	cols.append(c2)
	cols.append(c0)
	cols.append(c2)
	cols.append(c3)

# A triangle strip
func _strip(pts: PackedVector2Array, c: PackedColorArray):
	var p := pts if _ident else xf * pts
	for i in p.size() - 2:
		verts.append(p[i])
		verts.append(p[i + 1])
		verts.append(p[i + 2])
		cols.append(c[i])
		cols.append(c[i + 1])
		cols.append(c[i + 2])

static func _comp_width(w: float) -> float:
	if w > 0.0:
		if w <= FEATHER * 2.0 + 0.00001:
			return w * 0.5
		elif w <= FEATHER * 4.0 + 0.00001:
			return remap(w, FEATHER * 2.0, FEATHER * 4.0, w * 0.5, w - FEATHER * 0.5)
		return w - FEATHER * 0.5
	return w

# Thin (width < 0) lines are GL lines, not triangles: those still go
# straight to the engine, in order
func _native_begin():
	flush()
	RenderingServer.canvas_item_add_set_transform(ci, xf)
	_native_xf = true

# Fewest circle segments that stay within PRECISION of a true circle
func _segments(r: float) -> int:
	var rs := r * _px * _xf_scale
	if rs <= PRECISION:
		return SEG_STEPS[0]
	var need := PI / acos(1.0 - PRECISION / rs) if rs > PRECISION * 0.5 else 4.0
	for n in SEG_STEPS:
		if n >= need:
			return n
	return 64

# ── The CanvasItem draw functions ──
func draw_circle(pos: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false):
	draw_ellipse(pos, radius, radius, color, filled, width, antialiased)

func draw_ellipse(pos: Vector2, major: float, minor: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false):
	if filled:
		_add_ellipse(pos, major, minor, color, antialiased)
	elif width >= 2.0 * max(major, minor):
		_add_ellipse(pos, major + 0.5 * width, minor + 0.5 * width, color, antialiased)
	else:
		var pts := Transform2D(Vector2(major, 0), Vector2(0, minor), pos) * _unit(64)
		pts[64] = pts[0]
		draw_polyline(pts, color, width, antialiased)

func _add_ellipse(pos: Vector2, major: float, minor: float, color: Color, aa: bool):
	if aa:
		major = max(0.0, major - FEATHER * 0.25)
		minor = max(0.0, minor - FEATHER * 0.25)
	var n := _segments(max(major, minor) + (FEATHER if aa else 0.0))
	_unit(n)
	var place := Transform2D(0.0, pos)
	if not _ident:
		place = xf * place
	# The filled fan, all one colour
	verts.append_array(place * Transform2D(Vector2(major, 0), Vector2(0, minor), Vector2.ZERO) * _fans[n])
	_fill(color, n * 3)
	if not aa:
		return
	var border := FEATHER
	var max_axis = max(major, minor) * 2.0
	if 0.0 <= max_axis and max_axis < 1.0:
		border *= max_axis * 0.5
	# The feather: a strip from the edge out to a transparent ring
	var key := Vector4(major, minor, border, n)
	var tri: PackedVector2Array = _feathers.get(key, PackedVector2Array())
	if tri.is_empty():
		var u: PackedVector2Array = _units[n]
		var inner := Transform2D(Vector2(major, 0), Vector2(0, minor), Vector2.ZERO) * u
		var outer := Transform2D(Vector2(major + border, 0), Vector2(0, minor + border), Vector2.ZERO) * u
		for i in n:
			tri.append(inner[i])
			tri.append(outer[i])
			tri.append(inner[i + 1])
			tri.append(outer[i])
			tri.append(inner[i + 1])
			tri.append(outer[i + 1])
		_feathers[key] = tri
	verts.append_array(place * tri)
	var pk := Vector2i(n, color.to_rgba32()) # colours to 8 bits: only picks the cached copy
	var pat: PackedColorArray = _pattern.get(pk, PackedColorArray())
	if pat.is_empty() or pat[0] != color:
		var tr := Color(color, 0.0)
		pat = PackedColorArray([color, tr, color, tr, color, tr])
		while pat.size() < n * 6:
			pat.append_array(pat)
		pat.resize(n * 6)
		_pattern[pk] = pat
	cols.append_array(pat)

func draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float = -1.0, antialiased: bool = false):
	var pts := PackedVector2Array()
	pts.resize(point_count)
	var delta = clamp(end_angle - start_angle, -TAU, TAU)
	for i in point_count:
		var th = (i / (point_count - 1.0)) * delta + start_angle
		pts[i] = center + Vector2(radius * cos(th), radius * sin(th))
	draw_polyline(pts, color, width, antialiased)

func draw_colored_polygon(points: PackedVector2Array, color: Color, _uvs: PackedVector2Array = PackedVector2Array(), _texture: Texture2D = null):
	draw_polygon(points, PackedColorArray([color]))

func draw_polygon(points: PackedVector2Array, colors: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _texture: Texture2D = null):
	if points.size() < 3:
		return
	var tri := Geometry2D.triangulate_polygon(points)
	if tri.is_empty():
		push_error("Invalid polygon data, triangulation failed.")
		return
	add_triangles(tri, points, colors)

func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false):
	if width < 0.0:
		_native_begin()
		RenderingServer.canvas_item_add_line(ci, from, to, color, width, antialiased)
		return
	var diff := from - to
	var dir := diff.orthogonal().normalized()
	if antialiased:
		width = _comp_width(width)
	var t := dir * width * 0.5
	var bl := from + t
	var br := from - t
	var el := to + t
	var er := to - t
	_quad(bl, br, er, el, color, color, color, color)
	if antialiased:
		var bs := FEATHER
		if 0.0 <= width and width < 1.0:
			bs *= width
		var dir2 := diff.normalized()
		var bo := dir * bs
		var bo2 := dir2 * bs
		var tr := Color(color, 0.0)
		_quad(bl, bl + bo, el + bo, el, color, tr, tr, color)
		_quad(br, br - bo, er - bo, er, color, tr, tr, color)
		_quad(bl, bl + bo2, br + bo2, br, color, tr, tr, color)
		_quad(el, el - bo2, er - bo2, er, color, tr, tr, color)
		_quad(bl, bl + bo2, bl + bo + bo2, bl + bo, color, tr, tr, tr)
		_quad(br, br + bo2, br - bo + bo2, br - bo, color, tr, tr, tr)
		_quad(el, el - bo2, el + bo - bo2, el + bo, color, tr, tr, tr)
		_quad(er, er - bo2, er - bo - bo2, er - bo, color, tr, tr, tr)

static func _seg_dir(pts: PackedVector2Array, i: int, prev: Vector2) -> Vector2:
	if i == pts.size() - 1:
		return prev
	var d := (pts[i + 1] - pts[i]).normalized()
	return prev if d.is_zero_approx() else d

static func _edge_offset(seg: Vector2, prev: Vector2) -> Vector2:
	var length := 1.0
	var bis := (prev * seg.length() - seg * prev.length()).normalized()
	var ang := atan2(bis.cross(prev), bis.dot(prev))
	var s := sin(ang)
	if not is_zero_approx(s) and not seg.is_equal_approx(prev):
		length = clamp(1.0 / s, -3.0, 3.0)
	else:
		bis = seg.orthogonal()
	if bis.is_zero_approx():
		bis = seg.orthogonal()
	return bis * length

func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false):
	draw_polyline_colors(points, PackedColorArray([color]), width, antialiased)

func draw_polyline_colors(points: PackedVector2Array, colors: PackedColorArray, width: float = -1.0, antialiased: bool = false):
	var n := points.size()
	if n < 2:
		push_error("A polyline needs at least 2 points.")
		return
	if antialiased:
		width = _comp_width(width)
	if width < 0.0:
		_native_begin()
		RenderingServer.canvas_item_add_polyline(ci, points, colors, width, antialiased)
		return
	var color := Color(1, 1, 1, 1)
	var loop := points[0].is_equal_approx(points[n - 1])
	var first_dir := Vector2.ZERO
	var last_dir := Vector2.ZERO
	for i in range(1, n):
		first_dir = (points[i] - points[i - 1]).normalized()
		if not first_dir.is_zero_approx():
			break
	for i in range(n - 1, 0, -1):
		last_dir = (points[i] - points[i - 1]).normalized()
		if not last_dir.is_zero_approx():
			break
	var pc := n * 2
	var ncols := colors.size()
	if not antialiased:
		var mp := PackedVector2Array()
		var mc := PackedColorArray()
		mp.resize(pc)
		mc.resize(pc)
		var prev := Vector2.ZERO
		for i in n:
			var seg := _seg_dir(points, i, prev)
			if i == 0 and loop:
				prev = last_dir
			elif i == n - 1 and loop:
				prev = first_dir
			var base: Vector2
			if i == 0 and not loop:
				base = first_dir.orthogonal()
			elif i == n - 1 and not loop:
				base = last_dir.orthogonal()
			else:
				base = _edge_offset(seg, prev)
			var eo := base * (width * 0.5)
			var pos := points[i]
			mp[i * 2] = pos + eo
			mp[i * 2 + 1] = pos - eo
			if i < ncols:
				color = colors[i]
			mc[i * 2] = color
			mc[i * 2 + 1] = color
			prev = seg
		_strip(mp, mc)
		return
	var bs := FEATHER
	if width < 1.0:
		bs *= width
	var color2 := Color(1, 1, 1, 0)
	var extra := 0 if loop else 4
	var extra_side := 0 if loop else 5
	var mp := PackedVector2Array()
	var mc := PackedColorArray()
	var lp := PackedVector2Array()
	var lc := PackedColorArray()
	var rp := PackedVector2Array()
	var rc := PackedColorArray()
	mp.resize(pc + extra)
	mc.resize(pc + extra)
	lp.resize(pc + extra_side)
	lc.resize(pc + extra_side)
	rp.resize(pc + extra_side)
	rc.resize(pc + extra_side)
	var prev := Vector2.ZERO
	for i in n:
		var first := i == 0
		var last := i == n - 1
		var seg := _seg_dir(points, i, prev)
		if first and loop:
			prev = last_dir
		elif last and loop:
			prev = first_dir
		var base: Vector2
		if first and not loop:
			base = first_dir.orthogonal()
		elif last and not loop:
			base = last_dir.orthogonal()
		else:
			base = _edge_offset(seg, prev)
		var eo := base * (width * 0.5)
		var bo := base * bs
		var pos := points[i]
		var j := i * 2 + (0 if loop else 2)
		mp[j] = pos + eo
		mp[j + 1] = pos - eo
		lp[j] = pos + eo
		lp[j + 1] = pos + eo + bo
		rp[j] = pos - eo
		rp[j + 1] = pos - eo - bo
		if i < ncols:
			color = colors[i]
			color2 = Color(color.r, color.g, color.b, 0)
		mc[j] = color
		mc[j + 1] = color
		lc[j] = color
		lc[j + 1] = color2
		rc[j] = color
		rc[j + 1] = color2
		if first and not loop:
			var bb := -seg * bs
			mp[0] = pos + eo + bb
			mp[1] = pos - eo + bb
			mc[0] = color2
			mc[1] = color2
			lp[0] = pos + eo + bb
			lp[1] = pos + eo + bb + bo
			lc[0] = color2
			lc[1] = color2
			rp[0] = pos - eo + bb
			rp[1] = pos - eo + bb - bo
			rc[0] = color2
			rc[1] = color2
		if last and not loop:
			var eb := prev * bs
			var e := pc + 2
			mp[e] = pos + eo + eb
			mp[e + 1] = pos - eo + eb
			mc[e] = color2
			mc[e + 1] = color2
			lp[e] = pos + eo
			lp[e + 1] = pos + eo + eb + bo
			lp[e + 2] = pos + eo + eb
			lc[e] = color
			lc[e + 1] = color2
			lc[e + 2] = color2
			rp[e] = pos - eo
			rp[e + 1] = pos - eo + eb - bo
			rp[e + 2] = pos - eo + eb
			rc[e] = color
			rc[e + 1] = color2
			rc[e + 2] = color2
		prev = seg
	# Same order as the engine: the line, then its left and right feathers
	_strip(mp, mc)
	_strip(lp, lc)
	_strip(rp, rc)
