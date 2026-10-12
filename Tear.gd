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
        add_to_group("enemy_tears")
        collision_layer = 16
        collision_mask = 1 + 4
        $Sprite2D.texture = load("res://assets/enemy_tear.png")
        $Sprite2D.hframes = 1
        if has_node("PointLight2D"):
            $PointLight2D.color = Color(1.0, 0.15, 0.3)
        if has_node("TrailParticles"):
            $TrailParticles.color = Color(1.0, 0.2, 0.3, 0.6)
    else:
        collision_layer = 8
        collision_mask = 2 + 4
        $Sprite2D.texture = load("res://assets/tear_sheet.png")
        $Sprite2D.hframes = 3
        if has_node("PointLight2D"):
            $PointLight2D.color = Color(0.0, 0.95, 1.0)
            $PointLight2D.energy = 1.3
        if has_node("TrailParticles"):
            $TrailParticles.color = Color(0.0, 0.95, 1.0, 0.6)

    if velocity == Vector2.ZERO:
        velocity = direction.normalized() * speed
    
    # Deferred: reacting can add/remove physics nodes, which Godot forbids mid physics step
    body_entered.connect(_on_body_entered, CONNECT_DEFERRED)

func _physics_process(delta: float):
    if is_homing and not is_enemy_tear:
        var enemies = get_tree().get_nodes_in_group("enemies")
        var closest: Node2D = null
        var closest_dist: float = 420.0
        for e in enemies:
            if is_instance_valid(e):
                var d = global_position.distance_to(e.global_position)
                if d < closest_dist:
                    closest_dist = d
                    closest = e
        if closest:
            var target_dir = (closest.global_position - global_position).normalized()
            velocity = velocity.lerp(target_dir * speed, delta * 7.5)

    position += velocity * delta
    $Sprite2D.rotation += 8.0 * delta
    if not is_enemy_tear and $Sprite2D.hframes > 1:
        $Sprite2D.frame = int(fmod(lifetime * 14.0, 3.0))
        
    if is_boomerang:
        if lifetime < initial_lifetime * 0.55:
            var p_node = get_tree().get_first_node_in_group("player")
            if p_node and is_instance_valid(p_node):
                var to_p = (p_node.global_position - global_position).normalized()
                velocity = velocity.lerp(to_p * speed * 1.3, delta * 9.0)

    if lifetime < 0.15:
        scale = Vector2.ONE * (lifetime / 0.15)
        
    lifetime -= delta
    if lifetime <= 0:
        if is_explosive:
            trigger_explosion()
        destroy_tear()

@export var is_electric: bool = false
@export var is_splitter: bool = false
@export var is_piercing: bool = false
@export var is_homing: bool = false
@export var is_caustic: bool = false
@export var is_vampiric: bool = false
@export var is_explosive: bool = false
@export var is_shrapnel: bool = false
@export var is_boomerang: bool = false
@export var is_stun: bool = false
@export var knockback_force: float = 0.0
var has_split: bool = false
var initial_lifetime: float = 0.85

func _on_body_entered(body: Node):
    if not is_instance_valid(body) or is_queued_for_deletion():
        return
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
            
            if knockback_force > 0 and body.has_method("apply_knockback"):
                body.apply_knockback(velocity.normalized() * knockback_force, 0.3)
                
            if is_stun and body.has_method("apply_stun"):
                body.apply_stun(1.2)
                
            # Electric arc
            if is_electric:
                trigger_electric_arc(body)
                
            # Mitosis split
            if is_splitter and not has_split:
                trigger_mitosis_split()
                
            # Shrapnel burst
            if is_shrapnel and not has_split:
                trigger_shrapnel_burst()
                
            # Explosion
            if is_explosive:
                trigger_explosion()
                
            # Vampiric leech
            if is_vampiric and randf() < 0.3:
                var player_node = get_tree().get_first_node_in_group("player")
                if player_node and player_node.has_method("heal"):
                    player_node.heal(1)
                    
            if is_caustic:
                spawn_caustic_pool(global_position)
                
            if not is_piercing:
                destroy_tear()
        elif body.is_in_group("obstacles"):
            if body.has_method("take_damage"):
                body.take_damage(damage)
            if is_caustic:
                spawn_caustic_pool(global_position)
            if is_explosive:
                trigger_explosion()
            destroy_tear()
        elif body.is_in_group("walls"):
            if is_caustic:
                spawn_caustic_pool(global_position)
            if is_explosive:
                trigger_explosion()
            destroy_tear()

