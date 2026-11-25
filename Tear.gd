# Tear.gd
extends Area2D

@export var speed: float = 680.0
@export var damage: float = 3.5
@export var lifetime: float = 0.85
@export var is_enemy_tear: bool = false
var shooter_name: String = "" # the animal that spat it, for "killed by"
@export var is_snare: bool = false # velvet-worm slime: slows instead of hurting
# Player weapon this projectile belongs to (data/Lineages.gd WEAPONS), e.g. "vesicle"
@export var projectile_kind: String = ""

# Projectile art in assets/projectiles/<kind>.png and the glow it casts.
# Pointed kinds face their flight direction instead of spinning.
const PROJECTILE_GLOW = {
    "vesicle": Color(1.0, 0.45, 0.7), "jet": Color(0.55, 0.85, 1.0), "spit": Color(0.75, 1.0, 0.2),
    "harpoon": Color(1.0, 0.9, 0.7), "slime": Color(0.8, 1.0, 0.85), "silk": Color(0.95, 0.95, 1.0),
    "spray": Color(1.0, 0.65, 0.15),
}
const POINTED = ["jet", "spit", "harpoon", "silk", "spray"]

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
# Size the shot was fired at (splits are smaller); spawn pop and end fade scale it
var base_scale: Vector2 = Vector2.ONE
var age: float = 0.0
const HitFX = preload("res://HitFX.gd")
# Lysosomes (the cell's "vesicle" shots) are drawn here in code as membrane
# sacs, not from a picture. At a cell's size water is thick as syrup (low
# Reynolds number), so a released sac coasts only a short way and stops:
# speed falls by e every 1/VESICLE_DRAG s. On contact it fuses with the
# prey's surface and its hydrolases keep digesting: DIGEST_TICKS more bites
# of DIGEST_SHARE of the hit each, DIGEST_GAP s apart.
const VESICLE_DRAG := 5.0
const DIGEST_TICKS := 3
const DIGEST_SHARE := 0.35
const DIGEST_GAP := 0.32
var is_vesicle: bool = false
var _wob: float = 0.0

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
        if is_snare:
            $Sprite2D.modulate = Color(0.85, 1.0, 0.75)
            if has_node("PointLight2D"):
                $PointLight2D.color = Color(0.6, 1.0, 0.5)
            if has_node("TrailParticles"):
                $TrailParticles.color = Color(0.8, 1.0, 0.7, 0.6)
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
        var art = "res://assets/projectiles/%s.png" % projectile_kind
        if projectile_kind != "" and ResourceLoader.exists(art):
            $Sprite2D.texture = load(art)
            $Sprite2D.hframes = 1
            var glow: Color = PROJECTILE_GLOW.get(projectile_kind, Color(0.0, 0.95, 1.0))
            if has_node("PointLight2D"):
                $PointLight2D.color = glow
            if has_node("TrailParticles"):
                $TrailParticles.color = Color(glow.r, glow.g, glow.b, 0.5)

    is_vesicle = projectile_kind == "vesicle" and not is_enemy_tear
    if is_vesicle:
        # No comet tail and no glow sprite: a sac drifting through water
        $Sprite2D.visible = false
        if has_node("TrailParticles"):
            $TrailParticles.emitting = false
        if has_node("PointLight2D"):
            $PointLight2D.energy = 0.5
        _wob = randf() * TAU
    elif has_node("TrailParticles"):
        setup_trail($TrailParticles)

    if velocity == Vector2.ZERO:
        velocity = direction.normalized() * speed
    base_scale = scale
    
    # Deferred: reacting can add/remove physics nodes, which Godot forbids mid physics step
    body_entered.connect(_on_body_entered, CONNECT_DEFERRED)

# Glowing comet tail: a soft additive streak stretched behind the shot along
# its flight, plus the particle trail as round fading dots instead of hard
# square specks. One extra quad per shot, so it stays cheap on phones.
# Textures, material and curves are built once and shared.
const STREAK_W = 64
const STREAK_H = 16
static var dot_texture: GradientTexture2D
static var streak_texture: ImageTexture
static var additive: CanvasItemMaterial
static var fade_ramp: Gradient
static var shrink_curve: Curve
var streak: Sprite2D

