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
var eras = preload("res://data/Eras.gd")
var bestiary = preload("res://data/Bestiary.gd")

var era: Dictionary = {}

func setup_room(data, floor_number: int):
    room_data = data
    era = eras.for_floor(floor_number)
    
    # 1. Clear existing children
    for child in get_children():
        child.queue_free()
        
    active_enemies.clear()
    door_nodes.clear()
    
    var dir_angles = {
        Vector2i.UP: 0.0,
        Vector2i.RIGHT: PI/2.0,
        Vector2i.DOWN: PI,
        Vector2i.LEFT: 3.0*PI/2.0
    }
    
    # 2. Build 1080p Grid (15 cols x 8 rows of 128x128px tiles)
    for gy in range(8):
        for gx in range(15):
            var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
            var is_border = (gx == 0 or gx == 14 or gy == 0 or gy == 7)
            
            # Check door spots
            var is_door_spot = false
            var door_dir = Vector2i.ZERO
            if gy == 0 and gx == 7:
                is_door_spot = true
                door_dir = Vector2i.UP
            elif (gy == 3 or gy == 4) and gx == 14 and gy == 3:
                is_door_spot = true
                door_dir = Vector2i.RIGHT
            elif gy == 7 and gx == 7:
                is_door_spot = true
                door_dir = Vector2i.DOWN
            elif (gy == 3 or gy == 4) and gx == 0 and gy == 3:
                is_door_spot = true
                door_dir = Vector2i.LEFT
                
            if is_door_spot:
                if room_data.connections.has(door_dir):
                    var door = door_scene.instantiate()
                    # Center left and right doors vertically at 540
                    if door_dir == Vector2i.LEFT or door_dir == Vector2i.RIGHT:
                        door.position = Vector2(pos.x, 540)
                    else:
                        door.position = pos
                        
                    door.rotation = dir_angles[door_dir]
                    door.direction = door_dir
                    
                    var neighbor_pos = room_data.connections[door_dir]
                    var neighbor_type = get_parent().get_room_type(neighbor_pos)
                    
                    if (neighbor_type == 2 or neighbor_type == 4) and not get_parent().is_room_visited(neighbor_pos):
                        door.is_locked = true
                        
                    add_child(door)
                    door_nodes[door_dir] = door
                    door.door_entered.connect(_on_door_entered)
                else:
                    spawn_wall(pos)
            elif is_border:
                spawn_wall(pos)
            else:
                spawn_floor(pos)

    # 3. Spawn contents based on Room Type
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
    floor_tile.modulate = era.get("floor_tint", Color.WHITE)
    add_child(floor_tile)

func spawn_obstacles():
    var spawned = 0
    var max_rocks = randi_range(3, 6)
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
            if c.position.distance_to(pos) < 30:
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
            continue # Clear center
            
        var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
        
        var occupied = false
        for c in get_children():
            if c is StaticBody2D and c.position.distance_to(pos) < 40:
                occupied = true
                break
        if occupied:
            continue
            
        var enemy = enemy_scene.instantiate()
        enemy.position = pos
        var species: String = era.enemies.pick_random()
        enemy.setup_from_data(bestiary.get_enemy(species), floor_number)
        
        add_child(enemy)
        active_enemies.append(enemy)
        enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
        spawned += 1

func spawn_boss(floor_number: int):
    var boss = enemy_scene.instantiate()
    boss.position = Vector2(960, 540)
    boss.setup_from_data(bestiary.get_enemy(era.boss), floor_number)
    
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
