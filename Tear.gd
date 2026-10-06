# Tear.gd
extends Area2D

@export var speed: float = 680.0
@export var damage: float = 3.5
@export var lifetime: float = 0.85
@export var is_enemy_tear: bool = false

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

func _ready():
    add_to_group("tears")
    if is_enemy_tear:
        collision_layer = 16
        collision_mask = 1 + 4
        $Sprite2D.texture = load("res://assets/enemy_tear.png")
        if has_node("PointLight2D"):
            $PointLight2D.color = Color(1.0, 0.15, 0.3)
        if has_node("TrailParticles"):
            $TrailParticles.color = Color(1.0, 0.2, 0.3, 0.6)
    else:
        collision_layer = 8
        collision_mask = 2 + 4
        $Sprite2D.texture = load("res://assets/tear.png")
        if has_node("PointLight2D"):
            $PointLight2D.color = Color(0.0, 0.95, 1.0)
        if has_node("TrailParticles"):
            $TrailParticles.color = Color(0.0, 0.95, 1.0, 0.6)

    if velocity == Vector2.ZERO:
        velocity = direction.normalized() * speed
    
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
    position += velocity * delta
    $Sprite2D.rotation += 6.0 * delta
    
    if lifetime < 0.15:
        scale = Vector2.ONE * (lifetime / 0.15)
        
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
            destroy_tear()
        elif body.is_in_group("obstacles") or body.is_in_group("walls"):
            destroy_tear()

func destroy_tear():
    spawn_splash_particles()
    queue_free()

func spawn_splash_particles():
    var p = CPUParticles2D.new()
    p.position = global_position
    p.emitting = true
    p.one_shot = true
    p.explosiveness = 0.9
    p.amount = 8
    p.lifetime = 0.3
    p.spread = 180.0
    p.initial_velocity_min = 40.0
    p.initial_velocity_max = 90.0
    p.scale_amount_min = 2.0
    p.scale_amount_max = 4.0
    
    if is_enemy_tear:
        p.color = Color(1.0, 0.2, 0.35, 0.8)
    else:
        p.color = Color(0.0, 0.95, 1.0, 0.8)
        
    get_parent().add_child(p)
    var timer = get_tree().create_timer(0.35)
    timer.timeout.connect(func(): p.queue_free())
