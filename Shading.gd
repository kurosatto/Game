# Shading.gd
# Shared lighting for the code-drawn animals (the player forms in
# PlayerBody.gd and the era bosses in bosses/BossBase.gd). Every body part is
# shaded as a rounded volume lit from the top left of the screen: a soft
# diffuse falloff into cool shadow, a wet specular glint and a darker rim
# where the surface turns away, so parts read as solid, glossy bodies rather
# than flat cut-outs. Parts are drawn as vertex-coloured triangle meshes.
class_name Shading
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

# Polygon shaded as a dome over its outline (rings shrinking to the centre)
static func lit_poly(ci: RID, pts: PackedVector2Array, col: Color, L: Vector3):
	var n = pts.size()
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= n
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	for s in RINGS:
		var r = s * 0.94
		var z = sqrt(max(0.0, 1.0 - r * r))
		for q in pts:
			var d: Vector2 = q - c
			var dir = d.normalized() if d.length() > 0.001 else Vector2.ZERO
			verts.append(c + d * s)
			cols.append(lit(col, Vector3(dir.x * r, dir.y * r, z), L))
	verts.append(c)
	cols.append(lit(col, Vector3(0, 0, 1), L))
	var idx := PackedInt32Array()
	for k in RINGS.size() - 1:
		for i in n:
			var a = k * n + i
			var b = k * n + (i + 1) % n
			idx.append_array([a, b, b + n, a, b + n, a + n])
	var last = (RINGS.size() - 1) * n
	var centre = verts.size() - 1
	for i in n:
		idx.append_array([last + i, last + (i + 1) % n, centre])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, verts, cols)

# Long body shaded as a cylinder along its spine
static func lit_tube(ci: RID, spine: Array, widths: Array, col: Color, L: Vector3):
	var n = spine.size()
	if n < 2:
		return
	var m = ACROSS.size()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var a: Vector2 = spine[max(i - 1, 0)]
		var b: Vector2 = spine[min(i + 1, n - 1)]
		var tn = (b - a).normalized()
		var nm = Vector2(-tn.y, tn.x)
		for u in ACROSS:
			var uu = u * 0.94
			verts.append(spine[i] + nm * widths[i] * u)
			cols.append(lit(col, Vector3(nm.x * uu, nm.y * uu, sqrt(1.0 - uu * uu)), L))
	var idx := PackedInt32Array()
	for i in n - 1:
		for j in m - 1:
			var a = i * m + j
			idx.append_array([a, a + 1, a + m + 1, a, a + m + 1, a + m])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, verts, cols)

# Round limbs drawn as strokes: a shadow along the side away from the light
# and a thin glint along the lit side
static func limb_shine(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, L: Vector3):
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
