# ArtShape.gd
# Where things are drawn, so a hit lands only when the drawings touch.
# kuro (2026-11-25): "a leaf monster hit me even if the visual looks like it
# did not hit me, make all the damages accurate". Every hit on the player
# (bites, body contact, the Charnia lash, spit, boss strikes, hazards) is
# tested against the player's drawn body, and animal contact against the
# animal's drawing too, instead of against collision circles.
#
# Two kinds of drawing:
#  - a Sprite2D sheet frame: its alpha is turned once into a coarse distance
#    field (cached per texture and frame), so the gap from any point to the
#    painted pixels is one lookup
#  - code-drawn art (PlayerBody.gd with a HitPen.gd): the solid strokes and
#    fills recorded as it drew, [a, b, half width] capsules and
#    [points, centre, bound] polygons
# A drawing also gives sample circles along its outline, so two drawings
# touch when any sample of one is within its radius of the other.
extends RefCounted

const ALPHA := 0.5 # painted pixels at least this opaque count
const GRID := 64 # distance field cells across a frame's longer side

static var _masks := {}

# ── Sprite frames ──

# {cell, gw, gh, fw, fh, df (gap in texture px, 0 inside), edge (outline
# cell centres, frame px from the frame's middle), reach (furthest painted
# pixel from the middle)}, or {} when the sprite shows nothing readable
static func mask(spr: Sprite2D) -> Dictionary:
	var tex: Texture2D = spr.texture
	if tex == null:
		return {}
	var key := "%d:%d:%d:%d" % [tex.get_rid().get_id(), spr.hframes, spr.vframes, spr.frame]
	if _masks.has(key):
		return _masks[key]
	var m := _build(tex, spr.hframes, spr.vframes, spr.frame)
	_masks[key] = m
	return m

static func _build(tex: Texture2D, hf: int, vf: int, frame: int) -> Dictionary:
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return {}
	if img.is_compressed():
		img = img.duplicate()
		if img.decompress() != OK:
			return {}
	var fw := int(img.get_width() / max(hf, 1))
	var fh := int(img.get_height() / max(vf, 1))
	var region := img.get_region(Rect2i((frame % max(hf, 1)) * fw, (frame / max(hf, 1)) * fh, fw, fh))
	region.convert(Image.FORMAT_RGBA8)
	var cell: float = max(1.0, float(max(fw, fh)) / GRID)
	var gw := int(ceil(fw / cell))
	var gh := int(ceil(fh / cell))
	# Each cell's share of painted pixels: shrink with averaging
	region.resize(gw, gh, Image.INTERPOLATE_BILINEAR)
	var n := gw * gh
	var near := PackedVector2Array() # nearest painted cell, per cell
	near.resize(n)
	var d2 := PackedFloat32Array()
	d2.resize(n)
	var far := Vector2(-1e6, -1e6)
	for y in gh:
		for x in gw:
			var i := y * gw + x
			if region.get_pixel(x, y).a >= ALPHA:
				near[i] = Vector2(x, y)
				d2[i] = 0.0
			else:
				near[i] = far
				d2[i] = INF
	# Two sweeps passing the nearest painted cell on to neighbours
	var fwd := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]
	var back := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]
	for pass_i in 2:
		var dirs: Array = fwd if pass_i == 0 else back
		var ys := range(gh) if pass_i == 0 else range(gh - 1, -1, -1)
		var xs := range(gw) if pass_i == 0 else range(gw - 1, -1, -1)
		for y in ys:
			for x in xs:
				var i: int = y * gw + x
				if d2[i] == 0.0:
					continue
				var here := Vector2(x, y)
				for o in dirs:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
						continue
					var q: Vector2 = near[ny * gw + nx]
					if q.x < -1e5:
						continue
					var dd := here.distance_squared_to(q)
					if dd < d2[i]:
						d2[i] = dd
						near[i] = q
	var df := PackedFloat32Array()
	df.resize(n)
	var edge := PackedVector2Array()
	var reach := 0.0
	var any := false
	var mid := Vector2(fw, fh) * 0.5
	for y in gh:
		for x in gw:
			var i := y * gw + x
			if d2[i] == 0.0:
				any = true
				df[i] = 0.0
				var c := (Vector2(x, y) + Vector2(0.5, 0.5)) * cell - mid
				reach = max(reach, c.length() + cell * 0.71)
				# Outline cells: a neighbour is unpainted or off the frame
				var rim := x == 0 or y == 0 or x == gw - 1 or y == gh - 1
				if not rim:
					rim = d2[i - 1] > 0.0 or d2[i + 1] > 0.0 or d2[i - gw] > 0.0 or d2[i + gw] > 0.0
				if rim:
					edge.append(c)
			else:
				# Painted cells reach half a cell toward us
				df[i] = max(0.0, sqrt(d2[i]) - 0.5) * cell
	if not any:
		return {}
	return {"cell": cell, "gw": gw, "gh": gh, "fw": fw, "fh": fh, "df": df, "edge": edge, "reach": reach}

