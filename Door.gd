# Door.gd
extends Area2D

signal door_entered(direction)

@export var direction: Vector2i = Vector2i.UP
@export var is_locked: bool = false

var is_open: bool = false
var trigger_cooldown: float = 0.6
var hint_cooldown: float = 0.0
var key_badge: Node2D = null

@onready var light = $PointLight2D

func _ready():
	add_to_group("doors")
	_build_key_badge()
	# Deferred: reacting can add/remove physics nodes, which Godot forbids mid physics step
	body_entered.connect(_on_body_entered, CONNECT_DEFERRED)
	update_visuals()

func _process(delta: float):
	if hint_cooldown > 0:
		hint_cooldown -= delta
	elif not is_open and not is_locked:
		# Bumping a shut door: say why it is shut
		for body in get_overlapping_bodies():
			if body.is_in_group("player"):
				_show_hint("DOOR SHUT", "Defeat every creature in this room to open the doors")
				break
	if trigger_cooldown > 0:
		trigger_cooldown -= delta
	elif is_open or is_locked:
		# body_entered only fires on first contact: if the player was already
		# standing in the doorway when it opened (or during the cooldown),
		# let them through now instead of making them step out and back in
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and (is_open or body.keys > 0):
				_on_body_entered(body)
				break
		
	if key_badge:
		key_badge.visible = is_locked
		if is_locked:
			# Bob just inside the doorway, upright whatever wall it is on
			key_badge.global_rotation = 0.0
			# Local +y points into the room for every door rotation
			key_badge.position = Vector2(0, 150 + sin(Time.get_ticks_msec() * 0.004) * 6)
			var has_key = _player_keys() > 0
			key_badge.get_node("Label").text = "USE KEY" if has_key else "NEED KEY"
			key_badge.modulate = Color(0.6, 1.0, 0.6) if has_key else Color.WHITE

	# Gentle pulsating light on doors
	if light and is_open:
		light.energy = 1.2 + sin(Time.get_ticks_msec() * 0.005) * 0.3

func open_door():
	if is_locked:
		return
	var was_open = is_open
	is_open = true
	update_visuals()
	if not was_open and is_inside_tree():
		# Pop and glow so a newly opened exit catches the eye
		var sprite = $Sprite2D
		sprite.scale = Vector2.ONE * 1.3
		var tw = create_tween()
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if light:
			light.energy = 3.0

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
	if not is_instance_valid(body):
		return
	if trigger_cooldown > 0:
		return
		
	if body.is_in_group("player"):
		if is_locked and body.keys <= 0:
			_show_hint("LOCKED", "A key lies in one of this floor's other rooms")
			trigger_cooldown = 2.0
			return
		if is_locked:
			if body.keys > 0:
				body.add_key(-1)
				unlock_door()
				trigger_cooldown = 1.0
				door_entered.emit(direction)
		elif is_open:
			trigger_cooldown = 1.0
			door_entered.emit(direction)

func _show_hint(title: String, desc: String):
	if hint_cooldown > 0:
		return
	hint_cooldown = 3.0
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("display_item_banner"):
		main.display_item_banner(title, desc)

func _player_keys() -> int:
	var p = get_tree().get_first_node_in_group("player")
	return p.keys if p else 0

# Key icon and caption over locked doors, so it is clear what opens them
func _build_key_badge():
	key_badge = Node2D.new()
	key_badge.z_index = 5
	key_badge.visible = false
	var icon = Sprite2D.new()
	icon.texture = load("res://assets/pickup_key.png")
	var tex_size = icon.texture.get_size()
	icon.scale = Vector2.ONE * (56.0 / max(tex_size.x, tex_size.y))
	key_badge.add_child(icon)
	var label = Label.new()
	label.name = "Label"
	label.text = "NEED KEY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 30)
	label.position = Vector2(-80, 20)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	key_badge.add_child(label)
	add_child(key_badge)
