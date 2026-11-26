# Shading.gd
# Shared lighting for the code-drawn animals (the player forms in
# PlayerBody.gd and the era bosses in bosses/BossBase.gd). Every body part is
# shaded as a rounded volume lit from the top left of the screen: a soft
# diffuse falloff into cool shadow, a wet specular glint and a darker rim
# where the surface turns away, so parts read as solid, glossy bodies rather
# than flat cut-outs. Parts are drawn as vertex-coloured triangle meshes.
# Loaded with preload() where used, so it never depends on the editor's class cache
extends RefCounted

# Screen-space light: from the top left, above the water
const LIGHT := Vector3(-0.42, -0.62, 0.66)
const RINGS := [1.0, 0.86, 0.68, 0.46, 0.22]
const ACROSS := [-1.0, -0.7, -0.35, 0.0, 0.35, 0.7, 1.0]

# The light in the frame of something drawn rotated by `rot` on screen
static func light_for(rot: float) -> Vector3:
	var l2 = Vector2(LIGHT.x, LIGHT.y).rotated(-rot)
	return Vector3(l2.x, l2.y, LIGHT.z).normalized()

# Line colour: a deep shade of the part's own colour rather than flat black
static func ink(col: Color) -> Color:
	return Color(col.r * 0.22 + 0.03, col.g * 0.22 + 0.03, col.b * 0.26 + 0.05, 1.0)

static func lit(col: Color, n: Vector3, L: Vector3) -> Color:
	var d = n.dot(L)
	var diff = clamp(d * 0.5 + 0.5, 0.0, 1.0) # wrapped, soft terminator
	diff = diff * diff * (3.0 - 2.0 * diff)
	var shadow = Color(col.r * 0.42, col.g * 0.48, col.b * 0.62 + 0.04)
	var light = Color(min(col.r * 1.12 + 0.04, 1.0), min(col.g * 1.1 + 0.04, 1.0), min(col.b * 1.05 + 0.03, 1.0))
	var c = shadow.lerp(light, diff)
	var h = (L + Vector3(0, 0, 1)).normalized()
	var spec = pow(max(n.dot(h), 0.0), 28.0) * 0.55
	var rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 3.0) * 0.18
	return Color(min(c.r + spec - rim, 1.0), min(c.g + spec - rim, 1.0), min(c.b + spec - rim * 0.8, 1.0), col.a)

# ci: an InkBatch (one draw call per body), or a canvas item RID
static func _emit(ci, idx: PackedInt32Array, verts: PackedVector2Array, cols: PackedColorArray):
	if ci is RID:
		RenderingServer.canvas_item_add_triangle_array(ci, idx, verts, cols)
	else:
		ci.add_triangles(idx, verts, cols)

# The lighting of lit(), split so whole meshes can be shaded quickly: for a
# normal n, colour = base + span * diffuse(n.L) + specular(n.h) - rim(n.z)
static var _idx_poly := {} # index pattern of a dome with n outline points

static func _spec(nh: float) -> float:
	# pow(x, 28) is below 1/255 for x < 0.83: skip it there
	return pow(nh, 28.0) * 0.55 if nh > 0.8 else 0.0

# Polygon shaded as a dome over its outline (rings shrinking to the centre)
static func lit_poly(ci, pts: PackedVector2Array, col: Color, L: Vector3):
	var n := pts.size()
	if n < 3:
		return
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= n
	var h := (L + Vector3(0, 0, 1)).normalized()
	var sr := col.r * 0.42
	var sg := col.g * 0.48
	var sb := col.b * 0.62 + 0.04
	var dr: float = min(col.r * 1.12 + 0.04, 1.0) - sr
	var dg: float = min(col.g * 1.1 + 0.04, 1.0) - sg
	var db: float = min(col.b * 1.05 + 0.03, 1.0) - sb
	var nr := RINGS.size()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	verts.resize(nr * n + 1)
	cols.resize(nr * n + 1)
	for i in n:
		var d: Vector2 = pts[i] - c
		var dl := 0.0
		var dh := 0.0
		if d.length() > 0.001:
			var dn := d.normalized()
			dl = dn.x * L.x + dn.y * L.y
			dh = dn.x * h.x + dn.y * h.y
		for k in nr:
			var s: float = RINGS[k]
			var r: float = _RR[k]
			var z: float = _RZ[k]
			verts[k * n + i] = c + d * s
			var diff := clampf((r * dl + z * L.z) * 0.5 + 0.5, 0.0, 1.0)
			diff = diff * diff * (3.0 - 2.0 * diff)
			var e := _spec(r * dh + z * h.z)
			var rim: float = _RIM[k]
			cols[k * n + i] = Color(minf(sr + dr * diff + e - rim, 1.0), minf(sg + dg * diff + e - rim, 1.0), minf(sb + db * diff + e - rim * 0.8, 1.0), col.a)
	verts[nr * n] = c
	cols[nr * n] = lit(col, Vector3(0, 0, 1), L)
	var idx: PackedInt32Array = _idx_poly.get(n, PackedInt32Array())
	if idx.is_empty():
		for k in nr - 1:
			for i in n:
				var a = k * n + i
				var b = k * n + (i + 1) % n
				idx.append_array([a, b, b + n, a, b + n, a + n])
		var last = (nr - 1) * n
		var centre = nr * n
		for i in n:
			idx.append_array([last + i, last + (i + 1) % n, centre])
		_idx_poly[n] = idx
	_emit(ci, idx, verts, cols)