# From world space to frame pixels measured from the frame's middle
static func _to_frame(spr: Sprite2D) -> Transform2D:
	var xf := spr.get_global_transform()
	var off := spr.offset
	if not spr.centered:
		off += Vector2(_m_size(spr)) * 0.5
	var t := Transform2D(0.0, -off) * xf.affine_inverse()
	if spr.flip_h:
		t = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO) * t
	if spr.flip_v:
		t = Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2.ZERO) * t
	return t

static func _m_size(spr: Sprite2D) -> Vector2i:
	var s := spr.texture.get_size()
	return Vector2i(int(s.x / max(spr.hframes, 1)), int(s.y / max(spr.vframes, 1)))

static func _scale_of(spr: Node2D) -> float:
	var s := spr.get_global_transform().get_scale()
	return max(0.001, (absf(s.x) + absf(s.y)) * 0.5)

# World distance from p to the nearest painted pixel (0 when on the paint)
static func sprite_gap(spr: Sprite2D, p: Vector2) -> float:
	var m := mask(spr)
	if m.is_empty():
		return INF
	var q: Vector2 = _to_frame(spr) * p + Vector2(m.fw, m.fh) * 0.5
	var c := Vector2(clamp(q.x, 0.0, m.fw - 0.01), clamp(q.y, 0.0, m.fh - 0.01))
	var gx := int(c.x / m.cell)
	var gy := int(c.y / m.cell)
	var g: float = m.df[gy * m.gw + gx] + q.distance_to(c)
	return g * _scale_of(spr)

# The same as a Callable(p) -> gap, with the frame looked up once, for
# testing many points against one pose
static func sprite_gapper(spr: Sprite2D) -> Callable:
	var m := mask(spr)
	if m.is_empty():
		return func(_p): return INF
	var t := _to_frame(spr)
	var k := _scale_of(spr)
	var half := Vector2(m.fw, m.fh) * 0.5
	var lim := Vector2(m.fw - 0.01, m.fh - 0.01)
	var cell: float = m.cell
	var gw: int = m.gw
	var df: PackedFloat32Array = m.df
	return func(p: Vector2) -> float:
		var q: Vector2 = t * p + half
		var c := q.clamp(Vector2.ZERO, lim)
		return (df[int(c.y / cell) * gw + int(c.x / cell)] + q.distance_to(c)) * k

# Outline sample circles [world point, radius] of the sprite's frame
static func sprite_samples(spr: Sprite2D) -> Array:
	var m := mask(spr)
	var out: Array = []
	if m.is_empty():
		return out
	var inv := _to_frame(spr).affine_inverse()
	var r: float = m.cell * 0.71 * _scale_of(spr)
	for c in m.edge:
		out.append([inv * c, r])
	return out

# Furthest painted point from the sprite's world position, in world px
static func sprite_reach(spr: Sprite2D) -> float:
	var m := mask(spr)
	if m.is_empty():
		return 0.0
	var centre: Vector2 = _to_frame(spr).affine_inverse() * Vector2.ZERO
	return (m.reach * _scale_of(spr)) + centre.distance_to(spr.global_position)

# Furthest painted point from the frame's middle (sprite_centre), world px
static func sprite_radius(spr: Sprite2D) -> float:
	var m := mask(spr)
	return 0.0 if m.is_empty() else m.reach * _scale_of(spr)

# The frame's middle, in world space
static func sprite_centre(spr: Sprite2D) -> Vector2:
	return _to_frame(spr).affine_inverse() * Vector2.ZERO

# ── Code-drawn pieces (HitPen.gd), in the drawing node's space at xf ──

# The body without its hairlines (HitPen.gd marks them): thin feelers,
# flagella, whiskers and hatching don't take or give contact hits; filled
# shapes and thick strokes (legs, jaws, tails, shells) do. Keeps everything
# when a drawing is all hairlines.
static func body_pieces(pieces: Array) -> Array:
	var out: Array = []
	for d in pieces:
		if d.size() < 4 or not d[3]:
			out.append(d)
	return out if not out.is_empty() else pieces

static func pieces_gap(pieces: Array, xf: Transform2D, p: Vector2, cap: float = INF) -> float:
	if pieces.is_empty():
		return INF
	var lp: Vector2 = xf.affine_inverse() * p
	var k: float = max(0.001, (xf.x.length() + xf.y.length()) * 0.5)
	var best: float = INF if cap == INF else cap / k
	for d in pieces:
		var g: float
		if d[0] is PackedVector2Array:
			if lp.distance_to(d[1]) - d[2] > best:
				continue
			if Geometry2D.is_point_in_polygon(lp, d[0]):
				return 0.0
			g = INF
			var n: int = d[0].size()
			for i in n:
				g = min(g, lp.distance_to(Geometry2D.get_closest_point_to_segment(lp, d[0][i], d[0][(i + 1) % n])))
		else:
			g = lp.distance_to(Geometry2D.get_closest_point_to_segment(lp, d[0], d[1])) - d[2]
			if g <= 0.0:
				return 0.0
		best = min(best, g)
	return best * k

