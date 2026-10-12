# Obstacle.gd
extends StaticBody2D

@export var obstacle_type: String = "rock"

var light_node: PointLight2D = null

func setup_obstacle(type_name: String = "rock"):
    obstacle_type = type_name
    
    var sprite = get_node_or_null("Sprite2D")
    if not sprite:
        sprite = Sprite2D.new()
        sprite.name = "Sprite2D"
        add_child(sprite)
        
    var tex_path = "res://assets/rock.png"
    var light_color = Color.TRANSPARENT
    var light_energy = 0.0
    
    match obstacle_type:
        "coral_spire":
            tex_path = "res://assets/coral_spire.png"
            light_color = Color(0.50, 0.80, 1.0)
            light_energy = 0.85
        "biocrystal":
            tex_path = "res://assets/biocrystal.png"
            light_color = Color(0.0, 0.9, 1.0)
            light_energy = 1.2
        "fossil_bone":
            tex_path = "res://assets/fossil_bone.png"
            light_color = Color(0.2, 0.6, 0.7)
            light_energy = 0.4
        "stromatolite":
            tex_path = "res://assets/stromatolite.png"
            light_color = Color(0.2, 0.80, 0.60)
            light_energy = 0.6
        "ediacaran_frond":
            tex_path = "res://assets/ediacaran_frond.png"
            light_color = Color(0.15, 0.90, 0.85)
            light_energy = 0.75
        "hydrothermal_vent":
            tex_path = "res://assets/hydrothermal_vent.png"
            light_color = Color(0.0, 0.85, 0.95)
            light_energy = 1.2
        "calcified_sponge":
            tex_path = "res://assets/calcified_sponge.png"
            light_color = Color(0.85, 0.75, 0.35)
            light_energy = 0.5
        _:
            tex_path = "res://assets/rock.png"
            light_color = Color(0.0, 0.6, 0.8)
            light_energy = 0.35
            
    sprite.texture = load(tex_path)
    
    if light_energy > 0:
        if not light_node:
            light_node = PointLight2D.new()
            light_node.texture = load("res://assets/light.png")
            light_node.scale = Vector2(1.1, 1.1)
            add_child(light_node)
        light_node.color = light_color
        light_node.energy = light_energy

var max_health: float = 12.0
var health: float = 12.0

func take_damage(amount: float):
    health -= amount
    
    # Visual hit flash
    var sprite = get_node_or_null("Sprite2D")
    if sprite:
        sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
        var tw = create_tween()
        tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
        
    spawn_hit_chip_fx()
    SoundManager.play_sfx("hit", 0.8, -4.0)
    
    if health <= 0:
        destroy_rock()

func spawn_hit_chip_fx():
    var p = CPUParticles2D.new()
    p.position = global_position
    p.emitting = true
    p.one_shot = true
    p.explosiveness = 0.9
    p.amount = 6
    p.lifetime = 0.25
    p.spread = 180.0
    p.initial_velocity_min = 40.0
    p.initial_velocity_max = 110.0
    p.scale_amount_min = 2.0
    p.scale_amount_max = 4.0
    p.color = Color(0.7, 0.85, 0.95, 0.8)
    get_parent().add_child(p)
    var timer = get_tree().create_timer(0.3)
    timer.timeout.connect(p.queue_free)

func destroy_rock():
    spawn_destruction_fx()
    SoundManager.play_sfx("explosion", 1.4, -6.0)
    
    # 35% chance to spawn a pickup on destruction (Biomass, Hearts, or Keys)
    if randf() < 0.35:
        var pickup_scene = load("res://Pickup.tscn")
        var p = pickup_scene.instantiate()
        p.position = global_position
        var roll = randf()
        if roll < 0.55:
            p.pickup_type = "coin"
        elif roll < 0.85:
            p.pickup_type = "heart"
        else:
            p.pickup_type = "key"
        get_parent().call_deferred("add_child", p)
        
    queue_free()

func spawn_destruction_fx():
    var particles = CPUParticles2D.new()
    particles.position = global_position
    particles.emitting = true
    particles.one_shot = true
    particles.explosiveness = 0.95
    particles.amount = 14
    particles.lifetime = 0.45
    particles.spread = 180.0
    particles.initial_velocity_min = 60.0
    particles.initial_velocity_max = 180.0
    particles.scale_amount_min = 2.5
    particles.scale_amount_max = 6.0
    
    match obstacle_type:
        "coral_spire":
            particles.color = Color(0.55, 0.80, 1.0, 0.9)
        "biocrystal":
            particles.color = Color(0.0, 0.95, 1.0, 0.95)
        "fossil_bone":
            particles.color = Color(0.8, 0.85, 0.8, 0.85)
        "stromatolite":
            particles.color = Color(0.25, 0.85, 0.65, 0.9)
        "ediacaran_frond":
            particles.color = Color(0.20, 0.92, 0.85, 0.9)
        "hydrothermal_vent":
            particles.color = Color(0.15, 0.88, 0.95, 0.9)
        "calcified_sponge":
            particles.color = Color(0.85, 0.75, 0.35, 0.85)
        _:
            particles.color = Color(0.35, 0.55, 0.7, 0.85)
            
    get_parent().add_child(particles)
    var timer = get_tree().create_timer(0.5)
    timer.timeout.connect(particles.queue_free)