func spawn_caustic_pool(pos: Vector2):
    var pool = Area2D.new()
    pool.position = pos
    pool.collision_layer = 0
    pool.collision_mask = 2
    
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 42.0
    col.shape = shape
    pool.add_child(col)
    
    var p = CPUParticles2D.new()
    p.amount = 16
    p.lifetime = 1.6
    p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 28.0
    p.gravity = Vector2(0, -10)
    p.initial_velocity_min = 5.0
    p.initial_velocity_max = 18.0
    p.scale_amount_min = 3.0
    p.scale_amount_max = 6.0
    p.color = Color(1.0, 0.45, 0.05, 0.85)
    pool.add_child(p)
    
    get_parent().add_child(pool)
    
    var burn_timer = 0.0
    var pool_lifetime = 2.4
    var timer_node = Timer.new()
    timer_node.wait_time = 0.35
    timer_node.autostart = true
    pool.add_child(timer_node)
    timer_node.timeout.connect(func():
        for body in pool.get_overlapping_bodies():
            if body.is_in_group("enemies") and body.has_method("take_damage"):
                body.take_damage(1.8)
    )
    
    var tw = get_tree().create_timer(pool_lifetime)
    tw.timeout.connect(pool.queue_free)

func trigger_electric_arc(source_enemy: Node):
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if enemy != source_enemy and is_instance_valid(enemy):
            if enemy.global_position.distance_to(global_position) < 260.0:
                enemy.take_damage(2.5)
                # Visual electric spark line
                var line = Line2D.new()
                line.points = PackedVector2Array([global_position, enemy.global_position])
                line.width = 3.0
                line.default_color = Color(0.2, 0.95, 1.0, 0.9)
                get_parent().add_child(line)
                var tw = create_tween()
                tw.tween_property(line, "modulate:a", 0.0, 0.2)
                tw.tween_callback(line.queue_free)
                break

func trigger_mitosis_split():
    has_split = true
    for angle in [-0.65, 0.65]:
        var split_tear = duplicate()
        split_tear.has_split = true
        split_tear.scale = scale * 0.7
        split_tear.damage = damage * 0.55
        split_tear.lifetime = 0.4
        split_tear.direction = direction.rotated(angle)
        split_tear.velocity = split_tear.direction * speed * 1.1
        split_tear.position = global_position
        get_parent().add_child(split_tear)

func trigger_explosion():
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if is_instance_valid(enemy):
            if enemy.global_position.distance_to(global_position) < 140.0:
                enemy.take_damage(damage * 1.4)
    var p = CPUParticles2D.new()
    p.position = global_position
    p.amount = 22
    p.lifetime = 0.4
    p.explosiveness = 0.95
    p.color = Color(1.0, 0.5, 0.1, 1.0)
    p.initial_velocity_min = 60.0
    p.initial_velocity_max = 160.0
    p.scale_amount_min = 3.0
    p.scale_amount_max = 6.0
    get_parent().add_child(p)
    var tw = get_tree().create_timer(0.45)
    tw.timeout.connect(p.queue_free)
    SoundManager.play_sfx("explosion", 1.2, -2.0)
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(6.0)

func trigger_shrapnel_burst():
    has_split = true
    for a in [0.0, PI/2.0, PI, 3.0*PI/2.0]:
        var shrap = duplicate()
        shrap.has_split = true
        shrap.is_shrapnel = false
        shrap.scale = scale * 0.55
        shrap.damage = max(1.5, damage * 0.45)
        shrap.lifetime = 0.35
        shrap.direction = Vector2(cos(a), sin(a))
        shrap.velocity = shrap.direction * speed * 1.25
        shrap.position = global_position
        get_parent().add_child(shrap)

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
    timer.timeout.connect(p.queue_free)
