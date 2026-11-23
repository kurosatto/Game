# Room.gd
extends Node2D

signal room_transition_requested(direction)

var room_data = null
var current_floor: int = 1
# Extra floor on each side when the screen is wider than 16:9, so rooms fill
# the whole width (phones are ~19.5:9). Layouts stay in the central 1920px.
var side_margin: float = 0.0
# Which way the player walked in (Main sets it before setup_room); the boss
# starts on the far side of the room from that door
var entry_dir: Vector2i = Vector2i.ZERO

const ERA_ART = ["ediacaran", "cambrian", "ordovician", "carboniferous", "permian"]

# Tests can force a margin (headless runs always report a 1920px viewport)
static var margin_override: float = -1.0

static func margin_for(viewport: Viewport) -> float:
    if margin_override >= 0.0:
        return margin_override
    var w = viewport.get_visible_rect().size.x
    return clampf((w - 1920.0) / 2.0, 0.0, 400.0)

func era_dir() -> String:
    return "res://assets/eras/%s/" % ERA_ART[clampi(current_floor - 1, 0, ERA_ART.size() - 1)]
var active_enemies: Array = []
var door_nodes: Dictionary = {}

# Preloads
var door_scene = preload("res://Door.tscn")
var pickup_scene = preload("res://Pickup.tscn")
var pedestal_scene = preload("res://ItemPedestal.tscn")
var enemy_scene = preload("res://Enemy.tscn")
var obstacle_scene = preload("res://Obstacle.tscn")
var room_layouts = preload("res://RoomLayouts.gd")
var fauna = preload("res://data/Fauna.gd")
const Obstacle = preload("res://Obstacle.gd")
const Enemy = preload("res://Enemy.gd")
var era_look = preload("res://data/EraLook.gd")
const HitFX = preload("res://HitFX.gd")

func setup_room(data, floor_number: int):
    room_data = data
    current_floor = floor_number
    side_margin = margin_for(get_viewport())
    
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
        5: # SEEP: open ground around the seep
            raw_layout = room_layouts.get_treasure_layout()
            raw_layout["decals"] = []
        _ when room_data.special in OPEN_SPECIALS: # open ground for the room's feature
            raw_layout = room_layouts.get_treasure_layout()
            raw_layout["decals"] = []
        _: # NORMAL
            var normal_layouts = room_layouts.get_normal_layouts()
            var l_idx = room_data.layout_idx
            if l_idx < 0 or l_idx >= normal_layouts.size():
                l_idx = abs(room_data.grid_pos.x * 7 + room_data.grid_pos.y * 13) % normal_layouts.size()
            raw_layout = normal_layouts[l_idx]
            
    var clean_layout = room_layouts.filter_layout_for_doors(raw_layout, room_data.connections)

    # 6. Spawn Floor Decals
    spawn_layout_decals(clean_layout)

    # 7. Spawn Layout Obstacles
    spawn_layout_obstacles(clean_layout)
    close_tight_gaps()

    # 7b. Era ground hazards in fight rooms (Hazard.gd)
    if room_data.type == 1 and room_data.special == "":
        spawn_hazards(floor_number)

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
        elif room_data.type == 5: # SEEP
            spawn_seep()
        elif room_data.special != "":
            start_special(clean_layout, floor_number, false)
        elif room_data.type == 3 and not room_data.cleared: # BOSS
            spawn_boss(floor_number)
        elif room_data.type == 1 and not room_data.cleared: # NORMAL left mid-fight
            spawn_tactical_enemies(clean_layout, floor_number)
            spawn_fronds(floor_number)
            
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
        
        # Spawn any pre-saved pickups (such as the floor's one hidden key)
        for p_data in room_data.saved_pickups:
            var p = pickup_scene.instantiate()
            p.position = free_spot(p_data["pos"], 50.0) if p_data.get("place", false) else p_data["pos"]
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
        elif room_data.type == 5: # SEEP
            room_data.cleared = true
            for d_dir in door_nodes:
                door_nodes[d_dir].open_door()
            spawn_seep()
        elif room_data.type == 3: # BOSS
            for d_dir in door_nodes:
                door_nodes[d_dir].close_door()
            spawn_boss(floor_number)
        elif room_data.special != "":
            start_special(clean_layout, floor_number, true)
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
            spawn_fronds(floor_number)
            # From era 2, some rooms draw a second group in once the first falls
            if floor_number >= 2 and randf() < 0.22:
                room_data.waves_left = 1

    # A fight room with nobody to fight would keep its doors shut forever
    if room_data.type == 1 and not room_data.cleared and active_enemies.is_empty():
        clear_room.call_deferred()

# ---- Special rooms (data/SpecialRooms.gd, rooms/SpecialRoom.gd) ----
const OPEN_SPECIALS = ["vent", "dig", "extinction", "nest", "symbiont"]
var special_node: Node2D = null

