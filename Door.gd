# Door.gd
extends Area2D

signal door_entered(direction)

@export var direction: Vector2i = Vector2i.UP
@export var is_locked: bool = false

var is_open: bool = false
var trigger_cooldown: float = 0.6

@onready var light = $PointLight2D

func _ready():
	add_to_group("doors")
	body_entered.connect(_on_body_entered)
	update_visuals()

func _process(delta: float):
	if trigger_cooldown > 0:
		trigger_cooldown -= delta
		
	# Gentle pulsating light on doors
	if light and is_open:
		light.energy = 1.2 + sin(Time.get_ticks_msec() * 0.005) * 0.3

func open_door():
	if is_locked:
		return
	is_open = true
	update_visuals()

func close_door():
	is_open = false
	update_visuals()

func lock_door():
	is_locked = true
	is_open = false
	update_visuals()

func unlock_door():
	is_locked = false
	is_open = true
	SoundManager.play_sfx("door_open", 1.2)
	update_visuals()

func update_visuals():
	if not is_inside_tree():
		return
		
	if is_locked:
		$Sprite2D.texture = load("res://assets/door_locked.png")
		$Sprite2D.modulate = Color.WHITE
		$StaticBody2D/CollisionShape2D.set_deferred("disabled", false)
		if light:
			light.color = Color(1.0, 0.75, 0.1)
			light.energy = 1.0
	elif is_open:
		$Sprite2D.texture = load("res://assets/door.png")
		$Sprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
		$StaticBody2D/CollisionShape2D.set_deferred("disabled", true)
		if light:
			light.color = Color(0.0, 0.95, 1.0)
			light.energy = 1.5
	else: # Closed
		$Sprite2D.texture = load("res://assets/door_closed.png")
		$Sprite2D.modulate = Color.WHITE
		$StaticBody2D/CollisionShape2D.set_deferred("disabled", false)
		if light:
			light.color = Color(0.1, 0.4, 0.6)
			light.energy = 0.35

func blow_open():
	if is_locked or not is_open:
		is_locked = false
		is_open = true
		SoundManager.play_sfx("door_open", 0.9)
		update_visuals()

func _on_body_entered(body: Node):
	if trigger_cooldown > 0:
		return
		
	if body.is_in_group("player"):
		if is_locked:
			if body.keys > 0:
				body.add_key(-1)
				unlock_door()
				trigger_cooldown = 1.0
				door_entered.emit(direction)
		elif is_open:
			trigger_cooldown = 1.0
			door_entered.emit(direction)
