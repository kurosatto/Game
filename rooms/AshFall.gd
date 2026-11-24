# AshFall.gd
# The sky of the Great Dying (data/Endgame.gd), over every room of the
# finale floor. On land, flecks of volcanic ash from the Siberian Traps drift
# down and settle; at sea, "marine snow" of dead plankton sinks through the
# water. Drawn in ink like the rest, a few dozen flecks, cheap on phones.
extends Node2D

const INK = Color(0.24, 0.15, 0.08)
const COUNT := 70

var sea: bool = false
var flecks: Array = [] # [pos, speed, size, phase]
var time: float = 0.0

func _ready():
	z_index = 40
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in COUNT:
		flecks.append([Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080)),
			rng.randf_range(22.0, 60.0), rng.randf_range(1.5, 4.0), rng.randf() * TAU])

func _process(delta: float):
	time += delta
	for f in flecks:
		var p: Vector2 = f[0]
		p.y += f[1] * delta
		p.x += sin(time * 0.7 + f[3]) * (14.0 if sea else 26.0) * delta + (0.0 if sea else 9.0 * delta)
		if p.y > 1090.0:
			p.y = -10.0
			p.x = randf_range(0, 1920)
		if p.x > 1930.0:
			p.x = -10.0
		f[0] = p
	queue_redraw()

func _draw():
	# A faint red-brown haze over everything
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.45, 0.18, 0.08, 0.07) if not sea else Color(0.2, 0.25, 0.12, 0.08))
	for f in flecks:
		var a = 0.35 + 0.25 * sin(time * 1.3 + f[3])
		if sea:
			# Soft clumps of dead plankton
			draw_circle(f[0], f[2], Color(0.9, 0.88, 0.78, a * 0.8))
			draw_arc(f[0], f[2], 0, TAU, 8, Color(INK, a * 0.5), 1.0)
		else:
			# Torn grey flakes of ash
			var r: float = f[2]
			var rot = time * 0.8 + f[3]
			draw_line(f[0] - Vector2(r, 0).rotated(rot), f[0] + Vector2(r, 0).rotated(rot), Color(0.25, 0.22, 0.2, a), r * 0.7)
