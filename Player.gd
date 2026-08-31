# Player.gd
extends CharacterBody2D

signal health_changed(health, max_health)
signal stats_changed(dna, bombs, keys)
signal dna_changed(current_dna, max_dna, level)
signal player_died

@export var max_health: int = 6
@export var health: int = 6

# Base stats (Scaled for 1080p)
@export var speed: float = 380.0
@export var damage: float = 3.5
@export var fire_delay: float = 0.32
@export var range_lifetime: float = 0.85
@export var shot_speed: float = 680.0

# Organism Evolution & Inventory
var dna_biomass: int = 0
var dna_to_next_level: int = 20
var evolution_level: int = 1

var bombs: int = 1
var keys: int = 0

# Visual animation & cooldowns
var swim_time: float = 0.0
var shoot_cooldown: float = 0.0
var invincibility_time: float = 0.0
var door_cooldown: float = 0.0

# Preloads
var tear_scene = preload("res://Tear.tscn")
var bomb_scene = preload("res://Bomb.tscn")

func _ready():
    add_to_group("player")
    call_deferred("emit_all_signals")

func emit_all_signals():
    health_changed.emit(health, max_health)
    stats_changed.emit(dna_biomass, bombs, keys)
    dna_changed.emit(dna_biomass, dna_to_next_level, evolution_level)

func _physics_process(delta: float):
    # Cooldowns
    if shoot_cooldown > 0:
        shoot_cooldown -= delta
    if invincibility_time > 0:
        invincibility_time -= delta
        $Sprite2D.visible = sin(invincibility_time * 30.0) > 0.0
    else:
        $Sprite2D.visible = true
        
    if door_cooldown > 0:
        door_cooldown -= delta

    # 1. Movement
    var move_dir = Vector2.ZERO
    move_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    move_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
    
    velocity = move_dir.normalized() * speed
    move_and_slide()

    # Dynamic Swimming Squash & Stretch
    if move_dir != Vector2.ZERO:
        swim_time += delta * 12.0
        var stretch_x = 1.0 + sin(swim_time) * 0.15
        var stretch_y = 1.0 - sin(swim_time) * 0.15
        $Sprite2D.scale = Vector2(stretch_x, stretch_y)
        $Sprite2D.rotation = lerp_angle($Sprite2D.rotation, move_dir.angle() - PI/2, delta * 8.0)
    else:
        swim_time += delta * 4.0
        var pulse = 1.0 + sin(swim_time) * 0.05
        $Sprite2D.scale = Vector2(pulse, pulse)
        $Sprite2D.rotation = lerp_angle($Sprite2D.rotation, 0.0, delta * 8.0)

    # 2. Shooting
    var shoot_dir = Vector2.ZERO
    shoot_dir.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
    shoot_dir.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
    
    if shoot_dir != Vector2.ZERO and shoot_cooldown <= 0:
        var shoot_vec = Vector2.ZERO
        if abs(shoot_dir.x) >= abs(shoot_dir.y):
            shoot_vec = Vector2(sign(shoot_dir.x), 0)
        else:
            shoot_vec = Vector2(0, sign(shoot_dir.y))
            
        shoot_tear(shoot_vec)

    # 3. Spore Bombs
    if Input.is_action_just_pressed("place_bomb") and bombs > 0:
        place_bomb()

func shoot_tear(dir: Vector2):
    shoot_cooldown = fire_delay
    SoundManager.play_sfx("shoot", 1.0)
    $Sprite2D.scale = Vector2(1.25, 0.8)
    
    var is_triple_shot = has_meta("triple_shot") and get_meta("triple_shot")
    if is_triple_shot:
        var angles = [-0.22, 0.0, 0.22]
        for angle in angles:
            spawn_tear(dir.rotated(angle))
    else:
        spawn_tear(dir)

func spawn_tear(dir: Vector2):
    var tear = tear_scene.instantiate()
    tear.position = global_position
    tear.damage = damage
    tear.lifetime = range_lifetime
    tear.speed = shot_speed
    tear.velocity = dir * shot_speed + velocity * 0.35
    get_parent().add_child(tear)

func place_bomb():
    bombs -= 1
    stats_changed.emit(dna_biomass, bombs, keys)
    
    var bomb = bomb_scene.instantiate()
    bomb.position = global_position
    get_parent().add_child(bomb)

func add_dna(amount: int):
    dna_biomass += amount
    SoundManager.play_sfx("dna_pickup", 1.0 + (dna_biomass % 10) * 0.05)
    
    if dna_biomass >= dna_to_next_level:
        dna_biomass -= dna_to_next_level
        evolution_level += 1
        dna_to_next_level = int(dna_to_next_level * 1.5)
        SoundManager.play_sfx("level_up", 1.0)
        
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("display_item_banner"):
            main.display_item_banner("BIOMASS MUTATION!", "Organism evolved to Level " + str(evolution_level))
            
    stats_changed.emit(dna_biomass, bombs, keys)
    dna_changed.emit(dna_biomass, dna_to_next_level, evolution_level)

func add_coin(amount: int):
    add_dna(amount)

func take_damage(amount: int):
    if invincibility_time > 0:
        return
        
    health = max(0, health - amount)
    invincibility_time = 1.0
    
    SoundManager.play_sfx("player_hurt", 1.0)
    $Sprite2D.scale = Vector2(0.7, 1.4)
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(8.0)
        
    health_changed.emit(health, max_health)
    
    if health <= 0:
        die()

func heal(amount: int):
    health = min(max_health, health + amount)
    SoundManager.play_sfx("heart_pickup", 1.0)
    health_changed.emit(health, max_health)

func add_max_health(amount: int):
    max_health += amount
    health += amount
    SoundManager.play_sfx("heart_pickup", 1.1)
    health_changed.emit(health, max_health)

func add_bomb(amount: int):
    bombs = min(99, bombs + amount)
    stats_changed.emit(dna_biomass, bombs, keys)

func add_key(amount: int):
    keys = min(99, keys + amount)
    SoundManager.play_sfx("dna_pickup", 0.9)
    stats_changed.emit(dna_biomass, bombs, keys)

func apply_item_upgrade(item_id: String):
    if item_id == "onion":
        fire_delay = max(0.12, fire_delay - 0.1)
    elif item_id == "eye":
        set_meta("triple_shot", true)
        fire_delay = fire_delay * 1.25
    elif item_id == "hormones":
        damage += 2.0
        speed += 60.0
    elif item_id == "cells":
        add_max_health(2)
        heal(2)
        
    health_changed.emit(health, max_health)
    stats_changed.emit(dna_biomass, bombs, keys)

func die():
    SoundManager.play_sfx("player_hurt", 0.7)
    player_died.emit()
    set_physics_process(false)
    set_process(false)
