# Bomb.gd
extends Node2D

@export var fuse_time: float = 1.5
@export var explosion_radius: float = 95.0
@export var damage: float = 25.0

var elapsed: float = 0.0
var exploded: bool = false

func _ready():
    add_to_group("bombs")
    $ExplosionVisual.visible = false
    $ExplosionArea/CollisionShape2D.shape.radius = explosion_radius

func _process(delta: float):
    if exploded:
        return
        
    elapsed += delta
    var time_left = fuse_time - elapsed
    if time_left <= 0:
        explode()
        return
        
    # Organic pulsing fuse rate
    var flash_speed = 6.0
    if time_left < 0.5:
        flash_speed = 22.0
    elif time_left < 1.0:
        flash_speed = 12.0
        
    var flash = sin(elapsed * flash_speed * PI) > 0
    if flash:
        $Sprite2D.modulate = Color(2.5, 1.2, 0.8, 1.0)
    else:
        $Sprite2D.modulate = Color.WHITE

func explode():
    exploded = true
    $Sprite2D.visible = false
    
    SoundManager.play_sfx("explosion", 1.0)
    
    # Screen shake
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(12.0)
    
    $ExplosionVisual.visible = true
    $ExplosionVisual.scale = Vector2.ZERO
    $ExplosionVisual.modulate = Color(0.2, 1.8, 2.0, 1.0) # Bioluminescent plasma explosion
    
    var tween = create_tween()
    var target_scale = explosion_radius / 8.0
    tween.tween_property($ExplosionVisual, "scale", Vector2(target_scale, target_scale), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property($ExplosionVisual, "modulate:a", 0.0, 0.2).set_delay(0.1)
    
    var bodies = $ExplosionArea.get_overlapping_bodies()
    for body in bodies:
        if body.is_in_group("player") and body.has_method("take_damage"):
            body.take_damage(2)
        elif body.is_in_group("enemies") and body.has_method("take_damage"):
            body.take_damage(damage)
        elif body.is_in_group("obstacles"):
            if body.has_method("destroy_rock"):
                body.destroy_rock()
            else:
                body.queue_free()
                
    var areas = $ExplosionArea.get_overlapping_areas()
    for area in areas:
        if area.is_in_group("doors") and area.has_method("blow_open"):
            area.blow_open()

    await tween.finished
    queue_free()