static func pieces_gapper(pieces: Array, xf: Transform2D) -> Callable:
	return func(p: Vector2) -> float: return pieces_gap(pieces, xf, p)

# Sample circles along every piece: capsules as beads, polygons as their
# rim (and the inscribed circle about the centre)
static func pieces_samples(pieces: Array, xf: Transform2D, spacing: float = 5.0) -> Array:
	var out: Array = []
	var k: float = max(0.001, (xf.x.length() + xf.y.length()) * 0.5)
	var sp: float = spacing / k
	for d in pieces:
		if d[0] is PackedVector2Array:
			var pts: PackedVector2Array = d[0]
			var n := pts.size()
			var inner := INF
			for i in n:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % n]
				var steps: int = max(1, int(ceil(a.distance_to(b) / sp)))
				for s in steps:
					out.append([xf * a.lerp(b, float(s) / steps), sp * 0.5 * k])
				inner = min(inner, d[1].distance_to(Geometry2D.get_closest_point_to_segment(d[1], a, b)))
			if Geometry2D.is_point_in_polygon(d[1], pts) and inner > sp:
				out.append([xf * d[1], inner * k])
		else:
			var a: Vector2 = d[0]
			var b: Vector2 = d[1]
			var hw: float = d[2]
			var steps: int = max(1, int(ceil(a.distance_to(b) / max(hw, sp * 0.5))))
			for s in steps + 1:
				out.append([xf * a.lerp(b, float(s) / steps), hw * k])
	return out

static func pieces_reach(pieces: Array, xf: Transform2D, from: Vector2) -> float:
	var lp: Vector2 = xf.affine_inverse() * from
	var k: float = max(0.001, (xf.x.length() + xf.y.length()) * 0.5)
	var r := 0.0
	for d in pieces:
		if d[0] is PackedVector2Array:
			r = max(r, lp.distance_to(d[1]) + d[2])
		else:
			r = max(r, max(lp.distance_to(d[0]), lp.distance_to(d[1])) + d[2])
	return r * k

# ── Fewer samples ──

# One circle per grid cell of `cell` px, covering every sample in it
static func dedupe(samples: Array, cell: float = 4.0) -> Array:
	var grid := {}
	for sm in samples:
		var k := Vector2i(floori(sm[0].x / cell), floori(sm[0].y / cell))
		var c := (Vector2(k) + Vector2(0.5, 0.5)) * cell
		var r: float = c.distance_to(sm[0]) + sm[1]
		if r > grid.get(k, -1.0):
			grid[k] = r
	var out: Array = []
	for k in grid:
		out.append([(Vector2(k) + Vector2(0.5, 0.5)) * cell, grid[k]])
	return out

# Only the circles on the outside: a cell boxed in on all four sides by
# other cells is inside the drawing (deduped samples, same cell size)
static func outline_of(cells: Array, cell: float = 4.0) -> Array:
	var have := {}
	for sm in cells:
		have[Vector2i(floori(sm[0].x / cell), floori(sm[0].y / cell))] = true
	var out: Array = []
	for sm in cells:
		var k := Vector2i(floori(sm[0].x / cell), floori(sm[0].y / cell))
		if not (have.has(k + Vector2i.LEFT) and have.has(k + Vector2i.RIGHT) and have.has(k + Vector2i.UP) and have.has(k + Vector2i.DOWN)):
			out.append(sm)
	return out

# Callable(p) -> distance from p to the nearest sample circle, looked up in
# a bucket grid; exact up to `near` px, beyond that it answers `near`
static func samples_gapper(samples: Array, near: float = 40.0) -> Callable:
	var b := near
	var grid := {}
	for sm in samples:
		var k := Vector2i(floori(sm[0].x / b), floori(sm[0].y / b))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(sm)
		# A big circle also reaches into the buckets around it
		if sm[1] > b * 0.5:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx != 0 or dy != 0:
						var k2 := k + Vector2i(dx, dy)
						if not grid.has(k2):
							grid[k2] = []
						grid[k2].append(sm)
	return func(p: Vector2) -> float:
		var k := Vector2i(floori(p.x / b), floori(p.y / b))
		var best := near
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for sm in grid.get(k + Vector2i(dx, dy), []):
					var g: float = p.distance_to(sm[0]) - sm[1]
					if g < best:
						best = g
						if best <= 0.0:
							return 0.0
		return best

# ── Two drawings ──

# True when any sample circle comes within its radius of the other
# drawing; samples further than `bound` from `centre` are skipped
static func touches(samples: Array, gap: Callable, centre: Vector2, bound: float) -> bool:
	for s in samples:
		if s[0].distance_to(centre) - s[1] > bound:
			continue
		if gap.call(s[0]) <= s[1]:
			return true
	return false
