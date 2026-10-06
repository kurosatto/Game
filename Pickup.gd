# Pickup.gd
extends Area2D

@export var pickup_type: String = "coin" # "coin", "heart", "heart_half", "key"

var player: Node2D = null
var magnet_range: float = 90.0

func _ready():
    add_to_group("pickups")
    body_entered.connect(_on_body_entered)
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
            # Optionally spawn small text / effect
            queue_free()
