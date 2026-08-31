# Enemy.gd
extends CharacterBody2D

signal enemy_died
signal boss_health_changed(current, max_value)

@export var enemy_type: String = "fly" # "fly" (Amoeba), "pacer" (Trilobite), "boss" (Nautiloid)

var max_health: float = 5.0
var health: float = 5.0
var speed: float = 160.0
var damage: int = 1

# AI State variables
var player: Node2D = null
var shoot_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var anim_timer: float = 0.0

# Boss specific states: "idle", "prep", "jump", "land", "cooldown"
var boss_state: String = "idle"
var boss_timer: float = 0.0
var boss_target_pos: Vector2 = Vector2.ZERO

# Hit flash
var hit_flash_timer: float = 0.0

# Preloads
var tear_scene = preload("res://Tear.tscn")

func _ready():
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    pick_random_wander()

func setup_enemy(floor_number: int):
    if enemy_type == "fly":
        # Amoeba Swarmer
        max_health = 4.0 + floor_number * 1.5
        speed = 170.0 + randf_range(-15, 25)
        damage = 1
        $Sprite2D.texture = load("res://assets/enemy_fly.png")
        $CollisionShape2D.shape.radius = 26.0
    elif enemy_type == "pacer":
        # Proto-Trilobite Crawler
        max_health = 7.0 + floor_number * 2.0
        speed = 105.0 + randf_range(-10, 10)
        damage = 1
        $Sprite2D.texture = load("res://assets/enemy_gusha.png")
        $CollisionShape2D.shape.radius = 34.0
        shoot_timer = randf_range(1.2, 2.2)
    elif enemy_type == "boss":
        # Ancient Apex Nautiloid
        max_health = 80.0 + floor_number * 30.0
        speed = 120.0
        damage = 2
        $Sprite2D.texture = load("res://assets/boss.png")
        $CollisionShape2D.shape.radius = 72.0
        boss_state = "idle"
        boss_timer = 1.0
        
    health = max_health
    
    if enemy_type == "boss":
        call_deferred("emit_boss_health")

func emit_boss_health():
    boss_health_changed.emit(health, max_health)

func pick_random_wander():
    var angles = [0, PI/2, PI, 3*PI/2, PI/4, 3*PI/4, 5*PI/4, 7*PI/4]
    var angle = angles.pick_random()
    wander_dir = Vector2.RIGHT.rotated(angle)
    wander_timer = randf_range(1.0, 2.0)

func _physics_process(delta: float):
    anim_timer += delta
    
    if hit_flash_timer > 0:
        hit_flash_timer -= delta
        $Sprite2D.modulate = Color(3.0, 1.0, 1.0, 1.0)
    else:
        $Sprite2D.modulate = Color.WHITE

    if not player or not is_instance_valid(player):
        return
        
    if enemy_type == "fly":
        var dir = (player.global_position - global_position).normalized()
        velocity = dir * speed
        move_and_slide()
        
        var sx = 1.0 + sin(anim_timer * 8.0) * 0.15
        var sy = 1.0 - sin(anim_timer * 8.0) * 0.15
        $Sprite2D.scale = Vector2(sx, sy)
        
    elif enemy_type == "pacer":
        wander_timer -= delta
        if wander_timer <= 0:
            pick_random_wander()
            
        velocity = wander_dir * speed
        if move_and_slide():
            pick_random_wander()
            
        $Sprite2D.rotation = wander_dir.angle() - PI/2
        
        shoot_timer -= delta
        if shoot_timer <= 0:
            shoot_at_player()
            shoot_timer = randf_range(1.5, 2.5)
            
    elif enemy_type == "boss":
        process_boss_ai(delta)
        
    check_contact_damage()

func check_contact_damage():
    for i in get_slide_collision_count():
        var collision = get_slide_collision(i)
        var collider = collision.get_collider()
        if collider.is_in_group("player") and boss_state != "jump":
            collider.take_damage(damage)

func shoot_at_player():
    if not player:
        return
    var dir = (player.global_position - global_position).normalized()
    var tear = tear_scene.instantiate()
    tear.position = global_position
    tear.direction = dir
    tear.is_enemy_tear = true
    tear.damage = 1
    tear.speed = 460.0
    get_parent().add_child(tear)
    
    SoundManager.play_sfx("shoot", 0.7)

func process_boss_ai(delta: float):
    boss_timer -= delta
    
    if boss_state == "idle":
        var dir = (player.global_position - global_position).normalized()
        velocity = dir * speed * 0.5
        move_and_slide()
        
        var s = 1.0 + sin(anim_timer * 3.0) * 0.06
        $Sprite2D.scale = Vector2(s, s)
        
        if boss_timer <= 0:
            boss_state = "prep"
            boss_timer = 0.6
            velocity = Vector2.ZERO
            SoundManager.play_sfx("boss_roar", 1.0)
            
    elif boss_state == "prep":
        $Sprite2D.position = Vector2(randf_range(-6, 6), randf_range(-6, 6))
        $Sprite2D.scale = Vector2(0.85, 1.25)
        
        if boss_timer <= 0:
            $Sprite2D.position = Vector2.ZERO
            boss_state = "jump"
            boss_timer = 0.8
            boss_target_pos = player.global_position
            set_collision_mask_value(3, false)
            
    elif boss_state == "jump":
        var diff = boss_target_pos - global_position
        var step = diff.normalized() * speed * 4.0
        if step.length() * delta >= diff.length():
            global_position = boss_target_pos
        else:
            global_position += step * delta
            
        var t = boss_timer / 0.8
        var height_scale = 1.0 + sin(t * PI) * 0.5
        $Sprite2D.scale = Vector2(height_scale, height_scale)
        
        if boss_timer <= 0:
            $Sprite2D.scale = Vector2.ONE
            boss_state = "land"
            boss_timer = 0.3
            velocity = Vector2.ZERO
            set_collision_mask_value(3, true)
            
            SoundManager.play_sfx("explosion", 1.2)
            fire_radial_tears()
            
            var main = get_tree().get_first_node_in_group("main")
            if main and main.has_method("shake_camera"):
                main.shake_camera(14.0)
                
    elif boss_state == "land":
        $Sprite2D.position = Vector2(randf_range(-4, 4), randf_range(-4, 4))
        $Sprite2D.scale = Vector2(1.3, 0.7)
        if boss_timer <= 0:
            $Sprite2D.position = Vector2.ZERO
            $Sprite2D.scale = Vector2.ONE
            boss_state = "cooldown"
            boss_timer = 1.2
            
    elif boss_state == "cooldown":
        if boss_timer <= 0:
            boss_state = "idle"
            boss_timer = randf_range(1.0, 2.0)

func fire_radial_tears():
    var num_tears = 12
    for i in range(num_tears):
        var angle = (i * 2 * PI) / num_tears
        var dir = Vector2.RIGHT.rotated(angle)
        
        var tear = tear_scene.instantiate()
        tear.position = global_position
        tear.direction = dir
        tear.is_enemy_tear = true
        tear.damage = 1
        tear.speed = 420.0
        get_parent().add_child(tear)

func take_damage(amount: float):
    health = max(0.0, health - amount)
    hit_flash_timer = 0.15
    
    if enemy_type == "boss":
        boss_health_changed.emit(health, max_health)
        
    if health <= 0:
        die()

func die():
    SoundManager.play_sfx("enemy_die", 1.0 if enemy_type != "boss" else 0.6)
    enemy_died.emit()
    queue_free()
