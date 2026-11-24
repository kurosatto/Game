# FilterFan.gd
# The crinoid filter fan (Player.filter_fan): while attack is held the
# feathery arms stand up in a fan toward the aim, each arm a feather of
# pinnules swaying in the current. It shows exactly the ground it covers, so
# you can see what will be caught. Things caught in it make the arms close
# in and quiver. Drawn in dark ink over what it holds.
extends Node2D

const ARMS := 10
var player: Node2D = null
var caught: int = 0
var time: float = 0.0
var shown: float = 0.0

func _ready():
	# Over the prey it has caught, which it wraps
	z_index = 2
	z_as_relative = true

func _process(delta: float):
	time += delta
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	var want = 1.0 if player.filter_hold > 0.0 else 0.0
	shown = move_toward(shown, want, delta * (8.0 if want > 0.0 else 5.0))
	if shown <= 0.0 and player.filter_open <= 0.0:
		caught = 0
	queue_redraw()

func _draw():
	if shown <= 0.01:
		return
	var reach: float = player.filter_reach() * (0.55 + 0.45 * shown)
	var half: float = player.filter_half_arc() * shown
	var base: float = player.filter_dir.angle()
	# Ink-dark always: pale lines vanish into the paper of the ink styles
	var ink = Color(0.3, 0.13, 0.12, 0.95 * shown)
	var soft = Color(0.3, 0.13, 0.12, 0.13 * shown)
	# The covered ground, a faint wash so the reach can be read
	var pts = PackedVector2Array([Vector2.ZERO])
	for i in 17:
		pts.append(Vector2.from_angle(base - half + 2.0 * half * i / 16.0) * reach)
	draw_colored_polygon(pts, soft)
	var quiver = 0.05 if caught > 0 else 0.0
	for i in ARMS:
		var f = (float(i) + 0.5) / ARMS
		var a = base - half + 2.0 * half * f + sin(time * 2.2 + i * 1.3) * 0.05 + sin(time * 30.0 + i) * quiver
		var arm_len = reach * (0.86 + 0.1 * sin(i * 2.7))
		# Each arm curls a little at the tip
		var arm = PackedVector2Array()
		for k in 9:
			var u = k / 8.0
			var bend = sin(u * PI * 0.5) * 0.22 * (1.0 if i % 2 else -1.0) * u
			arm.append(Vector2.from_angle(a + bend) * arm_len * u)
		draw_polyline(arm, ink, 4.0, true)
		# Pinnules: short side branches down both edges, the feather
		for k in range(2, 9):
			var p = arm[k]
			var d = (arm[k] - arm[k - 1]).normalized()
			var pl = 13.0 * (1.0 - k / 10.0) + 4.0
			for s in [-1.0, 1.0]:
				var tip = p + d.rotated(s * 1.0) * pl - d * 2.0
				draw_line(p, tip, Color(ink, ink.a * 0.85), 2.2, true)
