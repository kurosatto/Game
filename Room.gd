# Room.gd
extends Node2D

signal room_transition_requested(direction)

var room_data = null
var active_enemies: Array = []
var door_nodes: Dictionary = {}

# Preloads
var door_scene = preload("res://Door.tscn")
var pickup_scene = preload("res://Pickup.tscn")
var pedestal_scene = preload("res://ItemPedestal.tscn")
var enemy_scene = preload("res://Enemy.tscn")

func setup_room(data, floor_number: int):
    room_data = data
    
    # 1. Clear existing children
    for child in get_children():
        child.queue_free()
        
    active_enemies.clear()
    door_nodes.clear()
    
    # 2. Add Ambient Bioluminescent Particles (Marine snow / floating bio-motes)
    spawn_ambient_particles()
    
    # 3. Add Impenetrable Room Boundary Colliders (prevents walking off-screen under all circumstances)
    spawn_boundary_colliders()
    
    # 4. Build 1080p Grid (15 cols x 8 rows of 128x128px tiles)
    var dir_angles = {
        Vector2i.UP: 0.0,
        Vector2i.RIGHT: PI/2.0,
        Vector2i.DOWN: PI,
        Vector2i.LEFT: 3.0*PI/2.0
    }
    
    for gy in range(8):
        for gx in range(15):
            var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
            var is_border = (gx == 0 or gx == 14 or gy == 0 or gy == 7)
            
            # Identify door slots
            var is_top_door = (gy == 0 and gx == 7)
            var is_bottom_door = (gy == 7 and gx == 7)
            var is_left_door = (gx == 0 and (gy == 3 or gy == 4))
            var is_right_door = (gx == 14 and (gy == 3 or gy == 4))
            
            if is_top_door:
                if room_data.connections.has(Vector2i.UP):
                    spawn_door_at(Vector2(960, 92), Vector2i.UP, 0.0)
                else:
                    spawn_wall(pos)
            elif is_bottom_door:
                if room_data.connections.has(Vector2i.DOWN):
                    spawn_door_at(Vector2(960, 988), Vector2i.DOWN, PI)
                else:
                    spawn_wall(pos)
            elif is_left_door:
                if room_data.connections.has(Vector2i.LEFT):
                    # Spawn single door once on gy == 3
                    if gy == 3:
                        spawn_door_at(Vector2(64, 540), Vector2i.LEFT, 3.0*PI/2.0)
                    # For both gy == 3 and gy == 4, do not spawn wall
                else:
                    spawn_wall(pos)
            elif is_right_door:
                if room_data.connections.has(Vector2i.RIGHT):
                    if gy == 3:
                        spawn_door_at(Vector2(1856, 540), Vector2i.RIGHT, PI/2.0)
                else:
                    spawn_wall(pos)
            elif is_border:
                spawn_wall(pos)
            else:
                spawn_floor(pos)

    # 5. Spawn contents based on Room Type
    if room_data.cleared:
        for d_dir in door_nodes:
            door_nodes[d_dir].open_door()
            
        if room_data.type == 2: # TREASURE
            spawn_empty_pedestal()
        elif room_data.type == 4: # SHOP
            spawn_shop_keeper()
    else:
        for d_dir in door_nodes:
            door_nodes[d_dir].close_door()
            
        if room_data.type == 0: # START
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
        elif room_data.type == 2: # TREASURE
            spawn_treasure_pedestal()
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
        elif room_data.type == 4: # SHOP
            spawn_shop_items()
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
        elif room_data.type == 3: # BOSS
            spawn_boss(floor_number)
        else: # NORMAL
            spawn_obstacles()
            spawn_normal_enemies(floor_number)