# Per ring: normal length across, height, and the rim darkening
const _RR := [0.94, 0.8084, 0.6392, 0.4324, 0.2068]
static var _RZ := []
static var _RIM := []
static var _AZ := []
static var _ARIM := []
static func _static_init():
	for r in _RR:
		var z := sqrt(max(0.0, 1.0 - r * r))
		_RZ.append(z)
		_RIM.append(pow(1.0 - clamp(z, 0.0, 1.0), 3.0) * 0.18)
	for u in ACROSS:
		var uu: float = u * 0.94
		var z := sqrt(1.0 - uu * uu)
		_AZ.append(z)
		_ARIM.append(pow(1.0 - clamp(z, 0.0, 1.0), 3.0) * 0.18)

static var _idx_tube := {}

# Long body shaded as a cylinder along its spine
static func lit_tube(ci, spine: Array, widths: Array, col: Color, L: Vector3):
	var n := spine.size()
	if n < 2:
		return
	var m := ACROSS.size()
	var h := (L + Vector3(0, 0, 1)).normalized()
	var sr := col.r * 0.42
	var sg := col.g * 0.48
	var sb := col.b * 0.62 + 0.04
	var dr: float = min(col.r * 1.12 + 0.04, 1.0) - sr
	var dg: float = min(col.g * 1.1 + 0.04, 1.0) - sg
	var db: float = min(col.b * 1.05 + 0.03, 1.0) - sb
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	verts.resize(n * m)
	cols.resize(n * m)
	var j := 0
	for i in n:
		var a: Vector2 = spine[max(i - 1, 0)]
		var b: Vector2 = spine[min(i + 1, n - 1)]
		var tn := (b - a).normalized()
		var nm := Vector2(-tn.y, tn.x)
		var p: Vector2 = spine[i]
		var wd: float = widths[i]
		var nl := nm.x * L.x + nm.y * L.y
		var nh := nm.x * h.x + nm.y * h.y
		for k in m:
			var u: float = ACROSS[k]
			var uu := u * 0.94
			var z: float = _AZ[k]
			verts[j] = p + nm * (wd * u)
			var diff := clampf((uu * nl + z * L.z) * 0.5 + 0.5, 0.0, 1.0)
			diff = diff * diff * (3.0 - 2.0 * diff)
			var e := _spec(uu * nh + z * h.z)
			var rim: float = _ARIM[k]
			cols[j] = Color(minf(sr + dr * diff + e - rim, 1.0), minf(sg + dg * diff + e - rim, 1.0), minf(sb + db * diff + e - rim * 0.8, 1.0), col.a)
			j += 1
	var idx: PackedInt32Array = _idx_tube.get(n, PackedInt32Array())
	if idx.is_empty():
		for i in n - 1:
			for jj in m - 1:
				var q = i * m + jj
				idx.append_array([q, q + 1, q + m + 1, q, q + m + 1, q + m])
		_idx_tube[n] = idx
	_emit(ci, idx, verts, cols)

# Round limbs drawn as strokes: a shadow along the side away from the light
# and a thin glint along the lit side
static func limb_shine(ci, pts: PackedVector2Array, w: float, col: Color, L: Vector3):
	if w < 1.6 or pts.size() < 2:
		return
	var l2 = Vector2(L.x, L.y).normalized()
	var dark := PackedVector2Array()
	var glint := PackedVector2Array()
	for i in pts.size():
		var a: Vector2 = pts[max(i - 1, 0)]
		var b: Vector2 = pts[min(i + 1, pts.size() - 1)]
		var tn = (b - a).normalized()
		var nm = Vector2(-tn.y, tn.x)
		var side = 1.0 if nm.dot(l2) > 0.0 else -1.0
		glint.append(pts[i] + nm * side * w * 0.22)
		dark.append(pts[i] - nm * side * w * 0.28)
	var g = lit(col, Vector3(l2.x * 0.5, l2.y * 0.5, 0.86), L)
	ci.draw_polyline(dark, lit(col, Vector3(-l2.x * 0.8, -l2.y * 0.8, 0.6), L), w * 0.32, true)
	ci.draw_polyline(glint, Color(g.r, g.g, g.b, 0.55), max(0.7, w * 0.14), true)
