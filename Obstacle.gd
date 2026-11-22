# Obstacle.gd
extends StaticBody2D

@export var obstacle_type: String = "rock"

var light_node: PointLight2D = null

# Layout obstacle types map onto the five art slots each era has
const ERA_SLOT = {
    "rock": "rock", "coral_spire": "tall", "ediacaran_frond": "tall",
    "stromatolite": "mound", "calcified_sponge": "mound",
    "biocrystal": "glow", "hydrothermal_vent": "glow", "fossil_bone": "fossil",
}
const ERA_LIGHT = {
    "glow": [Color(0.4, 1.0, 0.9), 1.1], "tall": [Color(0.5, 0.8, 1.0), 0.45],
}
# Each era's glowing thing (generate_scenery_art.py): oxygen bubbles on a
# mat, a glass sponge, a calcite geode, glowing fungus, a lava fissure
const GLOW_COLORS = {
    "ediacaran": Color(0.6, 1.0, 0.85), "cambrian": Color(0.65, 0.9, 1.0),
    "ordovician": Color(0.6, 0.75, 1.0), "carboniferous": Color(0.7, 1.0, 0.45),
    "permian": Color(1.0, 0.5, 0.2),
}
# Which scenery sways in the current (fronds, sea lilies, ferns, trees):
# [era, slot] -> sway strength. Rocks, cups and stumps stay put.
const SWAY = {
    "ediacaran/tall": 0.09, "cambrian/mound": 0.04, "ordovician/tall": 0.12,
    "carboniferous/mound": 0.05, "carboniferous/tall_2": 0.06,
    "permian/tall": 0.05, "permian/mound": 0.04,
}
const SWAY_SHADER = """
shader_type canvas_item;
uniform float amount = 0.0;
uniform float phase = 0.0;
uniform float flash = 0.0;
uniform float push = 0.0;   // a body brushing past bends it (Obstacle._process)
uniform float gust_x = 0.0; // world x, so gusts roll across the room
void vertex() {
    // The top of the sprite sways, the base (footprint) stays put. A slow
    // swell, a quicker flutter on top, and now and then a gust of current
    // that rolls across the whole room from left to right.
    float up = clamp(-VERTEX.y / 100.0, 0.0, 1.0);
    float gust = pow(max(0.0, sin(TIME * 0.31 - gust_x * 0.0028)), 6.0);
    float s = sin(TIME * 1.3 + phase) + 0.35 * sin(TIME * 3.1 + phase * 1.7);
    VERTEX.x += (s * (1.0 + gust) + gust * 1.6 + push * 3.0) * amount * 160.0 * up * up;
    VERTEX.y += abs(push) * amount * 40.0 * up; // bending also shortens it
}
void fragment() {
    // Fine flutter in the fronds, strongest at the tips
    float tip = clamp(1.0 - UV.y, 0.0, 1.0);
    vec2 uv = UV + vec2(sin(UV.y * 38.0 + TIME * 2.6 + phase) * 0.0035 * amount * 10.0 * tip * tip, 0.0);
    vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * COLOR;
    COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
static var sway_shader: Shader
var era_name: String = ""
var slot_name: String = ""
var glow_phase: float = 0.0
var base_energy: float = 0.0

func setup_obstacle(type_name: String = "rock", era_dir: String = ""):
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
            
    # Era art (generate_room_art.py) replaces the generic look when present
    var slot = ERA_SLOT.get(obstacle_type, "rock")
    if era_dir != "" and ResourceLoader.exists(era_dir + slot + ".png"):
        era_name = era_dir.trim_suffix("/").get_file()
        # Two painted variants of most scenery; mirror some for variety
        if randf() < 0.5 and ResourceLoader.exists(era_dir + slot + "_2.png"):
            slot += "_2"
        tex_path = era_dir + slot + ".png"
        var l = ERA_LIGHT.get(slot.trim_suffix("_2"), [Color(0, 0, 0), 0.0])
        light_color = GLOW_COLORS.get(era_name, l[0]) if slot.begins_with("glow") else l[0]
        light_energy = l[1]
        # Newer 160 px scenery has its footprint 20 px below the middle
        if load(tex_path).get_width() == 160:
            sprite.offset = Vector2(0, -20)
            sprite.scale = Vector2.ONE * (1.4 if slot.begins_with("tall") else 1.2)
        sprite.flip_h = randf() < 0.5 and not slot.begins_with("fossil")
        slot_name = slot
        setup_sway(sprite, SWAY.get(era_name + "/" + slot, SWAY.get(era_name + "/" + slot.trim_suffix("_2"), 0.0)))
    sprite.texture = load(tex_path)
    
    if light_energy > 0:
        if not light_node:
            light_node = PointLight2D.new()
            light_node.texture = load("res://assets/light.png")
            light_node.scale = Vector2(1.1, 1.1)
            add_child(light_node)
        light_node.color = light_color
        light_node.energy = light_energy
        base_energy = light_energy
        glow_phase = randf() * TAU
    if slot_name.begins_with("glow"):
        add_glow_particles()

func setup_sway(sprite: Sprite2D, amount: float):
    if sway_shader == null:
        sway_shader = Shader.new()
        sway_shader.code = SWAY_SHADER
    var mat = ShaderMaterial.new()
    mat.shader = sway_shader
    mat.set_shader_parameter("amount", amount)
    mat.set_shader_parameter("phase", position.x * 0.013 + position.y * 0.007)
    mat.set_shader_parameter("gust_x", position.x)
    sprite.material = mat
    sway_mat = mat

var sway_mat: ShaderMaterial = null
var _push: float = 0.0
var _push_v: float = 0.0
var _bodies: Array = []
var _scan_t: float = 0.0

# Swaying scenery leans away from anything brushing past, then springs back
func update_push(delta: float):
    _scan_t -= delta
    if _scan_t <= 0.0:
        # Re-list nearby bodies a few times a second; cheap on phones
        _scan_t = 0.25
        _bodies.clear()
        for g in ["player", "enemies"]:
            for n in get_tree().get_nodes_in_group(g):
                if n is Node2D and n.global_position.distance_squared_to(global_position) < 260.0 * 260.0:
                    _bodies.append(n)
    var want = 0.0
    for n in _bodies:
        if not is_instance_valid(n):
            continue
        var off: Vector2 = global_position - n.global_position
        off.y += 40.0 # bodies brush the stem, not the top
        var d = off.length()
        if d < 150.0:
            want += sign(off.x) * (1.0 - d / 150.0) * (1.0 if n.is_in_group("player") else 0.7)
    want = clamp(want, -1.0, 1.0)
    _push_v += ((want - _push) * 90.0 - _push_v * 9.0) * delta
    _push += _push_v * delta
    sway_mat.set_shader_parameter("push", _push)

# Glowing scenery breathes: the light pulses and something drifts off it
func _process(delta: float):
    if sway_mat and float(sway_mat.get_shader_parameter("amount")) > 0.0:
        update_push(delta)
    if light_node and base_energy > 0.0 and slot_name.begins_with("glow"):
        glow_phase += delta
        light_node.energy = base_energy * (0.85 + 0.15 * sin(glow_phase * 1.7) + (0.12 * sin(glow_phase * 7.3) if era_name == "permian" else 0.0))

func add_glow_particles():
    var p = CPUParticles2D.new()
    p.position = Vector2(0, -10)
    p.amount = 5
    p.lifetime = 2.4
    p.preprocess = 2.4
    p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    p.emission_rect_extents = Vector2(28, 6)
    p.direction = Vector2(0, -1)
    p.spread = 15.0
    p.gravity = Vector2.ZERO
    p.initial_velocity_min = 14.0
    p.initial_velocity_max = 30.0
    p.scale_amount_min = 2.0
    p.scale_amount_max = 4.5
    var fade = Gradient.new()
    var col: Color = GLOW_COLORS.get(era_name, Color(0.7, 1.0, 0.9))
    match era_name:
        "ediacaran", "cambrian", "ordovician":
            # Bubbles rising through the water
            col = Color(0.85, 1.0, 1.0)
        "carboniferous":
            # Drifting spores
            p.initial_velocity_min = 6.0
            p.initial_velocity_max = 14.0
            p.spread = 60.0
        "permian":
            # Embers from the lava
            col = Color(1.0, 0.6, 0.2)
            p.amount = 7
            p.lifetime = 1.4
            p.initial_velocity_max = 50.0
    fade.set_color(0, Color(col.r, col.g, col.b, 0.0))
    fade.add_point(0.2, Color(col.r, col.g, col.b, 0.75))
    fade.set_color(1, Color(col.r, col.g, col.b, 0.0))
    p.color_ramp = fade
    add_child(p)

# Scenery can't be broken (kuro, 2026-11-22): hits flash, wobble and chip it,
# and stop the shot, but the rock, frond or vent always stays standing
func take_damage(_amount: float):
    var sprite = get_node_or_null("Sprite2D")
    if sprite:
        sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
        var tw = create_tween()
        tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
        var wob = create_tween()
        sprite.rotation = randf_range(-0.09, 0.09)
        wob.tween_property(sprite, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    # Swaying scenery also gets knocked back a little, then springs upright
    if sway_mat:
        _push_v += randf_range(-6.0, 6.0)
    spawn_hit_chip_fx()
    SoundManager.play_sfx("hit", 0.8, -4.0)

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
