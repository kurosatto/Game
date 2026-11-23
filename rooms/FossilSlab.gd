# FossilSlab.gd
# A slab of layered rock in the fossil bed (data/SpecialRooms.gd "dig").
# Attack it a few times (it's an obstacle with take_damage, so shots and
# bites both work) and it splits open on a fossil older than the era you're
# in, with a fact about it and a rare element the era's animals don't give.
extends StaticBody2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)
const HITS := 6

var floor_num: int = 1
var broken: bool = false
var on_broken: Callable = Callable()
var hits: int = 0
var time: float = 0.0
var shake: float = 0.0
var outline := PackedVector2Array()
var cracks: Array = []
var col: CollisionShape2D

func _ready():
	z_index = -1
	add_to_group("obstacles")
	collision_layer = 4
	collision_mask = 0
	col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 70.0
	col.shape = shape
	add_child(col)
	col.disabled = broken
	var rng = RandomNumberGenerator.new()
	rng.seed = floor_num * 3301
	for i in 14:
		var a = TAU * i / 14.0
		outline.append(Vector2.from_angle(a) * Vector2(120, 82) * rng.randf_range(0.88, 1.06))
	outline.append(outline[0])
	for i in HITS:
		var pts := PackedVector2Array([Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20))])
		var dir = Vector2.from_angle(rng.randf() * TAU)
		for k in 4:
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			pts.append(pts[-1] + dir * rng.randf_range(16, 30))
		cracks.append(pts)

func take_damage(_amount: float):
	if broken:
		return
	hits += 1
	shake = 1.0
	SoundManager.play_hit("shell")
	HitFX.pop(get_parent(), global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30)), Color(0.8, 0.74, 0.62), 14.0, 120.0, 0.25)
	if hits >= HITS:
		split_open()

func split_open():
	broken = true
	col.set_deferred("disabled", true)
	if on_broken.is_valid():
		on_broken.call()
	var fossil = SR.FOSSILS[clampi(floor_num, 1, 5)]
	var rare = SR.rare_element(floor_num)
	SR.spill(get_parent(), position, [rare, rare, "Ca"], 4.5, 6)
	SoundManager.play_sfx("level_up", 0.9, -4.0)
	HitFX.pop(get_parent(), global_position, Color(0.88, 0.8, 0.66), 40.0, 260.0, 0.45)
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("hud"):
		var el_name = preload("res://data/Biominerals.gd").ELEMENTS[rare].name
		main.hud.show_item_banner("FOSSIL: " + fossil.name.to_upper(), fossil.fact + "\nThe rock was rich in %s, rare in this era." % el_name.to_lower(), true)

func _process(delta: float):
	time += delta
	shake = max(0.0, shake - delta * 5.0)
	queue_redraw()

func _draw():
	var off = Vector2(sin(time * 60.0), cos(time * 47.0)) * 4.0 * shake
	draw_set_transform(off)
	if broken:
		# Two halves split apart, the fossil on the inner face
		for side in [-1.0, 1.0]:
			var half := PackedVector2Array()
			for p in outline:
				if p.x * side >= -4.0:
					half.append(Vector2(p.x * 1.05 + side * 26.0, p.y))
			if half.size() >= 3:
				draw_colored_polygon(half, Color(0.7, 0.64, 0.54, 0.6))
				half.append(half[0])
				draw_polyline(half, Color(INK, 0.6), 2.0, true)
		var slab := PackedVector2Array()
		for p in outline:
			slab.append(p * 0.78)
		draw_colored_polygon(slab, Color(0.86, 0.8, 0.68, 0.95))
		draw_polyline(slab, Color(INK, 0.8), 2.2, true)
		_draw_fossil(SR.FOSSILS[clampi(floor_num, 1, 5)].shape)
		return
	draw_colored_polygon(outline, Color(0.72, 0.66, 0.56, 0.97))
	draw_polyline(outline, Color(INK, 0.9), 2.8, true)
	# Bedding planes: the layers of the rock
	for k in range(-3, 4):
		var y = k * 18.0
		var w = 112.0 * sqrt(max(0.0, 1.0 - pow(y / 82.0, 2)))
		var pts := PackedVector2Array()
		for i in 9:
			var x = -w + 2.0 * w * i / 8.0
			pts.append(Vector2(x, y + sin(x * 0.05 + k) * 3.0))
		draw_polyline(pts, Color(INK, 0.3), 1.2, true)
	# A hint of what's inside: a curl peeping out at the edge
	draw_arc(Vector2(70, 30), 9.0, 0.5, 4.0, 10, Color(INK, 0.5), 1.4, true)
	for i in hits:
		draw_polyline(cracks[i], Color(INK, 0.9), 2.2, true)
	SR.draw_label(self, Vector2(0, -112), "HIT TO DIG" if hits == 0 else "%d MORE" % (HITS - hits), 24)