func start_special(layout: Dictionary, floor_number: int, first: bool):
    special_node = preload("res://rooms/SpecialRoom.gd").new()
    special_node.name = "Special"
    special_node.room = self
    special_node.kind = room_data.special
    special_node.floor_num = floor_number
    special_node.layout = layout
    add_child(special_node)
    special_node.begin(first)

# Shut the doors and start a fight in a room that began peaceful (an
# ambush, an angry parent)
func begin_fight():
    room_data.cleared = false
    for d_dir in door_nodes:
        door_nodes[d_dir].close_door()

# Animals still to beat here: the GROW screen stays shut until they are
# (HUD.show_grow_screen). Special rooms with a fight in them say so too.
func in_combat() -> bool:
    if room_data == null or room_data.cleared:
        return false
    return room_data.type in [1, 3]

func save_room_state():
    if not room_data:
        return
        
    # 1. Save all active pickups currently in the room
    room_data.saved_pickups.clear()
    for child in get_children():
        if child.is_in_group("pickups") and is_instance_valid(child) and not child.is_queued_for_deletion():
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
    # Era room art (generate_room_art.py): a 128px rim around a floor that
    # tiles horizontally, so the room can be as wide as the screen. The side
    # patches take in 64px of floor too, where the rim's shadow falls.
    var bg = NinePatchRect.new()
    bg.name = "FullscreenBackground"
    bg.texture = load(era_dir() + "room.png")
    bg.patch_margin_left = 192
    bg.patch_margin_right = 192
    bg.patch_margin_top = 128
    bg.patch_margin_bottom = 128
    bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
    bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
    bg.position = Vector2(-side_margin, 0)
    bg.size = Vector2(1920 + side_margin * 2, 1080)
    bg.z_index = -20
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Room types keep their mood through a tint over the era art
    if room_data:
        match room_data.type:
            0: bg.modulate = Color(0.95, 1.05, 1.1)
            2: bg.modulate = Color(1.15, 1.08, 0.8)
            4: bg.modulate = Color(1.12, 1.0, 0.85)
            5: bg.modulate = Color(1.05, 1.08, 1.0)
            3: bg.modulate = Color(0.85, 0.75, 0.95)
    # Colour art styles paint the open floor in their own backdrop key
    bg.material = preload("res://data/ArtStyles.gd").floor_material(SettingsManager.art_style, era_dir())
    add_child(bg)
    # Screens taller than 16:9 (the Legion Go's 1920x1200) see past the top
    # and bottom of the room: mirror the rocky rim out into that strip
    var extra = ceilf((get_viewport().get_visible_rect().size.y - 1080.0) / 2.0) + 8.0
    if extra > 8.0:
        extra = minf(extra, 400.0)
        for top in [true, false]:
            var at = AtlasTexture.new()
            at.atlas = bg.texture
            at.region = Rect2(0, 0 if top else 1080.0 - extra, 1920, extra)
            var strip = TextureRect.new()
            strip.name = "RimTop" if top else "RimBottom"
            strip.texture = at
            strip.flip_v = true
            strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            strip.stretch_mode = TextureRect.STRETCH_SCALE
            strip.position = Vector2(-side_margin, -extra if top else 1080.0)
            strip.size = Vector2(1920 + side_margin * 2, extra)
            strip.z_index = -20
            strip.modulate = bg.modulate
            strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
            add_child(strip)

func spawn_boundary_colliders_and_doors():
    var m = side_margin
    # Top Wall (thickness 128, leaving 896..1024 open for door at x=960)
    _add_static_box(Vector2(448 - m / 2, 64), Vector2(896 + m, 128))
    _add_static_box(Vector2(1472 + m / 2, 64), Vector2(896 + m, 128))
    if room_data.connections.has(Vector2i.UP):
        spawn_door_at(Vector2(960, 68), Vector2i.UP, 0.0)
    else:
        _add_static_box(Vector2(960, 64), Vector2(128, 128))
        
    # Bottom Wall (thickness 128, leaving 896..1024 open for door at x=960)
    _add_static_box(Vector2(448 - m / 2, 1016), Vector2(896 + m, 128))
    _add_static_box(Vector2(1472 + m / 2, 1016), Vector2(896 + m, 128))
    if room_data.connections.has(Vector2i.DOWN):
        spawn_door_at(Vector2(960, 1012), Vector2i.DOWN, PI)
    else:
        _add_static_box(Vector2(960, 1016), Vector2(128, 128))
        
    # Left Wall (thickness 128, leaving 476..604 open for door at y=540)
    _add_static_box(Vector2(64 - m, 238), Vector2(128, 476))
    _add_static_box(Vector2(64 - m, 842), Vector2(128, 476))
    if room_data.connections.has(Vector2i.LEFT):
        spawn_door_at(Vector2(68 - m, 540), Vector2i.LEFT, 3.0*PI/2.0)
    else:
        _add_static_box(Vector2(64 - m, 540), Vector2(128, 128))
        
    # Right Wall (thickness 128, leaving 476..604 open for door at y=540)
    _add_static_box(Vector2(1856 + m, 238), Vector2(128, 476))
    _add_static_box(Vector2(1856 + m, 842), Vector2(128, 476))
    if room_data.connections.has(Vector2i.RIGHT):
        spawn_door_at(Vector2(1852 + m, 540), Vector2i.RIGHT, PI/2.0)
    else:
        _add_static_box(Vector2(1856 + m, 540), Vector2(128, 128))