static func build_trail_resources():
    var g = Gradient.new()
    g.set_color(0, Color(1, 1, 1, 1))
    g.set_color(1, Color(1, 1, 1, 0))
    dot_texture = GradientTexture2D.new()
    dot_texture.gradient = g
    dot_texture.fill = GradientTexture2D.FILL_RADIAL
    dot_texture.fill_from = Vector2(0.5, 0.5)
    dot_texture.fill_to = Vector2(1.0, 0.5)
    dot_texture.width = 32
    dot_texture.height = 32
    # Bright at the head (right edge), fading to nothing at the tail
    var img = Image.create(STREAK_W, STREAK_H, false, Image.FORMAT_RGBA8)
    for x in STREAK_W:
        var along = pow(float(x) / (STREAK_W - 1), 1.6)
        for y in STREAK_H:
            var across = 1.0 - abs(y - (STREAK_H - 1) / 2.0) / (STREAK_H / 2.0)
            img.set_pixel(x, y, Color(1, 1, 1, along * across * across))
    streak_texture = ImageTexture.create_from_image(img)
    additive = CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    fade_ramp = Gradient.new()
    fade_ramp.set_color(0, Color(1, 1, 1, 1))
    fade_ramp.set_color(1, Color(1, 1, 1, 0))
    shrink_curve = Curve.new()
    shrink_curve.add_point(Vector2(0, 1))
    shrink_curve.add_point(Vector2(1, 0.3))

func setup_trail(p: CPUParticles2D):
    if dot_texture == null:
        build_trail_resources()
    p.texture = dot_texture
    p.material = additive
    p.color_ramp = fade_ramp
    p.scale_amount_curve = shrink_curve
    p.scale_amount_min = 0.5
    p.scale_amount_max = 0.7
    streak = Sprite2D.new()
    streak.texture = streak_texture
    streak.material = additive
    streak.centered = false
    streak.offset = Vector2(-STREAK_W, -STREAK_H / 2.0)
    # A short, faint wake behind the shot rather than a laser beam
    streak.modulate = Color(p.color.r, p.color.g, p.color.b, 0.45).lerp(Color(1, 1, 1, 0.45), 0.2)
    streak.show_behind_parent = true
    add_child(streak)
    move_child(streak, 0)

func update_streak():
    if streak == null:
        return
    # Tail length follows speed: about a sixth of a second of flight
    var length = clamp(velocity.length() * 0.07, 20.0, 55.0)
    streak.rotation = velocity.angle()
    streak.scale = Vector2(length / STREAK_W, 1.1)

func _physics_process(delta: float):
    if is_homing and not is_enemy_tear:
        var enemies = get_tree().get_nodes_in_group("enemies")
        var closest: Node2D = null
        var closest_dist: float = 420.0
        for e in enemies:
            if is_instance_valid(e) and not e.get("dead") and not (e.has_method("is_burrowed") and e.is_burrowed()):
                var d = global_position.distance_to(e.global_position)
                if d < closest_dist:
                    closest_dist = d
                    closest = e
        if closest:
            var target_dir = (closest.global_position - global_position).normalized()
            velocity = velocity.lerp(target_dir * speed, delta * 7.5)

    if is_vesicle:
        velocity *= exp(-VESICLE_DRAG * delta)
        _wob += delta * 9.0
        queue_redraw()
    position += velocity * delta
    update_streak()
    if projectile_kind in POINTED and not is_enemy_tear:
        $Sprite2D.rotation = velocity.angle()
    else:
        $Sprite2D.rotation += (3.0 if projectile_kind != "" else 8.0) * delta
    if not is_enemy_tear and $Sprite2D.hframes > 1:
        $Sprite2D.frame = int(fmod(lifetime * 14.0, 3.0))
        
    if is_boomerang:
        if lifetime < initial_lifetime * 0.55:
            var p_node = get_tree().get_first_node_in_group("player")
            if p_node and is_instance_valid(p_node):
                var to_p = (p_node.global_position - global_position).normalized()
                velocity = velocity.lerp(to_p * speed * 1.3, delta * 9.0)

    # Shots pop out a little big, settle, and shrink away at the end of their
    # range instead of vanishing
    age += delta
    var s = 1.0
    if age < 0.08:
        s = lerp(1.45, 1.0, age / 0.08)
    if lifetime < 0.15:
        s *= max(0.0, lifetime / 0.15)
    scale = base_scale * s


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
@export var is_blinding: bool = false # spitting venom: the enemy can't aim for a while
var has_split: bool = false
var initial_lifetime: float = 0.85

