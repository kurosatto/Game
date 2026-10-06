# Room.gd
extends Node2D

signal room_transition_requested(direction)

var room_data = null
var current_floor: int = 1
var active_enemies: Array = []
var door_nodes: Dictionary = {}

# Preloads
var door_scene = preload("res://Door.tscn")
var pickup_scene = preload("res://Pickup.tscn")
var pedestal_scene = preload("res://ItemPedestal.tscn")
var enemy_scene = preload("res://Enemy.tscn")
var obstacle_scene = preload("res://Obstacle.tscn")
var room_layouts = preload("res://RoomLayouts.gd")

func setup_room(data, floor_number: int):
    room_data = data
    current_floor = floor_number
    
    # 1. Clear existing children
    for child in get_children():
        child.queue_free()
        
    active_enemies.clear()
    door_nodes.clear()
    
    # 2. Add Seamless Custom Full-Room Background (1920x1080)
    spawn_fullscreen_background()
    
    # 3. Add Ambient Bioluminescent Particles tailored to room theme
    spawn_ambient_particles()
    
    # 4. Add Impenetrable Room Boundary Colliders & Door Placements
    spawn_boundary_colliders_and_doors()
    
    # 5. Determine Premade Room Layout
    var raw_layout: Dictionary = {}
    match room_data.type:
        0: # START
            raw_layout = room_layouts.get_start_layout()
        2: # TREASURE
            raw_layout = room_layouts.get_treasure_layout()
        4: # SHOP
            raw_layout = room_layouts.get_shop_layout()
        3: # BOSS
            raw_layout = room_layouts.get_boss_layout()
        _: # NORMAL
            var normal_layouts = room_layouts.get_normal_layouts()
            var l_idx = abs(room_data.grid_pos.x * 7 + room_data.grid_pos.y * 13) % normal_layouts.size()
            raw_layout = normal_layouts[l_idx]
            
    var clean_layout = room_layouts.filter_layout_for_doors(raw_layout, room_data.connections)

    # 6. Spawn Floor Decals
    spawn_layout_decals(clean_layout)

    # 7. Spawn Layout Obstacles
    spawn_layout_obstacles(clean_layout)

    # 8. Restore or Initialize Contents based on Persistence State
    if room_data.has_initialized_contents:
        # Restore saved pickups that were left in this room
        for p_data in room_data.saved_pickups:
            var p = pickup_scene.instantiate()
            p.position = p_data["pos"]
            p.pickup_type = p_data["type"]
            add_child(p)
            
        # Restore special room pedestals & shop inventory
        if room_data.type == 2: # TREASURE
            var ped = pedestal_scene.instantiate()
            ped.position = Vector2(960, 540)
            ped.item_id = room_data.treasure_item_id
            add_child(ped)
        elif room_data.type == 4: # SHOP
            spawn_shop_keeper()
            for s_item in room_data.shop_inventory:
                var ped = pedestal_scene.instantiate()
                ped.position = s_item["pos"]
                ped.item_id = s_item["item_id"]
                ped.price = s_item["price"]
                ped.is_shop_item = true
                ped.collected = s_item.get("collected", false)
                add_child(ped)
        elif room_data.type == 3 and not room_data.cleared: # BOSS
            spawn_boss(floor_number)
            
        if room_data.cleared:
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
            if room_data.type == 3:
                spawn_trapdoor()
        else:
            for d_dir in door_nodes:
                door_nodes[d_dir].close_door()
    else:
        # First visit initialization
        room_data.has_initialized_contents = true
        
        # Spawn any pre-saved pickups (such as the guaranteed key on Floor 1!)
        for p_data in room_data.saved_pickups:
            var p = pickup_scene.instantiate()
            p.position = p_data["pos"]
            p.pickup_type = p_data["type"]
            add_child(p)
            
        if room_data.type == 0: # START
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
        elif room_data.type == 2: # TREASURE
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
            spawn_treasure_pedestal()
        elif room_data.type == 4: # SHOP
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
            spawn_shop_items()
        elif room_data.type == 3: # BOSS
            for d_dir in door_nodes:
                door_nodes[d_dir].close_door()
            spawn_boss(floor_number)
        else: # NORMAL
            for d_dir in door_nodes:
                door_nodes[d_dir].close_door()
            for p_info in clean_layout.get("pickups", []):
                var pos = Vector2(p_info["gx"] * 128 + 64, p_info["gy"] * 128 + 64 + 28)
                var p = pickup_scene.instantiate()
                p.position = pos
                p.pickup_type = p_info["type"]
                add_child(p)
            spawn_tactical_enemies(clean_layout, floor_number)

