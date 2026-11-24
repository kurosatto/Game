# WorldSign.gd
# The ink picture over each trapdoor when an amphibious form chooses its
# next world (Room.spawn_trapdoor, data/Worlds.gd): waves and a fish for the
# sea, a fern and footprints for the land. Pictures only, no words.
extends Node2D

const INK = Color(0.24, 0.15, 0.08)
const PAPER = Color(0.95, 0.9, 0.78)
const SEA = Color(0.35, 0.62, 0.78)
const LAND = Color(0.45, 0.6, 0.28)

var world: String = "sea"
var time: float = 0.0

func _process(delta: float):
	time += delta
	queue_redraw()

func _draw():
	var bob = sin(time * 2.2) * 5.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	# A torn paper slip
	var slip := PackedVector2Array()
	for i in 20:
		var a = TAU * i / 20.0
		var r = 1.0 + 0.04 * sin(i * 2.7)
		slip.append(Vector2(cos(a) * 62.0, sin(a) * 50.0) * r)
	draw_colored_polygon(slip, Color(PAPER, 0.9))
	slip.append(slip[0])
	draw_polyline(slip, Color(INK, 0.8), 2.5, true)
	if world == "sea":
		_sea()
	else:
		_land()
	# Pointer down to the trapdoor
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 48), Vector2(10, 48), Vector2(0, 64)]), Color(INK, 0.8))

func _sea():
	# Three rows of waves
	for row in 3:
		var y = 14.0 + row * 13.0
		var pts := PackedVector2Array()
		for i in 25:
			var x = -46.0 + i * 92.0 / 24.0
			pts.append(Vector2(x, y + sin(x * 0.18 + time * 3.0 + row) * 4.0))
		draw_polyline(pts, Color(SEA, 0.9), 3.0 - row * 0.5, true)
	# A fish
	var c = Vector2(sin(time * 1.4) * 8.0, -14.0)
	var body := PackedVector2Array()
	for i in 16:
		var a = TAU * i / 16.0
		body.append(c + Vector2(cos(a) * 22.0, sin(a) * 10.0))
	draw_colored_polygon(body, Color(SEA, 0.85))
	body.append(body[0])
	draw_polyline(body, INK, 2.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 0), c + Vector2(-34, -10), c + Vector2(-34, 10)]), INK)
	draw_circle(c + Vector2(12, -2), 2.5, INK)

func _land():
	# Ground line with three-toed footprints walking off
	draw_line(Vector2(-48, 30), Vector2(48, 30), Color(INK, 0.7), 2.0, true)
	for k in 3:
		var p = Vector2(-30.0 + k * 22.0, 22.0 - (k % 2) * 8.0)
		draw_circle(p, 3.5, Color(INK, 0.85))
		for t in 3:
			draw_line(p, p + Vector2.from_angle(-PI * 0.5 + (t - 1) * 0.5) * 7.0, Color(INK, 0.85), 2.0, true)
	# A fern frond, stirring
	var base = Vector2(20, 26)
	var sway = sin(time * 1.6) * 0.12
	var tip = base + Vector2.UP.rotated(-0.35 + sway) * 62.0
	draw_line(base, tip, INK, 2.5, true)
	for i in 9:
		var f = (i + 1) / 10.0
		var p = base.lerp(tip, f)
		var w = 18.0 * sin(f * PI) * (1.0 - f * 0.3)
		var dir = (tip - base).normalized()
		for s in [-1.0, 1.0]:
			var leaf = p + dir.rotated(s * 1.1) * w
			draw_line(p, leaf, Color(LAND, 0.95), 3.0, true)
