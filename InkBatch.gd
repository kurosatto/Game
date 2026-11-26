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
# One indexed triangle list. Strips, line grids and fans share vertices;
# their indices are cut from long prebuilt patterns (slice + append_array, done
# in the engine), so the script never loops per triangle
var verts := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
# Prebuilt index patterns, grown on demand:
#  _ID     0, 1, 2, 3 ...                       (plain triangle lists)
#  _STRIP  i, i+1, i+2 for each i               (a strip from vertex b is the slice 3b ..)
#  _GRID   9 quads of a 4x4 grid, every 16 verts (an antialiased line)
static var _ID := PackedInt32Array()
static var _STRIP := PackedInt32Array()
static var _GRID := PackedInt32Array()
# Antialiased polylines: four vertices per point (A edge, B other edge, C and
# D the faded outer feathers). Ladders between neighbouring points, by point:
static var _LAB := PackedInt32Array() # the stroke
static var _LAC := PackedInt32Array() # feather on the A side
static var _LBD := PackedInt32Array() # feather on the B side
const _GRID_QUADS := [
	[5, 9, 10, 6], [5, 1, 2, 6], [9, 13, 14, 10], [5, 4, 8, 9], [6, 7, 11, 10],
	[5, 4, 0, 1], [9, 8, 12, 13], [6, 7, 3, 2], [10, 11, 15, 14]]
# Solid colour runs, by colour
static var _solid := {}
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
	idx.resize(0)
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
	RenderingServer.canvas_item_add_triangle_array(ci, idx, verts, cols)
	verts = PackedVector2Array()
	cols = PackedColorArray()
	idx = PackedInt32Array()
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
static func _grow_patterns(n: int):
	# n: vertex count the patterns must reach
	if _ID.size() < n:
		var m := maxi(n * 2, 4096)
		var start := _ID.size()
		_ID.resize(m)
		for i in range(start, m):
			_ID[i] = i
		_STRIP.resize(m * 3)
		for i in m:
			_STRIP[i * 3] = i
			_STRIP[i * 3 + 1] = i + 1
			_STRIP[i * 3 + 2] = i + 2
		var pts := m / 4 + 1
		_LAB.resize(pts * 6)
		_LAC.resize(pts * 6)
		_LBD.resize(pts * 6)
		for i in pts:
			var v := i * 4
			var k6 := i * 6
			# strip order A0 B0 A1 B1 .. as triangles
			_LAB[k6] = v; _LAB[k6 + 1] = v + 1; _LAB[k6 + 2] = v + 4
			_LAB[k6 + 3] = v + 1; _LAB[k6 + 4] = v + 4; _LAB[k6 + 5] = v + 5
			_LAC[k6] = v; _LAC[k6 + 1] = v + 2; _LAC[k6 + 2] = v + 4
			_LAC[k6 + 3] = v + 2; _LAC[k6 + 4] = v + 4; _LAC[k6 + 5] = v + 6
			_LBD[k6] = v + 1; _LBD[k6 + 1] = v + 3; _LBD[k6 + 2] = v + 5
			_LBD[k6 + 3] = v + 3; _LBD[k6 + 4] = v + 5; _LBD[k6 + 5] = v + 7
		var blocks := m / 16 + 1
		_GRID.resize(blocks * 54)
		var k := 0
		for j in blocks:
			var o := j * 16
			for q in _GRID_QUADS:
				_GRID[k] = o + q[0]
				_GRID[k + 1] = o + q[1]
				_GRID[k + 2] = o + q[2]
				_GRID[k + 3] = o + q[0]
				_GRID[k + 4] = o + q[2]
				_GRID[k + 5] = o + q[3]
				k += 6

# n vertices of one colour
func _fill(c: Color, n: int):
	var run: PackedColorArray = _solid.get(c, PackedColorArray())
	if run.size() < n:
		run.resize(maxi(n, 256))
		run.fill(c)
		_solid[c] = run
		if _solid.size() > 4000:
			_solid.clear()
	cols.append_array(run.slice(0, n) if run.size() != n else run)