func spawn_door_at(pos: Vector2, d_dir: Vector2i, rot: float):
    var door = door_scene.instantiate()
    door.position = pos
    door.rotation = rot
    door.direction = d_dir
    
    var neighbor_pos = room_data.connections[d_dir]
    var neighbor_type = get_parent().get_room_type(neighbor_pos)
    
    if (neighbor_type == 2 or neighbor_type == 4) and not get_parent().is_room_visited(neighbor_pos):
        door.is_locked = true
        
    add_child(door)
    door_nodes[d_dir] = door
    door.door_entered.connect(_on_door_entered)

func spawn_boundary_colliders():
    # 4 infinite outer boundary walls to prevent clipping off-screen
    var boundaries = [
        {"pos": Vector2(960, -80), "size": Vector2(2400, 200)},   # Top
        {"pos": Vector2(960, 1160), "size": Vector2(2400, 200)},  # Bottom
        {"pos": Vector2(-80, 540), "size": Vector2(200, 1600)},   # Left
        {"pos": Vector2(2000, 540), "size": Vector2(200, 1600)}   # Right
    ]
    for b in boundaries:
        var body = StaticBody2D.new()
        body.position = b.pos
        body.collision_layer = 4
        body.collision_mask = 1
        var col = CollisionShape2D.new()
        var shape = RectangleShape2D.new()
        shape.size = b.size
        col.shape = shape
        body.add_child(col)
        add_child(body)

func spawn_ambient_particles():
    var particles = CPUParticles2D.new()
    particles.position = Vector2(960, 540)
    particles.amount = 35
    particles.lifetime = 6.0
    particles.preprocess = 4.0
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(960, 540)
    particles.gravity = Vector2(0, -6)
    particles.initial_velocity_min = 5.0
    particles.initial_velocity_max = 15.0
    particles.scale_amount_min = 2.0
    particles.scale_amount_max = 4.5
    particles.color = Color(0.0, 0.9, 1.0, 0.35)
    particles.z_index = -5
    add_child(particles)

func spawn_wall(pos: Vector2):
    var wall = StaticBody2D.new()
    wall.position = pos
    wall.add_to_group("walls")
    wall.collision_layer = 4
    wall.collision_mask = 0
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/wall.png")
    wall.add_child(sprite)
    
    var col = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(128, 128)
    col.shape = shape
    wall.add_child(col)
    
    add_child(wall)

func spawn_floor(pos: Vector2):
    var floor_tile = Sprite2D.new()
    floor_tile.texture = load("res://assets/floor.png")
    floor_tile.position = pos
    floor_tile.z_index = -10
    add_child(floor_tile)

func spawn_obstacles():
    var spawned = 0
    var max_rocks = randi_range(4, 7)
    var attempts = 0
    
    while spawned < max_rocks and attempts < 40:
        attempts += 1
        var gx = randi_range(3, 11)
        var gy = randi_range(2, 5)
        
        # Don't block center or door pathways
        if gx == 7 or gy == 3 or gy == 4:
            continue
            
        var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
        
        var occupied = false
        for c in get_children():
            if c.position.distance_to(pos) < 40:
                occupied = true
                break
        if occupied:
            continue
            
        var rock = StaticBody2D.new()
        rock.position = pos
        rock.add_to_group("obstacles")
        rock.collision_layer = 4
        rock.set_script(load("res://Obstacle.gd"))
        
        var sprite = Sprite2D.new()
        sprite.texture = load("res://assets/rock.png")
        rock.add_child(sprite)
        
        var col = CollisionShape2D.new()
        var shape = RectangleShape2D.new()
        shape.size = Vector2(110, 110)
        col.shape = shape
        rock.add_child(col)
        
        add_child(rock)
        spawned += 1

func spawn_normal_enemies(floor_number: int):
    var num_enemies = randi_range(3, 4 + floor_number)
    var spawned = 0
    var attempts = 0
    
    while spawned < num_enemies and attempts < 60:
        attempts += 1
        var gx = randi_range(2, 12)
        var gy = randi_range(1, 6)
        
        if (gx >= 6 and gx <= 8) and (gy >= 3 and gy <= 4):
            continue
            
        var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
        
        var occupied = false
        for c in get_children():
            if c is StaticBody2D and c.position.distance_to(pos) < 50:
                occupied = true
                break
        if occupied:
            continue
            
        var enemy = enemy_scene.instantiate()
        enemy.position = pos
        var type = "fly" if randf() < 0.6 else "pacer"
        enemy.enemy_type = type
        enemy.setup_enemy(floor_number)
        
        add_child(enemy)
        active_enemies.append(enemy)
        enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
        spawned += 1

