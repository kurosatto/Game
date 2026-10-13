# BossHazard.gd
# Short-lived boss attacks that live on the floor after the boss moves on:
#  "ring"  a pressure wave that expands from a point; hurts where the band is
#  "zone"  a warning circle that bursts after a delay (slams, falling debris)
extends Node2D

const WARN = Color(1.0, 0.25, 0.2)

var kind: String = "ring"
var params: Dictionary = {}
var boss: Node = null
var age: float = 0.0
var done_hit: bool = false

func _ready():
	z_index = -1 if kind == "zone" else 0

func _physics_process(delta: float):
	age += delta
	queue_redraw()
	var player = get_tree().get_first_node_in_group("player")
	match kind:
		"ring":
			var r = ring_radius()
			if r > params.get("max_r", 600.0):
				queue_free()
				return
			if player and not done_hit:
				var d = player.global_position.distance_to(global_position)
				if abs(d - r) < params.get("width", 30.0) * 0.5 + 18.0:
					player.take_damage(params.get("dmg", 1))
					done_hit = true
		"zone":
			var delay = params.get("delay", 0.8)
			if age >= delay and not done_hit:
				done_hit = true
				if player and player.global_position.distance_to(global_position) < params.get("r", 80.0) + 20.0:
					player.take_damage(params.get("dmg", 1))
			if age > delay + 0.35:
				queue_free()

func ring_radius() -> float:
	return params.get("start_r", 20.0) + age * params.get("speed", 420.0)

func _draw():
	var col: Color = params.get("color", Color(0.7, 0.9, 1.0))
	match kind:
		"ring":
			var r = ring_radius()
			var fade = 1.0 - clamp(r / params.get("max_r", 600.0), 0.0, 1.0)
			var w = params.get("width", 30.0)
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(col.r, col.g, col.b, 0.35 * fade), w)
			draw_arc(Vector2.ZERO, r + w * 0.5, 0, TAU, 64, Color(1, 1, 1, 0.7 * fade), 2.0)
			draw_arc(Vector2.ZERO, r - w * 0.5, 0, TAU, 64, Color(col.r, col.g, col.b, 0.6 * fade), 2.0)
		"zone":
			var delay = params.get("delay", 0.8)
			var r = params.get("r", 80.0)
			if age < delay:
				var k = age / delay
				draw_circle(Vector2.ZERO, r, Color(WARN.r, WARN.g, WARN.b, 0.12 + 0.12 * k))
				draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(WARN.r, WARN.g, WARN.b, 0.7), 2.0)
				draw_circle(Vector2.ZERO, r * k, Color(WARN.r, WARN.g, WARN.b, 0.18))
			else:
				var k = (age - delay) / 0.35
				draw_circle(Vector2.ZERO, r * (1.0 + k * 0.2), Color(col.r, col.g, col.b, 0.55 * (1.0 - k)))
				# Cracks radiating from the impact
				for i in 7:
					var a = TAU * i / 7.0 + 0.4
					var p1 = Vector2.RIGHT.rotated(a) * r * 0.25
					var p2 = Vector2.RIGHT.rotated(a + 0.2) * r * (0.9 + 0.2 * k)
					draw_line(p1, p2, Color(0.1, 0.07, 0.05, 0.8 * (1.0 - k)), 3.0)