# Vertices drawn as a plain triangle list (three per triangle)
func _list(p: PackedVector2Array):
	var base := verts.size()
	var end := base + p.size()
	if _ID.size() < end:
		_grow_patterns(end)
	verts.append_array(p)
	idx.append_array(_ID.slice(base, end))

# Already-built indexed triangles (Shading.lit_poly / lit_tube)
func add_triangles(tri: PackedInt32Array, pts: PackedVector2Array, c: PackedColorArray):
	var base := verts.size()
	verts.append_array(pts if _ident else xf * pts)
	if c.size() == pts.size():
		cols.append_array(c)
	else:
		_fill(c[0] if c.size() > 0 else Color.WHITE, pts.size())
	if base == 0:
		idx.append_array(tri)
	else:
		for i in tri:
			idx.append(i + base)

# A triangle strip: triangles (i, i+1, i+2)
func _strip(pts: PackedVector2Array, c: PackedColorArray):
	var m := pts.size()
	if m < 3:
		return
	var base := verts.size()
	if _ID.size() < base + m:
		_grow_patterns(base + m)
	verts.append_array(pts if _ident else xf * pts)
	cols.append_array(c)
	idx.append_array(_STRIP.slice(base * 3, (base + m - 2) * 3))

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
	if not (filled and antialiased):
		draw_ellipse(pos, radius, radius, color, filled, width, antialiased)
		return
	# The common case, inlined: a filled, antialiased disc
	var q := 20.0 * _px * _xf_scale
	var r: float = max(0.0, radius - FEATHER * 0.25)
	if q > 0.0:
		r = roundf(r * q) / q
	var entry: Array = _disc_by_r.get(Vector2(r, q), [])
	if entry.is_empty():
		var n := _segments(r + FEATHER)
		_add_ellipse(pos, radius, radius, color, true)
		var key := Vector4(r, r, n, 1.0)
		if _discs.has(key):
			if _disc_by_r.size() > 3000:
				_disc_by_r.clear()
			_disc_by_r[Vector2(r, q)] = [_discs[key], n]
		return
	var tpl: PackedVector2Array = entry[0]
	var n: int = entry[1]
	var base := verts.size()
	var end := base + tpl.size()
	if _ID.size() < end:
		_grow_patterns(end)
	if _ident:
		verts.append_array(Transform2D(0.0, pos) * tpl)
	else:
		verts.append_array((xf * Transform2D(0.0, pos)) * tpl)
	idx.append_array(_ID.slice(base, end))
	var ck := Vector3i(n, color.to_rgba32(), 1)
	var pat: PackedColorArray = _disc_cols.get(ck, PackedColorArray())
	if pat.is_empty() or pat[0] != color:
		_disc_cols.erase(ck)
		_disc_pattern(n, color, true)
		pat = _disc_cols[ck]
	cols.append_array(pat)

static var _disc_by_r := {}

func draw_ellipse(pos: Vector2, major: float, minor: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false):
	if filled:
		_add_ellipse(pos, major, minor, color, antialiased)
	elif width >= 2.0 * max(major, minor):
		_add_ellipse(pos, major + 0.5 * width, minor + 0.5 * width, color, antialiased)
	else:
		var pts := Transform2D(Vector2(major, 0), Vector2(0, minor), pos) * _unit(64)
		pts[64] = pts[0]
		draw_polyline(pts, color, width, antialiased)

# Whole circles (fan + feather) by size, in the circle's own space, and their
# colour runs by colour. Sizes are rounded to 1/20 of a screen pixel so a leg
# that swells a little as it lifts still finds its circle already built.
static var _discs := {}
static var _disc_cols := {}