func _add_static_box(pos: Vector2, size: Vector2):
    var body = StaticBody2D.new()
    body.position = pos
    # Layer 3 is shared with obstacles; walls are also on layer 5, which
    # flying forms (Player.gd drops layer 3 to fly over obstacles) still hit
    body.collision_layer = 4 | 16
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
    door.era_dir = era_dir()
    door.open_light = era_look.get_look(current_floor).door_light
    
    var neighbor_pos = room_data.connections[d_dir]
    var parent = get_parent()
    var neighbor_type = parent.get_room_type(neighbor_pos) if (parent and parent.has_method("get_room_type")) else -1
    var is_visited = parent.is_room_visited(neighbor_pos) if (parent and parent.has_method("is_room_visited")) else false
    
    # Only the treasure room needs a key: one hides in one of the floor's
    # other rooms (LevelGenerator), and there is no other key anywhere
    if neighbor_type == 2 and not is_visited:
        door.is_locked = true
        
    add_child(door)
    door_nodes[d_dir] = door
    door.door_entered.connect(_on_door_entered)

func spawn_ambient_particles():
    var look = era_look.get_look(current_floor)
    var particle_color: Color = look.motes
    var glow_color = Color(particle_color.r, particle_color.g, particle_color.b, 0.12)
    
    if room_data:
        match room_data.type:
            2: # TREASURE
                particle_color = Color(0.0, 0.90, 0.70, 0.30) # Seafoam mint
                glow_color = Color(0.05, 0.80, 0.65, 0.14)
            4: # SHOP
                particle_color = Color(0.95, 0.80, 0.25, 0.30) # Soft golden amber
                glow_color = Color(0.85, 0.70, 0.20, 0.14)

    # Layer 1: Gentle bioluminescent plankton motes
    var particles = CPUParticles2D.new()
    particles.position = Vector2(960, 540)
    particles.amount = 40
    particles.lifetime = 6.0
    particles.preprocess = 4.0
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(960 + side_margin, 540)
    # Plankton drifts up, spores float about, ash settles
    particles.gravity = {"plankton": Vector2(0, -6), "spores": Vector2(3, 1), "ash": Vector2(2, 8)}.get(look.mote_kind, Vector2(0, -6))
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
    particles2.emission_rect_extents = Vector2(900 + side_margin, 480)
    particles2.gravity = Vector2(0, -2)
    particles2.initial_velocity_min = 2.0
    particles2.initial_velocity_max = 5.0
    particles2.scale_amount_min = 5.0
    particles2.scale_amount_max = 10.0
    particles2.color = glow_color
    particles2.z_index = -4
    add_child(particles2)

    if look.shafts.a > 0:
        if preload("res://data/ArtStyles.gd").keeps_floor(SettingsManager.art_style):
            spawn_light_shafts(look.shafts)
    if look.bubbles:
        spawn_bubble_streams()
    if look.mote_kind == "ash":
        spawn_embers()
    spawn_floor_light(look)
    if preload("res://data/ArtStyles.gd").keeps_floor(SettingsManager.art_style):
        spawn_passing_shadow(look)

# Soft sunlight rays slanting down from the surface, gently swaying.
# Additive polygons with vertex alpha: no shader, cheap on phones.
func spawn_light_shafts(tint: Color):
    var add_mat = CanvasItemMaterial.new()
    add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    var rng = RandomNumberGenerator.new()
    rng.seed = hash(room_data.grid_pos) if room_data else 0
    for i in 4:
        var shaft = Polygon2D.new()
        var x = rng.randf_range(300 - side_margin, 1620 + side_margin)
        var top_w = rng.randf_range(50, 110)
        var bottom_w = top_w * rng.randf_range(2.2, 3.2)
        var slant = rng.randf_range(120, 260)
        shaft.polygon = PackedVector2Array([
            Vector2(x - top_w, 110), Vector2(x + top_w, 110),
            Vector2(x + slant + bottom_w, 980), Vector2(x + slant - bottom_w, 980)])
        var c = tint
        var clear = Color(c.r, c.g, c.b, 0.0)
        shaft.vertex_colors = PackedColorArray([c, c, clear, clear])
        shaft.material = add_mat
        shaft.z_index = -6
        add_child(shaft)
        # Slow shimmer: fade in and out at different rates per shaft
        shaft.modulate.a = rng.randf_range(0.3, 1.0)
        var tw = shaft.create_tween().set_loops()
        tw.tween_property(shaft, "modulate:a", rng.randf_range(0.15, 0.4), rng.randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)
        tw.tween_property(shaft, "modulate:a", 1.0, rng.randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)