func _on_body_entered(body: Node):
    if not is_instance_valid(body) or is_queued_for_deletion():
        return
    if is_enemy_tear:
        if body.is_in_group("player") and is_snare:
            body.apply_slow(2.0, 0.5, "SNARED")
            destroy_tear()
        elif body.is_in_group("player") and body.has_method("take_damage"):
            # Touch: feelers sometimes feel the shot coming and brush it aside
            if body.has_method("feelers_deflect") and body.get("invincibility_time") <= 0 and body.feelers_deflect():
                SoundManager.play_sfx("hit_glance", randf_range(1.2, 1.4), -6.0)
                get_tree().call_group("sense_hints", "felt_shot", global_position, velocity)
                destroy_tear()
                return
            body.take_damage(damage, shooter_name)
            destroy_tear()
        elif body.is_in_group("obstacles") or body.is_in_group("walls"):
            destroy_tear()
    else:
        if body.is_in_group("enemies") and body.has_method("take_damage"):
            var flight = velocity.normalized()
            var punch = clamp(damage / 3.5, 0.7, 1.8)
            SoundManager.play_hit(body.body_material() if body.has_method("body_material") else "soft")
            HitFX.impact(get_parent(), global_position, flight, shot_color(), punch)
            # The shot's own splash: a burst vesicle, a splash of venom, a harpoon's puncture
            HitFX.strike(get_parent(), global_position, flight, projectile_kind, shot_color(), 13.0 + 6.0 * punch)
            body.take_damage(damage)
            if is_vesicle:
                digest(body)

            if knockback_force > 0 and body.has_method("apply_knockback"):
                body.apply_knockback(flight * knockback_force, 0.3)
            elif body.has_method("apply_hit_push"):
                # Every shot shoves a little, so hits read as solid
                body.apply_hit_push(flight * 230.0 * punch)
            var main = get_tree().get_first_node_in_group("main")
            if main and main.has_method("shake_camera"):
                main.shake_camera(1.2 * punch)
                
            if is_blinding and "blind_timer" in body:
                body.blind_timer = 2.5
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

# A lysosome sac: a lipid bilayer (two thin rings) round acid hydrolases,
# wobbling as it drifts, squashed along its way while it still moves fast
func _draw():
    if not is_vesicle:
        return
    var spd = velocity.length()
    var stretch = 1.0 + clamp(spd / 900.0, 0.0, 0.35)
    var r = 6.2
    var pts := PackedVector2Array()
    for i in 18:
        var a = TAU * i / 18.0
        var k = 1.0 + 0.07 * sin(3.0 * a + _wob) + 0.04 * sin(5.0 * a - _wob * 1.3)
        pts.append(Vector2(cos(a) * r * k * stretch, sin(a) * r * k / stretch).rotated(velocity.angle()))
    draw_colored_polygon(pts, Color(0.86, 0.5, 0.58, 0.9))
    var loop := pts.duplicate()
    loop.append(pts[0])
    draw_polyline(loop, Color(0.16, 0.07, 0.1, 0.95), 1.4, true)
    var inner := PackedVector2Array()
    for q in loop:
        inner.append(q * 0.78)
    draw_polyline(inner, Color(0.16, 0.07, 0.1, 0.45), 0.7, true)
    # Enzyme granules inside
    for j in 4:
        var g = _wob * 0.3 + j * 1.9
        draw_circle(Vector2(cos(g), sin(g)) * (1.2 + j * 0.7), 0.9, Color(0.3, 0.1, 0.16, 0.85), true, -1.0, true)

# The sac fuses with the prey and its enzymes go on digesting it: a few
# smaller bites over the next second, each leaving a little dissolving mark.
# Timers are bound to the prey, so they drop out if it dies or leaves.
func digest(body: Node):
    if not body.has_method("take_damage_if_alive"):
        return
    # Weak references: the prey, the room or this sac may all be gone by the
    # time a tick fires, and a lambda holding a freed object errors
    var prey_ref = weakref(body)
    var room_ref = weakref(get_parent())
    var per_tick = damage * DIGEST_SHARE
    var col = shot_color()
    for i in DIGEST_TICKS:
        var timer = get_tree().create_timer(DIGEST_GAP * (i + 1))
        timer.timeout.connect(func():
            var prey = prey_ref.get_ref()
            if prey == null or prey.get("dead"):
                return
            prey.take_damage_if_alive(per_tick)
            var room = room_ref.get_ref()
            if room != null and is_instance_valid(prey):
                HitFX.strike(room, prey.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), Vector2.from_angle(randf() * TAU), "vesicle", col, 8.0)
        )

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
        if enemy != source_enemy and is_instance_valid(enemy) and not enemy.get("dead") and not (enemy.has_method("is_burrowed") and enemy.is_burrowed()):
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
        split_tear.scale = base_scale * 0.7
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
        shrap.scale = base_scale * 0.55
        shrap.damage = max(1.5, damage * 0.45)
        shrap.lifetime = 0.35
        shrap.direction = Vector2(cos(a), sin(a))
        shrap.velocity = shrap.direction * speed * 1.25
        shrap.position = global_position
        get_parent().add_child(shrap)

func shot_color() -> Color:
    if is_enemy_tear:
        return Color(1.0, 0.25, 0.35)
    return PROJECTILE_GLOW.get(projectile_kind, Color(0.0, 0.95, 1.0))

func destroy_tear():
    if is_queued_for_deletion():
        return
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
        var glow: Color = PROJECTILE_GLOW.get(projectile_kind, Color(0.0, 0.95, 1.0))
        p.color = Color(glow.r, glow.g, glow.b, 0.8)
        
    get_parent().add_child(p)
    var timer = get_tree().create_timer(0.35)
    timer.timeout.connect(p.queue_free)