func save_room_state():
    if not room_data:
        return
        
    # 1. Save all active pickups currently in the room
    room_data.saved_pickups.clear()
    for child in get_children():
        if child.is_in_group("pickups") and is_instance_valid(child):
            room_data.saved_pickups.append({
                "type": child.pickup_type,
                "pos": child.position
            })
            
    # 2. Save treasure pedestal state
    if room_data.type == 2:
        for child in get_children():
            if child is Area2D and "item_id" in child and not child.is_shop_item:
                room_data.treasure_item_id = child.item_id
                
    # 3. Save shop inventory
    if room_data.type == 4:
        room_data.shop_inventory.clear()
        for child in get_children():
            if child is Area2D and "is_shop_item" in child and child.is_shop_item:
                room_data.shop_inventory.append({
                    "item_id": child.item_id,
                    "price": child.price,
                    "pos": child.position,
                    "collected": child.collected
                })

func spawn_fullscreen_background():
    var bg = Sprite2D.new()
    bg.name = "FullscreenBackground"
    bg.position = Vector2(960, 540)
    bg.z_index = -20
    
    var bg_path = "res://assets/room_bg_normal.png"
    if room_data:
        match room_data.type:
            0: bg_path = "res://assets/room_bg_start.png"
            2: bg_path = "res://assets/room_bg_treasure.png"
            4: bg_path = "res://assets/room_bg_shop.png"
            3: bg_path = "res://assets/room_bg_boss.png"
            _: bg_path = "res://assets/room_bg_normal.png"
            
    bg.texture = load(bg_path)
    add_child(bg)

func spawn_boundary_colliders_and_doors():
    # Top Wall (thickness 128, leaving 896..1024 open for door at x=960)
    _add_static_box(Vector2(448, 64), Vector2(896, 128))
    _add_static_box(Vector2(1472, 64), Vector2(896, 128))
    if room_data.connections.has(Vector2i.UP):
        spawn_door_at(Vector2(960, 68), Vector2i.UP, 0.0)
    else:
        _add_static_box(Vector2(960, 64), Vector2(128, 128))
        
    # Bottom Wall (thickness 128, leaving 896..1024 open for door at x=960)
    _add_static_box(Vector2(448, 1016), Vector2(896, 128))
    _add_static_box(Vector2(1472, 1016), Vector2(896, 128))
    if room_data.connections.has(Vector2i.DOWN):
        spawn_door_at(Vector2(960, 1012), Vector2i.DOWN, PI)
    else:
        _add_static_box(Vector2(960, 1016), Vector2(128, 128))
        
    # Left Wall (thickness 128, leaving 476..604 open for door at y=540)
    _add_static_box(Vector2(64, 238), Vector2(128, 476))
    _add_static_box(Vector2(64, 842), Vector2(128, 476))
    if room_data.connections.has(Vector2i.LEFT):
        spawn_door_at(Vector2(68, 540), Vector2i.LEFT, 3.0*PI/2.0)
    else:
        _add_static_box(Vector2(64, 540), Vector2(128, 128))
        
    # Right Wall (thickness 128, leaving 476..604 open for door at y=540)
    _add_static_box(Vector2(1856, 238), Vector2(128, 476))
    _add_static_box(Vector2(1856, 842), Vector2(128, 476))
    if room_data.connections.has(Vector2i.RIGHT):
        spawn_door_at(Vector2(1852, 540), Vector2i.RIGHT, PI/2.0)
    else:
        _add_static_box(Vector2(1856, 540), Vector2(128, 128))

func _add_static_box(pos: Vector2, size: Vector2):
    var body = StaticBody2D.new()
    body.position = pos
    body.collision_layer = 4
    body.collision_mask = 1
    var col = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = size
    col.shape = shape
    body.add_child(col)
    add_child(body)

func spawn_door_at(pos: Vector2, d_dir: Vector2i, rot: float):
    var door = door_scene.instantiate()
    door.position = pos
    door.rotation = rot
    door.direction = d_dir
    
    var neighbor_pos = room_data.connections[d_dir]
    var parent = get_parent()
    var neighbor_type = parent.get_room_type(neighbor_pos) if (parent and parent.has_method("get_room_type")) else -1
    var is_visited = parent.is_room_visited(neighbor_pos) if (parent and parent.has_method("is_room_visited")) else false
    
    if (neighbor_type == 2 or neighbor_type == 4) and not is_visited:
        door.is_locked = true
        
    add_child(door)
    door_nodes[d_dir] = door
    door.door_entered.connect(_on_door_entered)