# A few thin columns of bubbles rising from the floor
func spawn_bubble_streams():
    var ramp = Gradient.new()
    ramp.set_color(0, Color(0.8, 0.95, 1.0, 0.0))
    ramp.add_point(0.15, Color(0.8, 0.95, 1.0, 0.45))
    ramp.set_color(1, Color(0.8, 0.95, 1.0, 0.0))
    var rng = RandomNumberGenerator.new()
    rng.seed = (hash(room_data.grid_pos) if room_data else 0) + 7
    for i in 3:
        var b = CPUParticles2D.new()
        b.position = Vector2(rng.randf_range(260 - side_margin, 1660 + side_margin), rng.randf_range(820, 940))
        b.amount = 8
        b.lifetime = 5.0
        b.preprocess = 5.0
        b.direction = Vector2.UP
        b.spread = 6.0
        b.gravity = Vector2(0, -12)
        b.initial_velocity_min = 50.0
        b.initial_velocity_max = 90.0
        b.scale_amount_min = 2.0
        b.scale_amount_max = 4.5
        b.color_ramp = ramp
        b.z_index = -5
        add_child(b)

# Sparks drifting up from far-off eruptions (end-Permian Siberian Traps)
func spawn_embers():
    var ramp = Gradient.new()
    ramp.set_color(0, Color(1.0, 0.6, 0.2, 0.0))
    ramp.add_point(0.2, Color(1.0, 0.55, 0.2, 0.8))
    ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
    var e = CPUParticles2D.new()
    e.position = Vector2(960, 1000)
    e.amount = 14
    e.lifetime = 7.0
    e.preprocess = 7.0
    e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    e.emission_rect_extents = Vector2(960 + side_margin, 40)
    e.direction = Vector2(0.3, -1)
    e.spread = 25.0
    e.gravity = Vector2(4, -10)
    e.initial_velocity_min = 30.0
    e.initial_velocity_max = 70.0
    e.scale_amount_min = 2.0
    e.scale_amount_max = 3.5
    e.color_ramp = ramp
    e.z_index = -5
    add_child(e)

# Light moving over the floor (data/EraLook.gd FLOOR_LIGHT_SHADER)
static var floor_light_shader: Shader = null

func spawn_floor_light(look: Dictionary):
    if not preload("res://data/ArtStyles.gd").keeps_floor(SettingsManager.art_style):
        return
    if floor_light_shader == null:
        floor_light_shader = Shader.new()
        floor_light_shader.code = era_look.FLOOR_LIGHT_SHADER
    var rect = ColorRect.new()
    rect.name = "FloorLight"
    rect.position = Vector2(-side_margin, 0)
    rect.size = Vector2(1920 + side_margin * 2, 1080)
    rect.z_index = -7
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat = ShaderMaterial.new()
    mat.shader = floor_light_shader
    mat.set_shader_parameter("tint", look.light)
    mat.set_shader_parameter("strength", look.light_power)
    mat.set_shader_parameter("mode", look.light_mode)
    mat.set_shader_parameter("rect_size", rect.size)
    rect.material = mat
    add_child(rect)

# Now and then something big passes overhead and its shadow slides over the
# floor: Anomalocaris, a nautiloid, Meganeura, or clouds
func spawn_passing_shadow(look: Dictionary):
    var path = era_dir() + "shadow.png"
    if not ResourceLoader.exists(path):
        return
    var s = Sprite2D.new()
    s.name = "PassingShadow"
    s.texture = load(path)
    s.z_index = -7
    s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # moved by a tween every frame
    s.modulate = Color(1, 1, 1, 0)
    add_child(s)
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    _pass_shadow(s, look, rng, rng.randf_range(2.0, 8.0))

func _pass_shadow(s: Sprite2D, look: Dictionary, rng: RandomNumberGenerator, wait: float):
    if not is_instance_valid(s) or not s.is_inside_tree():
        return
    var reach = side_margin + 500.0
    var a = Vector2(-reach, rng.randf_range(150, 930))
    var b = Vector2(1920 + reach, rng.randf_range(150, 930))
    if rng.randf() < 0.5:
        var tmp = a
        a = b
        b = tmp
    s.position = a
    s.scale = Vector2.ONE * look.shadow_scale * rng.randf_range(0.85, 1.15)
    s.rotation = (b - a).angle() + look.shadow_facing if look.shadow_turns else 0.0
    s.modulate.a = 0.0
    var dur = look.shadow_time * rng.randf_range(0.8, 1.25)
    var tw = s.create_tween()
    tw.tween_interval(wait)
    tw.tween_callback(func(): s.modulate.a = look.shadow_alpha)
    tw.tween_property(s, "position", b, dur)
    tw.tween_callback(_pass_shadow.bind(s, look, rng, rng.randf_range(8.0, 20.0)))

