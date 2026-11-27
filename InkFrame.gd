# InkFrame.gd
# Hand-inked frames for the main menu, so its buttons and pages look drawn in
# the same field notebook as the rooms (kuro, 2026-11-27: the menu felt too
# different from the game). A frame is a slightly wobbly pen rule with a
# fine second rule inside it, little tick marks at the corners and a few
# hatch strokes along the lower right edge for shade.
#   InkFrame.draw_frame(canvas_item, rect, ink, seed)
extends RefCounted

# A point along a wobbly line from a to b; the wobble is fixed per seed so
# the frame doesn't shimmer when it redraws
static func _wobble_line(a: Vector2, b: Vector2, seed_v: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n = maxi(2, int(a.distance_to(b) / 18.0))
	var normal = (b - a).normalized().orthogonal()
	for i in n + 1:
		var t = i / float(n)
		var w = 0.0
		if i > 0 and i < n:
			w = sin(t * 9.0 + seed_v * 1.3) * 0.6 + sin(t * 23.0 + seed_v * 0.7) * 0.4
		pts.append(a.lerp(b, t) + normal * w * amp)
	return pts

static func _rule(ci: CanvasItem, r: Rect2, ink: Color, width: float, seed_v: int, amp: float, overshoot: float):
	# Four strokes that cross a little at the corners, as a pen does
	var o = overshoot
	var tl = r.position
	var tr = Vector2(r.end.x, r.position.y)
	var br = r.end
	var bl = Vector2(r.position.x, r.end.y)
	ci.draw_polyline(_wobble_line(tl + Vector2(-o, 0), tr + Vector2(o * 0.4, 0), seed_v, amp), ink, width, true)
	ci.draw_polyline(_wobble_line(tr + Vector2(0, -o * 0.4), br + Vector2(0, o), seed_v + 1, amp), ink, width, true)
	ci.draw_polyline(_wobble_line(br + Vector2(o, 0), bl + Vector2(-o * 0.4, 0), seed_v + 2, amp), ink, width, true)
	ci.draw_polyline(_wobble_line(bl + Vector2(0, o * 0.4), tl + Vector2(0, -o), seed_v + 3, amp), ink, width, true)

# weight 1 = a button, 1.4 = a page
static func draw_frame(ci: CanvasItem, r: Rect2, ink: Color, seed_v: int = 0, weight: float = 1.0, hatch: bool = true):
	var w = 2.2 * weight
	_rule(ci, r.grow(-1.0), ink, w, seed_v, 1.1 * weight, 5.0 * weight)
	var inner = r.grow(-5.0 * weight)
	if inner.size.x > 20 and inner.size.y > 20:
		_rule(ci, inner, Color(ink, ink.a * 0.5), 1.0, seed_v + 7, 0.7, 0.0)
	# corner ticks
	var t = 6.0 * weight
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var d = (r.get_center() - c).sign()
		ci.draw_line(c - d * 2.0, c - d * (2.0 + t), Color(ink, ink.a * 0.8), 1.2, true)
	# shade: short diagonal hatching just outside the lower and right edges
	if hatch:
		var shade = Color(ink, ink.a * 0.45)
		var gap = 7.0
		var x = r.position.x + 14.0
		while x < r.end.x + 2.0:
			var y = r.end.y + 2.5
			ci.draw_line(Vector2(x, y), Vector2(x - 4.0 * weight, y + 4.0 * weight), shade, 1.0, true)
			x += gap
		var yy = r.position.y + 12.0
		while yy < r.end.y:
			var xx = r.end.x + 2.5
			ci.draw_line(Vector2(xx, yy), Vector2(xx + 4.0 * weight, yy - 4.0 * weight), shade, 1.0, true)
			yy += gap

# A short pen flourish under the title: two rules and a little cell between
static func draw_flourish(ci: CanvasItem, centre: Vector2, half: float, ink: Color):
	var gap = 16.0
	ci.draw_polyline(_wobble_line(centre + Vector2(-half, 0), centre + Vector2(-gap, 0), 3, 0.8), ink, 2.0, true)
	ci.draw_polyline(_wobble_line(centre + Vector2(gap, 0), centre + Vector2(half, 0), 5, 0.8), ink, 2.0, true)
	ci.draw_arc(centre, 9.0, 0, TAU, 20, ink, 1.8, true)
	ci.draw_circle(centre + Vector2(1.5, -1.0), 3.0, ink)
	for k in 3:
		var a = -0.6 + k * 0.6
		ci.draw_line(centre + Vector2.from_angle(a + PI / 2) * 9.0, centre + Vector2.from_angle(a + PI / 2) * 15.0, ink, 1.2, true)
	for s in [-1.0, 1.0]:
		ci.draw_circle(centre + Vector2(s * (half + 6.0), 0), 2.2, ink)
