# BiomassOrb.gd
# A glowing bit of prey that Enemy.gd scatters on death. It bursts outward,
# then streams into the player and fills the biomass (adaptation) bar.
extends Node2D

const COLOR = Color(0.45, 1.0, 0.6)

var value: float = 0.5
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
	if player and is_instance_valid(player) and player.has_method("add_biomass"):
		player.add_biomass(value)
		SoundManager.play_sfx("dna_pickup", 1.6 + randf_range(0.0, 0.25), -10.0)
	queue_free()

# Leaving the room before every orb arrives still counts what was eaten
func _exit_tree():
	if not collected and player and is_instance_valid(player) and player.is_inside_tree() \
			and player.has_method("add_biomass"):
		collected = true
		player.add_biomass(value)

func _draw():
	var pulse = 1.0 + 0.2 * sin(age * 18.0)
	draw_circle(Vector2.ZERO, 11.0 * pulse, Color(COLOR.r, COLOR.g, COLOR.b, 0.25))
	draw_circle(Vector2.ZERO, 6.0 * pulse, COLOR)
	draw_circle(Vector2(-1.5, -1.5), 2.5, Color(1, 1, 1, 0.9))
