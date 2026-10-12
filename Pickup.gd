# Pickup.gd
extends Area2D

@export var pickup_type: String = "coin" # "coin", "heart", "heart_half", "key"

var player: Node2D = null
var magnet_range: float = 90.0

func _ready():
    add_to_group("pickups")
    # Deferred: reacting can add/remove physics nodes, which Godot forbids mid physics step
    body_entered.connect(_on_body_entered, CONNECT_DEFERRED)
    call_deferred("setup_visuals")

func setup_visuals():
    var tex_path = "res://assets/pickup_coin.png"
    if pickup_type == "heart":
        tex_path = "res://assets/pickup_heart.png"
    elif pickup_type == "heart_half":
        tex_path = "res://assets/pickup_heart_half.png"

    elif pickup_type == "key":
        tex_path = "res://assets/pickup_key.png"
        
    $Sprite2D.texture = load(tex_path)

    # Pop in, then bob gently so pickups read as collectable
    var sprite = $Sprite2D
    sprite.scale = Vector2.ZERO
    var tw = create_tween()
    tw.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var bob = sprite.create_tween().set_loops()
    var phase = randf_range(0.0, 0.4)
    bob.tween_interval(phase)
    bob.tween_property(sprite, "position:y", -6.0, 0.7).set_trans(Tween.TRANS_SINE)
    bob.tween_property(sprite, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)

func sparkle_color() -> Color:
    match pickup_type:
        "heart", "heart_half":
            return Color(1.0, 0.35, 0.45)
        "key":
            return Color(1.0, 0.85, 0.3)
    return Color(0.3, 1.0, 0.85)

# Small one-shot burst where the pickup was collected
func spawn_collect_sparkle():
    var p = CPUParticles2D.new()
    p.global_position = global_position
    p.one_shot = true
    p.explosiveness = 0.9
    p.amount = 10
    p.lifetime = 0.45
    p.spread = 180.0
    p.gravity = Vector2(0, -40)
    p.initial_velocity_min = 70.0
    p.initial_velocity_max = 160.0
    p.scale_amount_min = 2.0
    p.scale_amount_max = 4.0
    var ramp = Gradient.new()
    var c = sparkle_color()
    ramp.set_color(0, Color(1, 1, 1, 1))
    ramp.add_point(0.3, c)
    ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
    p.color_ramp = ramp
    p.z_index = 5
    get_parent().add_child(p)
    p.emitting = true
    get_tree().create_timer(0.6).timeout.connect(p.queue_free)

func _physics_process(delta: float):
    # Attract to player if close (magnet effect)
    if not player:
        player = get_tree().get_first_node_in_group("player")
        
    if player and is_instance_valid(player):
        var dist = global_position.distance_to(player.global_position)
        if dist < magnet_range:
            # Heart checks if healing is needed
            if (pickup_type == "heart" or pickup_type == "heart_half") and player.health >= player.max_health:
                return # Don't attract if full health
                
            var dir = (player.global_position - global_position).normalized()
            var speed = (magnet_range - dist) * 4.0 + 80.0
            global_position += dir * speed * delta

func _on_body_entered(body: Node):
    if not is_instance_valid(body):
        return
    if body.is_in_group("player"):
        var collected = false
        
        if pickup_type == "coin":
            body.add_coin(1)
            collected = true
        elif pickup_type == "heart":
            if body.health < body.max_health:
                body.heal(2) # 1 Full Heart = 2 half hearts
                collected = true
        elif pickup_type == "heart_half":
            if body.health < body.max_health:
                body.heal(1) # Half Heart = 1 half heart
                collected = true
        elif pickup_type == "key":
            body.add_key(1)
            collected = true
            
        if collected:
            spawn_collect_sparkle()
            queue_free()
