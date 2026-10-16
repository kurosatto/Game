# BiomassOrb.gd
# A glowing bit of prey that Enemy.gd scatters on death: one of the elements
# its body was built from (data/Biominerals.gd). It bursts outward, then
# streams into the player to be spent on the GROW screen.
extends Node2D

const ELEMENTS = preload("res://data/Biominerals.gd").ELEMENTS

var value: float = 0.5
var element: String = "P"
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var collected: bool = false
var player: Node2D = null

func _ready():
	z_index = 5
	velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(160.0, 340.0)
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float):
	age += delta
	if age < 0.3:
		# Burst out and slow down, so the kill reads before the pickup
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	elif player and is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length() < 34.0:
			collect()
			return
		var pull = max(500.0, (age - 0.3) * 2600.0)
		velocity = velocity.lerp(to_player.normalized() * pull, min(1.0, delta * 9.0))
	position += velocity * delta
	queue_redraw()

func collect():
	if collected:
		return
	collected = true
	if player and is_instance_valid(player) and player.has_method("add_element"):
		player.add_element(element, value)
		SoundManager.play_sfx("dna_pickup", 1.6 + randf_range(0.0, 0.25), -10.0)
	queue_free()

# Leaving the room before every orb arrives still counts what was eaten
func _exit_tree():
	if not collected and player and is_instance_valid(player) and player.is_inside_tree() \
			and player.has_method("add_element"):
		collected = true
		player.add_element(element, value)

func _draw():
	var pulse = 1.0 + 0.2 * sin(age * 18.0)
	var col: Color = ELEMENTS.get(element, ELEMENTS["P"]).color
	var r = 4.0 + 4.0 * clamp(value, 0.3, 1.5)
	draw_circle(Vector2.ZERO, r * 1.8 * pulse, Color(col.r, col.g, col.b, 0.25), true, -1.0, true)
	# A little crystal of the element
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2.RIGHT.rotated(TAU * i / 6.0 + age * 3.0) * r * pulse)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.5), 1.2, true)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.85), true, -1.0, true)
