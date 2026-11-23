# GlowCritter.gd
# A glowing animal in the dark cave (data/SpecialRooms.gd "glow"): a sea pen,
# a feathery soft coral rooted in the floor, or (Ordovician) a drifting comb
# jelly. Each lights a patch of the dark (VisionFog.gd reads the
# "fog_lights" group), and flares brighter when you come close, the way sea
# pens flash when something brushes them.
extends Node2D

const INK = Color(0.24, 0.15, 0.08)
const GLOW = Color(1.0, 0.93, 0.62)

var floor_num: int = 2
var drifter: bool = false
var seed_val: int = 0
var light_radius: float = 150.0
var player: Node2D = null
var time: float = 0.0
var flare: float = 0.0
var home: Vector2 = Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _ready():
	add_to_group("fog_lights")
	z_index = -1
	player = get_tree().get_first_node_in_group("player")
	rng.seed = seed_val
	time = rng.randf() * 10.0
	home = position

func _process(delta: float):
	time += delta
	if player and is_instance_valid(player) and player.global_position.distance_to(global_position) < 150.0:
		if flare < 0.3:
			SoundManager.play_sfx("dna_pickup", 2.2, -16.0)
		flare = 1.0
	flare = max(0.0, flare - delta * 0.5)
	if drifter:
		position = home + Vector2(sin(time * 0.31) * 140.0, sin(time * 0.23 + 1.0) * 80.0)
	light_radius = 140.0 + 18.0 * sin(time * 1.7) + 110.0 * flare
	queue_redraw()

func _draw():
	var g = 0.55 + 0.25 * sin(time * 1.7) + 0.45 * flare
	for k in 4:
		draw_circle(Vector2.ZERO, 26.0 + k * 18.0 + flare * 20.0, Color(GLOW, 0.13 * g))
	if drifter:
		_draw_comb_jelly(g)
	else:
		_draw_sea_pen(g)

func _draw_sea_pen(g: float):
	var sway = sin(time * 0.9) * 0.12
	var stalk = Vector2(0, -46).rotated(sway)
	draw_line(Vector2(0, 14), stalk, Color(INK, 0.9), 2.4, true)
	draw_circle(Vector2(0, 14), 5.0, Color(INK, 0.8))
	for i in 7:
		var t = 0.2 + i * 0.11
		var p = Vector2(0, 14).lerp(stalk, t)
		for s in [-1.0, 1.0]:
			var leaf = p + Vector2(s * (16.0 - i * 1.2), -6.0).rotated(sway)
			draw_line(p, leaf, Color(INK, 0.85), 1.6, true)
			draw_circle(leaf, 2.6, Color(GLOW, 0.5 + 0.5 * g))

func _draw_comb_jelly(g: float):
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(Vector2.from_angle(TAU * i / 20.0) * Vector2(18, 26))
	draw_colored_polygon(pts, Color(0.95, 0.92, 0.8, 0.35))
	pts.append(pts[0])
	draw_polyline(pts, Color(INK, 0.8), 1.6, true)
	# Eight comb rows, beating light along them
	for i in 8:
		var x = -14.0 + i * 4.0
		for k in 5:
			var y = -20.0 + k * 10.0
			var on = 0.5 + 0.5 * sin(time * 6.0 - k * 1.2 + i)
			draw_circle(Vector2(x, y * (1.0 - absf(x) / 30.0)), 1.6, Color(GLOW, (0.3 + 0.7 * on) * g))