func spawn_layout_decals(layout: Dictionary):
    for decal in layout.get("decals", []):
        if decal["type"] == "decal_vent":
            continue # removed by request; old saved layouts may still list it
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
    frond_spots.clear()
    var tall_spots: Array = []
    for obs in layout.get("obstacles", []):
        var gx = obs["gx"]
        var gy = obs["gy"]
        var pos = Vector2(gx * 128 + 64, gy * 128 + 64 + 28)
        var raw_type = obs.get("type", "rock")
        var resolved_type = bio_obstacle_map.get(raw_type, raw_type)
        # Ediacaran fronds (Charnia) are animals, not scenery: set aside
        if is_frond_era() and Obstacle.ERA_SLOT.get(resolved_type, "") == "tall":
            tall_spots.append(pos)
            continue
        spawn_obstacle(pos, resolved_type)
    place_fronds(tall_spots)

func spawn_obstacle(pos: Vector2, type_name: String):
    var obs_node = obstacle_scene.instantiate()
    obs_node.position = pos
    add_child(obs_node)
    obs_node.setup_obstacle(type_name, era_dir())

# The Ediacaran "tall" scenery is Charnia, a frond that was an animal, so
# it is an enemy (Enemy.gd "frond"), not an obstacle. kuro (2026-11-23):
# the fronds looked like enemies, so make them one. A fight room keeps up
# to FROND_CAP of its frond spots as Charnia; the rest, and the spots in
# rooms without a fight, become stromatolite mounds. The pick is seeded by
# the room so a revisit puts everything back in the same place. A cleared
# room's Charnia were eaten, so their spots stay empty.
const FROND_CAP := 3
var frond_spots: Array = []

func is_frond_era() -> bool:
    return era_dir().ends_with("/ediacaran/")

func place_fronds(spots: Array):
    if spots.is_empty():
        return
    var rng = RandomNumberGenerator.new()
    rng.seed = hash(room_data.grid_pos) if room_data else 1
    for i in range(spots.size() - 1, 0, -1):
        var j = rng.randi_range(0, i)
        var t = spots[i]
        spots[i] = spots[j]
        spots[j] = t
    var fight = room_data != null and room_data.type == 1
    for i in spots.size():
        if fight and i < FROND_CAP:
            if not room_data.cleared:
                frond_spots.append(spots[i])
        else:
            spawn_obstacle(spots[i], "stromatolite")

# After the room's other animals, so fronds don't take their places
func spawn_fronds(floor_number: int):
    var player_node = get_tree().get_first_node_in_group("player")
    for pos in frond_spots:
        # Never right where you come in
        if player_node and pos.distance_to(player_node.global_position - global_position) < 260.0:
            continue
        spawn_enemy(pos, "frond", floor_number)
        var e = active_enemies.back()
        if is_instance_valid(e) and e.enemy_type == "frond":
            # The enemy's middle is up the frond; its holdfast sits on the spot
            e.position = pos - Enemy.FROND_ROOT