func _draw_fossil(shape: String):
	var c = Color(INK, 0.9)
	match shape:
		"coil":
			var pts := PackedVector2Array()
			for i in 90:
				var t = i / 89.0 * TAU * 3.2
				pts.append(Vector2.from_angle(t) * (6.0 + t * 3.0))
			draw_polyline(pts, c, 4.5, true)
			draw_polyline(pts, Color(0.95, 0.9, 0.8, 0.8), 1.4, true)
		"quilt":
			var oval := PackedVector2Array()
			for i in 33:
				oval.append(Vector2.from_angle(TAU * i / 32.0) * Vector2(52, 38))
			draw_polyline(oval, c, 2.4, true)
			draw_line(Vector2(-48, 0), Vector2(48, 0), c, 1.6, true)
			for i in range(-10, 11):
				var x = i * 4.6
				var h = 38.0 * sqrt(max(0.0, 1.0 - pow(x / 52.0, 2)))
				draw_line(Vector2(x, -h), Vector2(x, h), Color(INK, 0.6), 1.2, true)
		"trilobite":
			draw_arc(Vector2(0, -26), 30.0, PI, TAU, 18, c, 2.4, true)
			draw_line(Vector2(-30, -26), Vector2(30, -26), c, 2.0, true)
			draw_line(Vector2(-30, -26), Vector2(-40, 2), c, 2.0, true) # genal spines
			draw_line(Vector2(30, -26), Vector2(40, 2), c, 2.0, true)
			for i in 8:
				var y = -20.0 + i * 6.5
				var w = 24.0 - i * 1.8
				draw_line(Vector2(-w, y), Vector2(w, y), Color(INK, 0.75), 1.6, true)
			draw_line(Vector2(-7, -24), Vector2(-5, 30), c, 1.6, true)
			draw_line(Vector2(7, -24), Vector2(5, 30), c, 1.6, true)
			draw_circle(Vector2(-12, -36), 3.0, c)
			draw_circle(Vector2(12, -36), 3.0, c)
		"graptolite":
			for s in [-1.0, 1.0]:
				var a = Vector2(0, 30)
				var b = Vector2(s * 50, -36)
				draw_line(a, b, c, 2.2, true)
				for i in 9:
					var p = a.lerp(b, (i + 0.5) / 9.0)
					var n = (b - a).normalized().rotated(-PI / 2 * s)
					draw_line(p, p + n * 9.0 + (b - a).normalized() * 4.0, c, 1.6, true)
		"bark":
			for i in range(-3, 4):
				for j in range(-2, 3):
					var p = Vector2(i * 18.0 + (j % 2) * 9.0, j * 16.0)
					var d = PackedVector2Array([p + Vector2(0, -9), p + Vector2(7, 0), p + Vector2(0, 9), p + Vector2(-7, 0), p + Vector2(0, -9)])
					draw_polyline(d, Color(INK, 0.8), 1.5, true)
					draw_circle(p + Vector2(0, -2), 1.6, c)
