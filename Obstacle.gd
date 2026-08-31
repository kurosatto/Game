# Obstacle.gd
extends StaticBody2D

func destroy_rock():
    # 10% chance to spawn a pickup on destruction (very standard in Isaac)
    if randf() < 0.1:
        var pickup_scene = load("res://Pickup.tscn")
        var p = pickup_scene.instantiate()
        p.position = global_position
        var roll = randf()
        if roll < 0.4:
            p.pickup_type = "coin"
        elif roll < 0.7:
            p.pickup_type = "heart"
        elif roll < 0.85:
            p.pickup_type = "bomb"
        else:
            p.pickup_type = "key"
        get_parent().call_deferred("add_child", p)
        
    queue_free()