func spawn_boss(floor_number: int):
    var boss = enemy_scene.instantiate()
    boss.position = Vector2(960, 540)
    boss.enemy_type = "boss"
    boss.setup_enemy(floor_number)
    
    add_child(boss)
    active_enemies.append(boss)
    boss.enemy_died.connect(_on_enemy_died.bind(boss))
    
    get_parent().register_boss(boss)

func spawn_treasure_pedestal():
    var ped = pedestal_scene.instantiate()
    ped.position = Vector2(960, 540)
    var items = ["onion", "eye", "hormones", "cells"]
    ped.item_id = items.pick_random()
    add_child(ped)

func spawn_empty_pedestal():
    var ped = pedestal_scene.instantiate()
    ped.position = Vector2(960, 540)
    ped.item_id = ""
    add_child(ped)

func spawn_shop_keeper():
    var keeper = Sprite2D.new()
    keeper.texture = load("res://assets/boss.png")
    keeper.scale = Vector2(0.5, 0.5)
    keeper.modulate = Color(0.5, 0.6, 0.7, 1.0)
    keeper.position = Vector2(960, 320)
    add_child(keeper)

func spawn_shop_items():
    spawn_shop_keeper()
    
    var heart_ped = pedestal_scene.instantiate()
    heart_ped.position = Vector2(760, 540)
    heart_ped.item_id = "heart"
    heart_ped.is_shop_item = true
    heart_ped.price = 3
    add_child(heart_ped)
    
    var key_ped = pedestal_scene.instantiate()
    key_ped.position = Vector2(960, 540)
    key_ped.item_id = "key" if randf() < 0.5 else "bomb"
    key_ped.is_shop_item = true
    key_ped.price = 5
    add_child(key_ped)
    
    var item_ped = pedestal_scene.instantiate()
    item_ped.position = Vector2(1160, 540)
    var items = ["onion", "eye", "hormones", "cells"]
    item_ped.item_id = items.pick_random()
    item_ped.is_shop_item = true
    item_ped.price = 15
    add_child(item_ped)

func _on_enemy_died(enemy):
    active_enemies.erase(enemy)
    
    if randf() < 0.35:
        spawn_random_pickup(enemy.global_position)
        
    if active_enemies.size() == 0:
        clear_room()

func spawn_random_pickup(pos: Vector2):
    var p = pickup_scene.instantiate()
    p.position = pos
    
    var roll = randf()
    if roll < 0.45:
        p.pickup_type = "coin"
    elif roll < 0.7:
        p.pickup_type = "heart" if randf() < 0.7 else "heart_half"
    elif roll < 0.85:
        p.pickup_type = "bomb"
    else:
        p.pickup_type = "key"
        
    add_child(p)

func clear_room():
    room_data.cleared = true
    
    for d_dir in door_nodes:
        door_nodes[d_dir].open_door()
        
    if room_data.type == 1:
        if randf() < 0.65:
            spawn_random_pickup(Vector2(960, 540))
            
    if room_data.type == 3:
        spawn_trapdoor()

func spawn_trapdoor():
    var td = Area2D.new()
    td.position = Vector2(960, 540)
    td.collision_layer = 0
    td.collision_mask = 1
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/trapdoor.png")
    td.add_child(sprite)
    
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 48.0
    col.shape = shape
    td.add_child(col)
    
    add_child(td)
    
    td.body_entered.connect(func(body):
        if body.is_in_group("player"):
            get_parent().advance_floor()
    )

func _on_door_entered(direction):
    room_transition_requested.emit(direction)