func _add_ellipse(pos: Vector2, major: float, minor: float, color: Color, aa: bool):
	if aa:
		major = max(0.0, major - FEATHER * 0.25)
		minor = max(0.0, minor - FEATHER * 0.25)
	var q := 20.0 * _px * _xf_scale
	if q > 0.0:
		major = roundf(major * q) / q
		minor = roundf(minor * q) / q
	var n := _segments(max(major, minor) + (FEATHER if aa else 0.0))
	var key := Vector4(major, minor, n, 1.0 if aa else 0.0)
	var tpl: PackedVector2Array = _discs.get(key, PackedVector2Array())
	if tpl.is_empty():
		_unit(n)
		tpl = Transform2D(Vector2(major, 0), Vector2(0, minor), Vector2.ZERO) * _fans[n]
		if aa:
			var border := FEATHER
			var max_axis = max(major, minor) * 2.0
			if 0.0 <= max_axis and max_axis < 1.0:
				border *= max_axis * 0.5
			# The feather: a strip from the edge out to a transparent ring
			var u: PackedVector2Array = _units[n]
			var inner := Transform2D(Vector2(major, 0), Vector2(0, minor), Vector2.ZERO) * u
			var outer := Transform2D(Vector2(major + border, 0), Vector2(0, minor + border), Vector2.ZERO) * u
			for i in n:
				tpl.append(inner[i])
				tpl.append(outer[i])
				tpl.append(inner[i + 1])
				tpl.append(outer[i])
				tpl.append(inner[i + 1])
				tpl.append(outer[i + 1])
		if _discs.size() > 3000:
			_discs.clear()
		_discs[key] = tpl
	var place := Transform2D(0.0, pos)
	if not _ident:
		place = xf * place
	_list(place * tpl)
	# The fan in one colour, then the feather fading out
	var ck := Vector3i(n, color.to_rgba32(), 1 if aa else 0) # 8-bit key: only picks the cached copy
	var pat: PackedColorArray = _disc_cols.get(ck, PackedColorArray())
	if pat.is_empty() or pat[0] != color:
		pat = _disc_pattern(n, color, aa)
	cols.append_array(pat)

static func _disc_pattern(n: int, color: Color, aa: bool) -> PackedColorArray:
	var pat := PackedColorArray()
	pat.resize(n * 3)
	pat.fill(color)
	if aa:
		var tr := Color(color, 0.0)
		var fe := PackedColorArray([color, tr, color, tr, color, tr])
		while fe.size() < n * 6:
			fe.append_array(fe)
		fe.resize(n * 6)
		pat.append_array(fe)
	if _disc_cols.size() > 3000:
		_disc_cols.clear()
	_disc_cols[Vector3i(n, color.to_rgba32(), 1 if aa else 0)] = pat
	return pat

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
	if not antialiased:
		var base := verts.size()
		var q := PackedVector2Array([from + t, from - t, to - t, to + t])
		verts.append_array(q if _ident else xf * q)
		_fill(color, 4)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		return
	var bs := FEATHER
	if 0.0 <= width and width < 1.0:
		bs *= width
	var bo := dir * bs
	var bo2 := diff.normalized() * bs
	# A 4x4 grid: rows across the line (outer feather, edge, edge, outer
	# feather), columns along it (feather beyond `from`, from, to, feather
	# beyond `to`). The inner four are the line, the rest fade out.
	var f0 := from + bo2
	var t3 := to - bo2
	var a0 := t + bo
	var a3 := -t - bo
	var g := PackedVector2Array([
		f0 + a0, from + a0, to + a0, t3 + a0,
		f0 + t, from + t, to + t, t3 + t,
		f0 - t, from - t, to - t, t3 - t,
		f0 + a3, from + a3, to + a3, t3 + a3])
	# Start on a multiple of 16 so the prebuilt grid indices fit
	var base := verts.size()
	var pad := (16 - (base & 15)) & 15
	if pad > 0:
		base += pad
		verts.resize(base)
		cols.resize(base)
	if _ID.size() < base + 16:
		_grow_patterns(base + 16)
	verts.append_array(g if _ident else xf * g)
	var pk := Vector2i(-16, color.to_rgba32())
	var pat: PackedColorArray = _pattern.get(pk, PackedColorArray())
	if pat.is_empty() or pat[5] != color:
		var tr := Color(color, 0.0)
		pat = PackedColorArray([tr, tr, tr, tr, tr, color, color, tr, tr, color, color, tr, tr, tr, tr, tr])
		_pattern[pk] = pat
	cols.append_array(pat)
	var j := base / 16 * 54
	idx.append_array(_GRID.slice(j, j + 54))

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
	if antialiased and colors.size() == 1:
		_aa_polyline(points, colors[0], width)
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

