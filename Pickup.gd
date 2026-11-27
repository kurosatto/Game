# Pickup.gd
extends Area2D

@export var pickup_type: String = "coin" # "coin", "heart", "heart_half", "key"

var player: Node2D = null
var magnet_range: float = 90.0

func _ready():
    # There is no shop any more: a leftover coin (old layouts, old saves) is dropped
    if pickup_type == "coin":
        queue_free()
        return
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

    # Pop in (drop and bounce), then each kind idles in its own way: hearts
    # beat, keys swing on their ring, everything floats a little
    var sprite = $Sprite2D
    sprite.scale = Vector2.ZERO
    sprite.position.y = -26.0
    var tw = create_tween().set_parallel(true)
    tw.tween_property(sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(sprite, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    idle_t = randf_range(0.0, 3.0)
    tw.chain().tween_callback(func(): idling = true)

var idle_t: float = 0.0
var idling: bool = false

func _process(delta: float):
    if not idling or taken:
        return
    idle_t += delta
    var sprite = $Sprite2D
    sprite.position.y = -4.0 + sin(idle_t * 2.2) * 4.0
    match pickup_type:
        "heart", "heart_half":
            # Lub-dub: two quick beats, then a rest
            var b = fmod(idle_t, 1.1)
            var beat = exp(-pow((b - 0.08) / 0.05, 2.0)) * 0.14 + exp(-pow((b - 0.28) / 0.06, 2.0)) * 0.09
            sprite.scale = Vector2(1.0 + beat, 1.0 + beat * 0.8)
        "key":
            # Swings on its ring, with a glint now and then
            sprite.rotation = sin(idle_t * 1.7) * 0.22
            var glint = pow(max(0.0, sin(idle_t * 0.9)), 30.0)
            sprite.modulate = Color(1.0 + glint * 0.6, 1.0 + glint * 0.6, 1.0 + glint * 0.4)

# Collected: a copy of the pickup zips into the player and shrinks away
func fly_to_player(body: Node2D):
    var sprite = $Sprite2D
    var ghost = Sprite2D.new()
    ghost.texture = sprite.texture
    ghost.z_index = 6
    get_parent().add_child(ghost)
    ghost.global_position = sprite.global_position
    ghost.scale = sprite.scale * 1.25
    var tw = ghost.create_tween().set_parallel(true)
    tw.tween_method(func(t):
        if is_instance_valid(body):
            ghost.global_position = ghost.global_position.lerp(body.global_position, t)
        , 0.0, 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_property(ghost, "scale", Vector2.ONE * 0.25, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(ghost.queue_free)

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

var taken: bool = false

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
                
            # Already touching (e.g. a heart you stood on while at full
            # health, then got hurt): body_entered won't fire again
            if dist < 36.0:
                _on_body_entered(player)
                return
            var dir = (player.global_position - global_position).normalized()
            var speed = (magnet_range - dist) * 4.0 + 80.0
            global_position += dir * speed * delta

func _on_body_entered(body: Node):
    if not is_instance_valid(body):
        return
    if body.is_in_group("player") and not taken:
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
            taken = true
            spawn_collect_sparkle()
            fly_to_player(body)
            queue_free()