func spawn_ambient_particles():
    var particle_color = Color(0.0, 0.75, 0.90, 0.28) # Soothing ocean cyan
    var glow_color = Color(0.0, 0.65, 0.85, 0.12)
    
    if room_data:
        match room_data.type:
            2: # TREASURE
                particle_color = Color(0.0, 0.90, 0.70, 0.30) # Seafoam mint
                glow_color = Color(0.05, 0.80, 0.65, 0.14)
            4: # SHOP
                particle_color = Color(0.95, 0.80, 0.25, 0.30) # Soft golden amber
                glow_color = Color(0.85, 0.70, 0.20, 0.14)
            3: # BOSS
                particle_color = Color(0.55, 0.65, 0.95, 0.32) # Majestic celestial indigo
                glow_color = Color(0.40, 0.50, 0.85, 0.14)
            0: # START
                particle_color = Color(0.25, 0.85, 1.0, 0.28)
                glow_color = Color(0.15, 0.70, 0.9, 0.12)

    # Layer 1: Gentle bioluminescent plankton motes
    var particles = CPUParticles2D.new()
    particles.position = Vector2(960, 540)
    particles.amount = 40
    particles.lifetime = 6.0
    particles.preprocess = 4.0
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(960, 540)
    particles.gravity = Vector2(0, -6)
    particles.initial_velocity_min = 6.0
    particles.initial_velocity_max = 16.0
    particles.scale_amount_min = 1.5
    particles.scale_amount_max = 3.5
    particles.color = particle_color
    particles.z_index = -5
    add_child(particles)

    # Layer 2: Calm drifting deep-water glow motes
    var particles2 = CPUParticles2D.new()
    particles2.position = Vector2(960, 540)
    particles2.amount = 12
    particles2.lifetime = 12.0
    particles2.preprocess = 6.0
    particles2.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles2.emission_rect_extents = Vector2(900, 480)
    particles2.gravity = Vector2(0, -2)
    particles2.initial_velocity_min = 2.0
    particles2.initial_velocity_max = 5.0
    particles2.scale_amount_min = 5.0
    particles2.scale_amount_max = 10.0
    particles2.color = glow_color
    particles2.z_index = -4
    add_child(particles2)

func spawn_layout_decals(layout: Dictionary):
    for decal in layout.get("decals", []):
        var gx = decal["gx"]
        var gy = decal["gy"]
        var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
        
        var sprite = Sprite2D.new()
        sprite.texture = load("res://assets/" + decal["type"] + ".png")
        sprite.position = pos
        sprite.z_index = -8
        
        var rot_deg = ((gx * 37 + gy * 23) % 4) * 90
        sprite.rotation_degrees = rot_deg
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.75)
        add_child(sprite)
        
        if decal["type"] == "decal_vent":
            var vent_p = CPUParticles2D.new()
            vent_p.position = pos
            vent_p.amount = 6
            vent_p.lifetime = 2.0
            vent_p.gravity = Vector2(0, -18)
            vent_p.scale_amount_min = 1.5
            vent_p.scale_amount_max = 3.0
            vent_p.color = Color(0.0, 0.85, 0.95, 0.45)
            vent_p.z_index = -7
            add_child(vent_p)

func spawn_layout_obstacles(layout: Dictionary):
    var bio_obstacle_map = {
        "rock": "rock",
        "coral": "coral_spire",
        "crystal": "biocrystal",
        "bone": "fossil_bone",
        "stromatolite": "stromatolite",
        "frond": "ediacaran_frond",
        "vent": "hydrothermal_vent",
        "sponge": "calcified_sponge",
    }
    for obs in layout.get("obstacles", []):
        var gx = obs["gx"]
        var gy = obs["gy"]
        var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)

        var obs_node = obstacle_scene.instantiate()
        obs_node.position = pos
        add_child(obs_node)
        var raw_type = obs.get("type", "rock")
        var resolved_type = bio_obstacle_map.get(raw_type, raw_type)
        obs_node.setup_obstacle(resolved_type)