# A gap you can see through should be one you can walk through (kuro,
# 2026-11-23). Any gap between neighbouring scenery, or between scenery and
# the wall, that is too narrow for the player (56 px across, the same for
# every form) gets a bank of pebbles that visibly closes it. Gaps at least
# PASS_GAP wide stay open. Only next-door neighbours are joined, so the
# routes between diagonal neighbours (always wide) stay open.
const PASS_GAP := 64.0
func close_tight_gaps():
    var obs: Array = []
    for c in get_children():
        if c.is_in_group("obstacles") and c.has_method("outline_points"):
            obs.append(c)
    # Scenery to wall
    var inner = interior_rect()
    var walled := {} # obstacle -> [sides it is joined to the wall on]
    for o in obs:
        var r: Rect2 = o.footprint_rect()
        var mid = r.get_center()
        var sides: Array = []
        # A bank as wide as the thing it joins, so it leaves no hollow
        var wide = clampf(r.size.x, 40.0, 100.0)
        var tall = clampf(r.size.y, 40.0, 100.0)
        if r.position.y - inner.position.y < PASS_GAP:
            add_rubble(Vector2(mid.x, r.position.y + 4.0), Vector2(mid.x, inner.position.y - 6.0), wide)
            sides.append(Vector2i.UP)
        if inner.end.y - r.end.y < PASS_GAP:
            add_rubble(Vector2(mid.x, r.end.y - 4.0), Vector2(mid.x, inner.end.y + 6.0), wide)
            sides.append(Vector2i.DOWN)
        if r.position.x - inner.position.x < PASS_GAP:
            add_rubble(Vector2(r.position.x + 4.0, mid.y), Vector2(inner.position.x - 6.0, mid.y), tall)
            sides.append(Vector2i.LEFT)
        if inner.end.x - r.end.x < PASS_GAP:
            add_rubble(Vector2(r.end.x - 4.0, mid.y), Vector2(inner.end.x + 6.0, mid.y), tall)
            sides.append(Vector2i.RIGHT)
        walled[o] = sides
    # Scenery to scenery
    for i in obs.size():
        for j in range(i + 1, obs.size()):
            var o1 = obs[i]
            var o2 = obs[j]
            if o1.position.distance_to(o2.position) > 150.0:
                continue
            var best := INF
            var p1 := Vector2.ZERO
            var p2 := Vector2.ZERO
            var pts2 = o2.outline_points()
            for q1 in o1.outline_points():
                for q2 in pts2:
                    var d = q1.distance_to(q2)
                    if d < best:
                        best = d
                        p1 = q1
                        p2 = q2
            if best >= PASS_GAP:
                continue
            add_rubble(p1, p2)
            # Two neighbours both joined to the same wall and to each other
            # would wall in a little hollow between them: fill it too
            for side in walled[o1]:
                if side in walled[o2]:
                    var m = (p1 + p2) * 0.5
                    var to = Vector2(m.x, inner.position.y - 6.0)
                    match side:
                        Vector2i.DOWN: to = Vector2(m.x, inner.end.y + 6.0)
                        Vector2i.LEFT: to = Vector2(inner.position.x - 6.0, m.y)
                        Vector2i.RIGHT: to = Vector2(inner.end.x + 6.0, m.y)
                    add_rubble(m, to)

func add_rubble(from: Vector2, to: Vector2, thickness: float = 40.0):
    # Reach a little into each side so no notch is left to snag on
    var dir = (to - from).normalized()
    var rb = StaticBody2D.new()
    rb.set_script(preload("res://Rubble.gd"))
    rb.name = "Rubble"
    add_child(rb)
    rb.setup(from - dir * 6.0, to + dir * 6.0, thickness)

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
            
        spawn_enemy(pos, roll_enemy_type(sp.get("type", "fly"), floor_number), floor_number)
        
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
            
        spawn_enemy(cand_pos, roll_enemy_type("fly" if randf() < 0.55 else "pacer", floor_number), floor_number)

    maybe_promote_elder(floor_number)

# From the second era on, a fight room may hold one big old animal
# (Enemy.make_elder): tougher, circled in ink, and it always leaves a pickup
func maybe_promote_elder(floor_number: int):
    if floor_number < 2 or randf() > 0.12 + 0.06 * floor_number:
        return
    var picks = active_enemies.filter(func(e): return e.enemy_type not in ["swarm", "frond", "colony", "skittish"])
    if picks.is_empty():
        return
    picks.pick_random().make_elder()

# About a third of spawns become one of the era's special animals
# (data/Fauna.gd: the third and fourth animal of each era)
# A behaviour type, or "type@Species" for one of the era's extra animals
# (Fauna.EXTRAS), which spawn_enemy splits apart
func roll_enemy_type(base: String, floor_number: int) -> String:
    var extras: Array = fauna.extras(floor_number)
    if not extras.is_empty() and randf() < EXTRA_CHANCE:
        var sp: Dictionary = extras.pick_random()
        return "%s@%s" % [sp.type, sp.name]
    var specials = fauna.special_types(floor_number).filter(func(t): return t != "frond")
    if not specials.is_empty() and randf() < 0.36:
        return specials.pick_random()
    return base

const EXTRA_CHANCE := 0.34

func spawn_enemy(pos: Vector2, type: String, floor_number: int):
    var species := ""
    if "@" in type:
        species = type.get_slice("@", 1)
        type = type.get_slice("@", 0)
    # Roachoids and beetles come as a pack of four
    var count = 4 if type == "swarm" else 1
    for i in count:
        var enemy = enemy_scene.instantiate()
        enemy.position = free_spot(pos + (Vector2.RIGHT.rotated(TAU * i / count) * 50.0 if count > 1 else Vector2.ZERO))
        enemy.enemy_type = type
        enemy.species_name = species
        enemy.setup_enemy(floor_number)
        add_child(enemy)
        active_enemies.append(enemy)
        enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

# One real animal per era, each drawn and animated in code (bosses/)
const BOSSES = {
    1: "res://bosses/Stentor.gd",
    2: "res://bosses/Anomalocaris.gd",
    3: "res://bosses/Cameroceras.gd",
    4: "res://bosses/Arthropleura.gd",
    5: "res://bosses/Dimetrodon.gd",
}

# Or, half the time, a giant drawn with the playable forms' drawings
# (bosses/DrawnBoss.gd). The pick holds for the whole floor.
const ALT_BOSS := "res://bosses/DrawnBoss.gd"

