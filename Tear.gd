# Tear.gd
extends Area2D

@export var speed: float = 380.0
@export var damage: float = 3.5
@export var lifetime: float = 0.8
@export var is_enemy_tear: bool = false
@export var slows_target: bool = false # Velvet worm / spider silk

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

func _ready():
    add_to_group("tears")
    if is_enemy_tear:
        collision_layer = 16
        collision_mask = 1 + 4 # Player (1) + Obstacles (4)
        $Sprite2D.texture = load("res://assets/enemy_tear.png")
        if has_node("PointLight2D"):
            $PointLight2D.color = Color(1.0, 0.2, 0.2)
    else:
        collision_layer = 8
        collision_mask = 2 + 4 # Enemies (2) + Obstacles (4)
        $Sprite2D.texture = load("res://assets/tear.png")
        if has_node("PointLight2D"):
            $PointLight2D.color = Color(0.2, 0.8, 1.0)

    if velocity == Vector2.ZERO:
        velocity = direction.normalized() * speed
    
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
    position += velocity * delta
    $Sprite2D.rotation += 6.0 * delta
    
    if lifetime < 0.2:
        scale = Vector2.ONE * (lifetime / 0.2)
        
    lifetime -= delta
    if lifetime <= 0:
        destroy_tear()

func _on_body_entered(body: Node):
    if is_enemy_tear:
        if body.is_in_group("player") and body.has_method("take_damage"):
            body.take_damage(damage)
            destroy_tear()
        elif body.is_in_group("obstacles") or body.is_in_group("walls"):
            destroy_tear()
    else:
        if body.is_in_group("enemies") and body.has_method("take_damage"):
            SoundManager.play_sfx("hit", 1.0)
            body.take_damage(damage)
            if slows_target and body.has_method("apply_slow"):
                body.apply_slow(1.5)
            destroy_tear()
        elif body.is_in_group("obstacles") or body.is_in_group("walls"):
            destroy_tear()

func destroy_tear():
    queue_free()