func spawn_tactical_enemies(layout: Dictionary, floor_number: int):
    var spawns = layout.get("enemy_spawns", []).duplicate()
    var target_count = randi_range(3, 3 + floor_number)
    
    var player_node = get_tree().get_first_node_in_group("player")
    var player_pos = player_node.global_position if player_node else Vector2(960, 540)
    
    # 1. Spawn from layout tactical blueprints (ensuring safe distance from player spawn)
    for sp in spawns:
        if active_enemies.size() >= target_count:
            break
        var pos = Vector2(sp["gx"] * 128 + 64, sp["gy"] * 128 + 64 + 28)
        # Guarantee safe distance from player
        if pos.distance_to(player_pos) < 380.0:
            continue
            
        var enemy = enemy_scene.instantiate()
        enemy.position = pos
        enemy.enemy_type = sp.get("type", "fly")
        enemy.setup_enemy(floor_number)
        add_child(enemy)
        active_enemies.append(enemy)
        enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
        
    # 2. If additional enemies needed, safely spawn in safe quadrant locations away from player and doors
    var safe_spawn_candidates = [
        Vector2(3 * 128 + 64, 2 * 128 + 92),
        Vector2(11 * 128 + 64, 2 * 128 + 92),
        Vector2(3 * 128 + 64, 5 * 128 + 92),
        Vector2(11 * 128 + 64, 5 * 128 + 92),
        Vector2(4 * 128 + 64, 2 * 128 + 92),
        Vector2(10 * 128 + 64, 2 * 128 + 92),
        Vector2(4 * 128 + 64, 5 * 128 + 92),
        Vector2(10 * 128 + 64, 5 * 128 + 92),
    ]
    safe_spawn_candidates.shuffle()
    
    for cand_pos in safe_spawn_candidates:
        if active_enemies.size() >= target_count:
            break
        if cand_pos.distance_to(player_pos) < 420.0:
            continue
            
        var occupied = false
        for c in get_children():
            if (c is StaticBody2D or c is CharacterBody2D) and c.position.distance_to(cand_pos) < 70.0:
                occupied = true
                break
        if occupied:
            continue
            
        var enemy = enemy_scene.instantiate()
        enemy.position = cand_pos
        enemy.enemy_type = "fly" if randf() < 0.55 else "pacer"
        enemy.setup_enemy(floor_number)
        add_child(enemy)
        active_enemies.append(enemy)
        enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

func spawn_boss(floor_number: int):
    var boss = enemy_scene.instantiate()
    boss.position = Vector2(960, 540)

    match floor_number:
        1: boss.enemy_type = "boss_stentor"
        2: boss.enemy_type = "boss_anomalocaris"
        3: boss.enemy_type = "boss_cameroceras"
        4: boss.enemy_type = "boss_arthropleura"
        5: boss.enemy_type = "boss_apex_sovereign"
        _: boss.enemy_type = "boss_apex_sovereign"

    boss.setup_enemy(floor_number)
    add_child(boss)
    active_enemies.append(boss)
    boss.enemy_died.connect(_on_enemy_died.bind(boss))

    get_parent().register_boss(boss)

func spawn_treasure_pedestal():
    var ped = pedestal_scene.instantiate()
    ped.position = Vector2(960, 540)
    var items = ["onion", "eye", "hormones", "cells"]
    var chosen_item = items.pick_random()
    ped.item_id = chosen_item
    room_data.treasure_item_id = chosen_item
    add_child(ped)

func spawn_shop_keeper():
    var keeper = Sprite2D.new()
    keeper.texture = load("res://assets/boss.png")
    keeper.scale = Vector2(0.55, 0.55)
    keeper.modulate = Color(0.70, 0.82, 0.95, 1.0)
    keeper.position = Vector2(960, 310)
    add_child(keeper)
    
    var shop_light = PointLight2D.new()
    shop_light.texture = load("res://assets/light.png")
    shop_light.color = Color(1.0, 0.88, 0.4)
    shop_light.energy = 1.1
    shop_light.scale = Vector2(1.5, 1.5)
    keeper.add_child(shop_light)

func spawn_shop_items():
    spawn_shop_keeper()
    
    var shop_defs = [
        {"item_id": "heart", "price": 3, "pos": Vector2(720, 540), "collected": false},
        {"item_id": "key", "price": 5, "pos": Vector2(960, 540), "collected": false},
        {"item_id": ["onion", "eye", "hormones", "cells"].pick_random(), "price": 15, "pos": Vector2(1200, 540), "collected": false}
    ]
    room_data.shop_inventory = shop_defs.duplicate(true)
    
    for item_def in room_data.shop_inventory:
        var ped = pedestal_scene.instantiate()
        ped.position = item_def["pos"]
        ped.item_id = item_def["item_id"]
        ped.is_shop_item = true
        ped.price = item_def["price"]
        add_child(ped)

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
    if roll < 0.55:
        p.pickup_type = "coin"
    elif roll < 0.8:
        p.pickup_type = "heart" if randf() < 0.7 else "heart_half"
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
        var main = get_parent()
        if main and main.has_method("on_boss_defeated"):
            main.on_boss_defeated(current_floor)
        else:
            spawn_trapdoor()

func spawn_trapdoor():
    var td = Area2D.new()
    td.position = Vector2(960, 540)
    td.collision_layer = 0
    td.collision_mask = 1
    
    var sprite = Sprite2D.new()
    sprite.texture = load("res://assets/trapdoor.png")
    td.add_child(sprite)
    
    var td_light = PointLight2D.new()
    td_light.texture = load("res://assets/light.png")
    td_light.color = Color(0.0, 0.95, 1.0)
    td_light.energy = 1.4
    td_light.scale = Vector2(1.8, 1.8)
    td.add_child(td_light)
    
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