# Colour runs for _aa_polyline: per point the stroke colour twice, then the
# faded feather twice
static var _poly_cols := {}

# One-colour antialiased polyline (width already compensated). The same
# triangles as Godot's own (the engine's strip and its two feathers, with the
# end caps as one extra faded point at each end), but every point's four
# vertices are written once and the triangles come from the prebuilt ladders.
func _aa_polyline(points: PackedVector2Array, color: Color, width: float):
	var n := points.size()
	var bs := FEATHER
	if width < 1.0:
		bs *= width
	var hw := width * 0.5
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
	var caps := 0 if loop else 1
	var count := n + caps * 2 # points, with the cap points
	var v := PackedVector2Array()
	v.resize(count * 4)
	var prev := Vector2.ZERO
	var j := caps * 4
	for i in n:
		var pos := points[i]
		var seg := prev
		if i < n - 1:
			var d := (points[i + 1] - pos).normalized()
			if not d.is_zero_approx():
				seg = d
		var base: Vector2
		if not loop and i == 0:
			base = first_dir.orthogonal()
		elif not loop and i == n - 1:
			base = last_dir.orthogonal()
		else:
			if loop:
				if i == 0:
					prev = last_dir
				elif i == n - 1:
					prev = first_dir
			var length := 1.0
			var bis := (prev * seg.length() - seg * prev.length()).normalized()
			var sn := sin(atan2(bis.cross(prev), bis.dot(prev)))
			if not is_zero_approx(sn) and not seg.is_equal_approx(prev):
				length = clamp(1.0 / sn, -3.0, 3.0)
			else:
				bis = seg.orthogonal()
			if bis.is_zero_approx():
				bis = seg.orthogonal()
			base = bis * length
		var eo := base * hw
		var bo := base * bs
		v[j] = pos + eo
		v[j + 1] = pos - eo
		v[j + 2] = pos + eo + bo
		v[j + 3] = pos - eo - bo
		j += 4
		prev = seg
	if caps:
		# Faded points just beyond each end
		var bb := -first_dir * bs
		v[0] = v[4] + bb
		v[1] = v[5] + bb
		v[2] = v[6] + bb
		v[3] = v[7] + bb
		var eb := prev * bs
		var e := count * 4 - 4
		v[e] = v[e - 4] + eb
		v[e + 1] = v[e - 3] + eb
		v[e + 2] = v[e - 2] + eb
		v[e + 3] = v[e - 1] + eb
	# Start on a multiple of 4 so the ladders fit
	var vb := verts.size()
	var pad := (4 - (vb & 3)) & 3
	if pad > 0:
		vb += pad
		verts.resize(vb)
		cols.resize(vb)
	if _ID.size() < vb + count * 4 + 8:
		_grow_patterns(vb + count * 4 + 8)
	verts.append_array(v if _ident else xf * v)
	var key := color.to_rgba32()
	var run: PackedColorArray = _poly_cols.get(key, PackedColorArray())
	if run.is_empty() or run[0] != color:
		var tr := Color(color, 0.0)
		run = PackedColorArray([color, color, tr, tr])
		while run.size() < 256:
			run.append_array(run)
		if _poly_cols.size() > 2000:
			_poly_cols.clear()
		_poly_cols[key] = run
	if run.size() < n * 4:
		while run.size() < n * 4:
			run.append_array(run)
		_poly_cols[key] = run
	var tr4 := PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, 0.0), Color(color, 0.0)])
	if caps:
		cols.append_array(tr4)
	cols.append_array(run.slice(0, n * 4))
	if caps:
		cols.append_array(tr4)
	var p0 := vb / 4
	var a := p0 * 6
	var b := (p0 + count - 1) * 6
	# Same order as the engine: the stroke, then its two feathers
	idx.append_array(_LAB.slice(a, b))
	idx.append_array(_LAC.slice(a, b))
	idx.append_array(_LBD.slice(a, b))