func pick_boss_script(floor_number: int) -> String:
    var main = get_parent()
    var key = "boss_pick_%d" % floor_number
    var forced = OS.get_environment("BOSS_ALT")
    if forced != "":
        return ALT_BOSS if forced == "1" else BOSSES.get(clampi(floor_number, 1, 5))
    if main and not main.has_meta(key):
        main.set_meta(key, randf() < 0.5)
    var alt = main.get_meta(key) if main else false
    return ALT_BOSS if alt else BOSSES.get(clampi(floor_number, 1, 5))

func spawn_boss(floor_number: int):
    var boss = load(pick_boss_script(floor_number)).new()
    # Away from the door the player came through, never on top of them
    boss.position = Vector2(960, 540) + Vector2(entry_dir) * Vector2(420.0 + side_margin * 0.5, 220.0)
    boss.setup_enemy(floor_number)
    add_child(boss)
    active_enemies.append(boss)
    boss.enemy_died.connect(_on_enemy_died.bind(boss))

    get_parent().register_boss(boss)

func spawn_treasure_pedestal():
    var ped = pedestal_scene.instantiate()
    ped.position = Vector2(960, 540)
    # Something not yet found this run (data/Items.gd)
    var player = get_tree().get_first_node_in_group("player")
    var chosen_item = preload("res://data/Items.gd").roll(player.items_found if player else [])
    ped.item_id = chosen_item
    room_data.treasure_item_id = chosen_item
    add_child(ped)

# From era 2, about half the fight rooms have two patches of hazard ground:
# brine pools at sea, peat bog in the coal swamps, gas vents in the Permian.
# Rolled once per room and kept, so a revisit looks the same.
func spawn_hazards(floor_number: int):
    if not room_data.hazards_rolled:
        room_data.hazards_rolled = true
        if floor_number >= 2 and randf() < 0.45:
            room_data.hazards = roll_hazards(floor_number)
    var kind = preload("res://Hazard.gd").kind_for_floor(floor_number)
    for h in room_data.hazards:
        var hz = preload("res://Hazard.gd").new()
        hz.kind = kind
        hz.position = h.pos
        hz.size = h.size
        hz.seed_val = h.seed
        add_child(hz)

func roll_hazards(floor_number: int) -> Array:
    var out: Array = []
    var vent = floor_number >= 5
    var doors = [Vector2(960, 68), Vector2(960, 1012), Vector2(128 - side_margin, 540), Vector2(1792 + side_margin, 540)]
    var area = interior_rect(110.0)
    for attempt in 60:
        if out.size() >= 2:
            break
        var sz = Vector2(95, 66) if vent else Vector2(randf_range(130, 190), randf_range(80, 110))
        var pos = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
        var ok = spot_is_free(pos, sz.x * 0.75)
        for d in doors:
            if pos.distance_to(d) < 330.0:
                ok = false
        for h in out:
            if pos.distance_to(h.pos) < sz.x + h.size.x + 60.0:
                ok = false
        if ok:
            out.append({"pos": pos, "size": sz, "seed": randi()})
    return out

func spawn_seep():
    var seep = preload("res://MineralSeep.gd").new()
    seep.position = Vector2(960, 540)
    seep.floor_num = current_floor
    seep.spot_seed = room_data.grid_pos.x * 31 + room_data.grid_pos.y * 977
    seep.used = room_data.seep_used
    var data = room_data
    seep.on_used = func(): data.seep_used = true
    add_child(seep)

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
        {"item_id": preload("res://data/Items.gd").roll([]), "price": 15, "pos": Vector2(1200, 540), "collected": false}
    ]
    room_data.shop_inventory = shop_defs.duplicate(true)
    
    for item_def in room_data.shop_inventory:
        var ped = pedestal_scene.instantiate()
        ped.position = item_def["pos"]
        ped.item_id = item_def["item_id"]
        ped.is_shop_item = true
        ped.price = item_def["price"]
        add_child(ped)

# The open floor inside the walls (side margins included)
func interior_rect(pad: float = 0.0) -> Rect2:
    return Rect2(128 - side_margin + pad, 128 + pad, 1664 + side_margin * 2.0 - pad * 2.0, 824 - pad * 2.0)

func spot_is_free(pos: Vector2, radius: float = 40.0) -> bool:
    if not interior_rect(radius).has_point(pos):
        return false
    for c in get_children():
        if c.is_in_group("obstacles") and not c.is_queued_for_deletion() and c.position.distance_to(pos) < 44.0 + radius:
            return false
    return true

# Nearest open floor to pos, so nothing starts (or ends up) inside a rock or
# a wall where shots cannot reach it and the room could never be cleared
func free_spot(pos: Vector2, radius: float = 40.0) -> Vector2:
    if spot_is_free(pos, radius):
        return pos
    for ring in range(1, 10):
        var steps = 8 * ring
        for s in steps:
            var cand = pos + Vector2.RIGHT.rotated(TAU * s / steps) * ring * 48.0
            if spot_is_free(cand, radius):
                return cand
    var r = interior_rect(radius)
    return Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))

# Safety net for "defeat every creature" rooms: forget animals that are gone,
# pull back any stuck in a rock or outside the walls, and open the doors once
# nobody is left, whichever way the last one went
var _watch_timer: float = 0.0

func _process(delta: float):
    # Boss rooms too: if the boss is gone (or never spawned) the doors still open
    if room_data == null or room_data.cleared or not room_data.type in [1, 3]:
        return
    _watch_timer -= delta
    if _watch_timer > 0.0:
        return
    _watch_timer = 0.5
    active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and not e.dead)
    for e in active_enemies:
        # Bosses keep themselves inside their arena
        if e.is_boss() or e.is_burrowed():
            continue
        if not spot_is_free(e.position, 8.0):
            e.position = free_spot(e.position)
    if active_enemies.is_empty():
        clear_room()

func _on_enemy_died(enemy):
    active_enemies.erase(enemy)

    if randf() < 0.35 or enemy.get("elder"):
        spawn_random_pickup(enemy.global_position)

    if active_enemies.size() == 0 and not room_data.cleared:
        clear_room()

func spawn_random_pickup(pos: Vector2):
    var p = pickup_scene.instantiate()
    p.position = pos
    
    var roll = randf()
    # No keys here: each locked floor hides exactly one (LevelGenerator)
    if roll < 0.7:
        p.pickup_type = "coin"
    else:
        p.pickup_type = "heart" if randf() < 0.7 else "heart_half"
        
    add_child(p)

# The commotion draws more animals: when the room falls quiet, a second
# group comes in through the doors farthest from you, already hunting
var wave_pending: bool = false
var had_wave: bool = false # a room that drew a second group always pays out

func start_wave():
    wave_pending = true
    had_wave = true
    room_data.waves_left -= 1
    var player_node = get_tree().get_first_node_in_group("player")
    var ppos = player_node.global_position if player_node else Vector2(960, 540)
    var inward = {Vector2i.UP: Vector2(0, 170), Vector2i.DOWN: Vector2(0, -170), Vector2i.LEFT: Vector2(170, 0), Vector2i.RIGHT: Vector2(-170, 0)}
    var spots: Array = []
    for d in door_nodes:
        spots.append(door_nodes[d].position + inward.get(d, Vector2.ZERO))
    if spots.is_empty():
        spots.append(Vector2(960, 300))
    spots.sort_custom(func(a, b): return a.distance_to(ppos) > b.distance_to(ppos))
    spots = spots.slice(0, 2)
    for sp in spots:
        HitFX.pop(self, sp, Color(0.9, 0.75, 0.55), 30.0, 200.0, 0.5)
    if player_node and player_node.has_method("popup_text"):
        player_node.popup_text(ppos + Vector2(0, -70), "MORE ARE COMING!", Color(1.0, 0.75, 0.45))
    SoundManager.play_sfx("boss_roar", 1.6, -10.0)
    await get_tree().create_timer(1.1, false).timeout
    if not is_inside_tree() or player_node == null or player_node.health <= 0:
        wave_pending = false
        return
    var count = 2 + current_floor / 2
    for i in count:
        var sp: Vector2 = spots[i % spots.size()] + Vector2(randf_range(-50, 50), randf_range(-50, 50))
        spawn_enemy(free_spot(sp), roll_enemy_type("fly" if randf() < 0.55 else "pacer", current_floor), current_floor)
    for e in active_enemies:
        if is_instance_valid(e) and e.has_method("become_hostile"):
            e.become_hostile()
    wave_pending = false

func clear_room():
    if room_data.cleared or wave_pending:
        return
    if room_data.type == 1 and room_data.waves_left > 0 and active_enemies.is_empty():
        start_wave()
        return
    room_data.cleared = true
    SoundManager.play_sfx("room_clear")
    if special_node and is_instance_valid(special_node):
        special_node.on_cleared()
    var m = get_parent()
    if room_data.type == 1 and m and m.has_method("field_event"):
        if not m.hit_this_room:
            m.field_event("nohit")
        if had_wave:
            m.field_event("wave")
    var player_node = get_tree().get_first_node_in_group("player")
    if player_node and player_node.has_method("on_room_cleared"):
        player_node.on_room_cleared()
    
    for d_dir in door_nodes:
        door_nodes[d_dir].open_door()
        
    if room_data.type == 1:
        if randf() < 0.65 or had_wave:
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
        if is_instance_valid(body) and body.is_in_group("player"):
            get_parent().advance_floor()
    , CONNECT_DEFERRED)

func _on_door_entered(direction):
    room_transition_requested.emit(direction)
