# Player.gd
extends CharacterBody2D

signal health_changed(health, max_health)
signal stats_changed(dna, keys)
signal dna_changed(current_dna, max_dna, level)
signal dash_updated(current_cooldown, max_cooldown)
signal discharge_updated(current_cooldown, max_cooldown)
signal player_died
signal creature_changed(character_name, clade, color)

@export var max_health: int = 6
@export var health: int = 6

# Base stats (Scaled for 1080p)
@export var speed: float = 390.0
@export var damage: float = 3.5
@export var fire_delay: float = 0.28
@export var range_lifetime: float = 0.85
@export var shot_speed: float = 720.0

# Organism Evolution & Inventory
var dna_biomass: int = 0 # old coin count; unused since the shop was removed
var keys: int = 0
var evolution_choices: Array = [] # Tracks chosen path index per floor [0 or 1, ...]
var evolution_history: Array = [] # [{ "floor": 1, "title": "...", "clade": "...", "choice": 0 }]

# Active Creature State (Transforms on every floor into a distinct character)
var current_character_id: String = ""
var current_character_name: String = ""
var current_character_clade: String = ""
var current_living_example: String = ""
var current_modulate: Color = Color(0.0, 0.95, 1.0)
var current_accessory: String = "cilia"
# Per-lineage art: assets/lineages/<id>_sheet.png (4 frames of 128px, facing up).
# The default player_sheet.png needs a -90 degree turn; lineage sheets need +90.
var default_texture: Texture2D = null
var has_lineage_art: bool = false
var heading_offset: float = -PI/2
var current_attack_type: String = "single"
# Weapon style from data/Lineages.gd WEAPONS (ranged projectile or melee swing)
var current_weapon: String = "engulf"
var current_weapon_name: String = "Engulf (phagocytosis)"
var melee_arc_bonus: float = 0.0
var current_tear_perks: Dictionary = {}
var current_dash_perks: Dictionary = {}
var current_passive: String = "none"
var vision: int = 1 # 1-10, see Lineages.VISION; Main.gd passes it to VisionFog
var sense: int = 1 # 1-10, best non-visual sense, see Lineages.SENSES
# How close animals must come before they notice you (Lineages.STEALTH times
# the Cryptic Colouring adaptation); see notice_mult()
var stealth: float = 1.0
var cloak_time: float = 0.0 # ink, smoke or a camouflage dash: hard to see
var sense_kind: String = ""

# The current form's own stats; recompute_stats() adds items and adaptations
var form_stats: Dictionary = {}
# Flat bonuses from treasure items and refines, kept through evolution
var flat_damage: float = 0.0
var flat_speed: float = 0.0
var flat_fire: float = 0.0
var item_fire_mult: float = 1.0
var item_triple: bool = false

# Adaptations (data/Adaptations.gd): eating prey fills the biomass bar, and a
# full bar offers a pick of three traits that stack and survive evolution
var adaptations = preload("res://data/Adaptations.gd")
var biomass: float = 0.0
var adapt_level: int = 0
var adapt_pending: bool = false
var adaptations_taken: Dictionary = {} # id -> times taken
var range_mult: float = 1.0
var biomass_mult: float = 1.0
var armour: int = 0
var regen_on_clear: int = 0
var autotomy: bool = false # shed the first hit after each cleared room
var autotomy_ready: bool = false
var iframe_bonus: float = 0.0 # extra untouchable time on dash or escape
var crit_chance: float = 0.0 # Enemy.take_damage doubles this share of hits
var symbionts: float = 0.0 # each stack heals half a heart per 12 biomass
var symbiont_meter: float = 0.0
var thorns: float = 0.0 # enemies pressing against you take this x damage
var zap_power: float = 0.0
# Snared by velvet-worm slime or slowed by venom (Enemy.gd)
var slow_timer: float = 0.0
var slow_mult: float = 1.0

# Passive timer
var regen_timer: float = 0.0
var regen_interval: float = 8.0

# Where the creature faces: the aim while attacking, else where it moves.
# Kept when standing still, so it doesn't snap back to pointing up.
var face_dir: Vector2 = Vector2.UP
var aim_hold: float = 0.0

# Tear counter for burst cadences
var shot_counter: int = 0
# Shot feel: a short shove backwards and a squash that lasts a few frames
var recoil_velocity: Vector2 = Vector2.ZERO
var shot_kick: float = 0.0
const HitFX = preload("res://HitFX.gd")
const TearScript = preload("res://Tear.gd")

# Bio-Hydro Dash
var is_dashing: bool = false
var escape_style: String = "dart" # Lineages.ESCAPES: forms that can't dash
var rooted_time: float = 0.0 # holding still during a withdraw/bristle escape
var dash_timer: float = 0.0
var dash_duration: float = 0.22
var dash_speed: float = 900.0
var dash_direction: Vector2 = Vector2.UP
var dash_cooldown: float = 0.0
var max_dash_cooldown: float = 0.9

# Bio-Electric Discharge (Replaces legacy bombs with tactical ability)
var discharge_cooldown: float = 0.0
var max_discharge_cooldown: float = 4.5
var discharge_radius: float = 290.0

# Visual animation & cooldowns
var swim_time: float = 0.0
var shoot_cooldown: float = 0.0
var invincibility_time: float = 0.0
var door_cooldown: float = 0.0

# Preloads
var tear_scene = preload("res://Tear.tscn")
var melee_swing_script = preload("res://MeleeSwing.gd")

# Playable forms live in data/Lineages.gd, keyed by the path of evolution choices
var lineages = preload("res://data/Lineages.gd")
var codex = preload("res://data/Codex.gd")

func _ready():
    add_to_group("player")
    var start_form = lineages.get_form("")
    apply_form(start_form)
    codex.discover(start_form.id)
    call_deferred("emit_all_signals")

func emit_all_signals():
    health_changed.emit(health, max_health)
    stats_changed.emit(dna_biomass, keys)
    emit_biomass()
    dash_updated.emit(dash_cooldown, max_dash_cooldown)
    discharge_updated.emit(discharge_cooldown, max_discharge_cooldown)
    creature_changed.emit(current_character_name, current_character_clade, current_modulate)

# Physics interpolation draws the player between its last two physics ticks.
# Godot has no 2D getter for that drawn position, so keep the previous tick's
# and blend the same way; the vision fog centres on it.
var prev_tick_position: Vector2 = Vector2.ZERO

func drawn_position() -> Vector2:
    if not is_physics_interpolated_and_enabled():
        return global_position
    return prev_tick_position.lerp(global_position, Engine.get_physics_interpolation_fraction())

func _notification(what: int):
    if what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION:
        prev_tick_position = global_position

func _physics_process(delta: float):
    prev_tick_position = global_position
    # Dynamic redraw for animated creature anatomical accessories
    queue_redraw()

    # Cooldowns
    if shoot_cooldown > 0:
        shoot_cooldown -= delta
        
    if dash_cooldown > 0:
        dash_cooldown -= delta
        dash_updated.emit(dash_cooldown, max_dash_cooldown)
        
    if discharge_cooldown > 0:
        discharge_cooldown = max(0.0, discharge_cooldown - delta)
        discharge_updated.emit(discharge_cooldown, max_discharge_cooldown)
        
    if rooted_time > 0:
        rooted_time -= delta
    if cloak_time > 0:
        cloak_time -= delta
    if bite_chain_time > 0:
        bite_chain_time -= delta
    if slow_timer > 0:
        slow_timer -= delta
    # Spiny bodies (the spines weapon or the Defensive Spines adaptation)
    # hurt whatever presses against them
    if current_weapon == "spines" or thorns > 0.0:
        spine_aura_timer -= delta
        if spine_aura_timer <= 0.0:
            spine_aura_timer = 0.5
            var prick = damage * ((0.4 if current_weapon == "spines" else 0.0) + 0.3 * thorns)
            for e in get_tree().get_nodes_in_group("enemies"):
                if is_instance_valid(e) and e.global_position.distance_to(global_position) < body_radius(e, 30.0) + 55.0:
                    e.take_damage(prick)

    if invincibility_time > 0:
        invincibility_time -= delta
        $Sprite2D.visible = sin(invincibility_time * 32.0) > 0.0
    else:
        $Sprite2D.visible = true
        
    if door_cooldown > 0:
        door_cooldown -= delta

    # Passive cellular oxygen regeneration (Tiktaalik, Diplocaulus)
    if current_passive == "regen" and health < max_health:
        regen_timer += delta
        if regen_timer >= regen_interval:
            regen_timer = 0.0
            heal(1)

    # Passive tear reflection (Prismatic Bastion Ammonite)
    if current_passive == "damage_reduction_plus_reflect":
        var enemy_tears = get_tree().get_nodes_in_group("enemy_tears")
        for tear in enemy_tears:
            if is_instance_valid(tear) and global_position.distance_to(tear.global_position) < 65.0:
                if not tear.get_meta("reflected", false):
                    tear.set_meta("reflected", true)
                    tear.is_enemy_tear = false
                    tear.remove_from_group("enemy_tears")
                    tear.add_to_group("tears")
                    tear.collision_layer = 8
                    tear.collision_mask = 2 + 4
                    tear.direction = -tear.direction
                    tear.velocity = tear.direction * tear.speed * 1.2
                    if tear.has_node("Sprite2D"):
                        tear.get_node("Sprite2D").modulate = Color(0.3, 1.2, 1.5)

    # 1. Movement & Bio-Hydro Dash
    var move_dir = Vector2.ZERO
    move_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    move_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
    
    if move_dir != Vector2.ZERO:
        dash_direction = move_dir.normalized()

    # Trigger Bio-Dash (Spacebar / Shift / Right-Click)
    if (Input.is_action_just_pressed("dash") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and dash_cooldown <= 0 and not is_dashing:
        perform_bio_dash()

    # Trigger Bio-Electric Discharge (E / Q / Middle-Click)
    if (Input.is_action_just_pressed("discharge") or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) and discharge_cooldown <= 0:
        perform_bio_discharge()

    if is_dashing:
        dash_timer -= delta
        velocity = dash_direction * dash_speed
        move_and_slide()
        spawn_dash_particles()
        
        # Slipstream shockwave
        if current_dash_perks.get("slipstream", false):
            var enemies = get_tree().get_nodes_in_group("enemies")
            for e in enemies:
                if is_instance_valid(e) and global_position.distance_to(e.global_position) < 120.0:
                    var push = (e.global_position - global_position).normalized()
                    if e.has_method("apply_knockback"):
                        e.apply_knockback(push * 420.0, 0.25)

        # Contact dash damage (Bastion, Arthropleura, Scolopendra, Roller Titan)
        var slam_dmg = current_dash_perks.get("slam_damage", 0.0)
        if slam_dmg > 0:
            var enemies = get_tree().get_nodes_in_group("enemies")
            for e in enemies:
                if is_instance_valid(e) and global_position.distance_to(e.global_position) < 100.0:
                    if e.has_method("take_damage"):
                        e.take_damage(slam_dmg)

        # Poison acid slime trail (Eurypterid, Pulmonoscorpius, Plague Scorpion)
        if current_dash_perks.get("poison_trail", false) and randf() < 0.35:
            spawn_dash_acid_pool()

        if dash_timer <= 0:
            is_dashing = false
    else:
        var slowed = slow_mult if slow_timer > 0 else 1.0
        velocity = Vector2.ZERO if rooted_time > 0 else move_dir.normalized() * speed * slowed + recoil_velocity
        move_and_slide()
    recoil_velocity = recoil_velocity.move_toward(Vector2.ZERO, delta * 900.0)

    # Dynamic Swimming Squash & Stretch + Multi-Frame Cilia Animation
    if rooted_time > 0:
        # Hunkered down during an escape: drawn small and still (withdraw)
        # or puffed up (bristle, tubules)
        var hunker = 0.72 if escape_style == "withdraw" else 1.2
        $Sprite2D.scale = $Sprite2D.scale.lerp(Vector2(hunker, hunker), min(1.0, delta * 20.0))
    elif move_dir != Vector2.ZERO:
        swim_time += delta * 11.0
        var stretch_x = 1.0 + sin(swim_time) * 0.15
        var stretch_y = 1.0 - sin(swim_time) * 0.15
        $Sprite2D.scale = Vector2(stretch_x, stretch_y)
        $Sprite2D.frame = int(fmod(swim_time, 4.0))
    else:
        swim_time += delta * 3.5
        var pulse = 1.0 + sin(swim_time) * 0.06
        $Sprite2D.scale = Vector2(pulse, pulse)
        $Sprite2D.frame = int(fmod(swim_time, 4.0))
    # Recoil squash on top of the swim animation, so it is seen for more than a frame
    if shot_kick > 0.0:
        $Sprite2D.scale *= Vector2(1.0 + 0.22 * shot_kick, 1.0 - 0.18 * shot_kick)
        shot_kick = max(0.0, shot_kick - delta / 0.12)

    # Face the aim while attacking, otherwise the way we swim
    if aim_hold > 0:
        aim_hold -= delta
    elif move_dir != Vector2.ZERO and rooted_time <= 0:
        face_dir = move_dir.normalized()
    if not is_dashing:
        $Sprite2D.rotation = lerp_angle($Sprite2D.rotation, face_dir.angle() + heading_offset, delta * (16.0 if aim_hold > 0 else 9.0))

    # 2. Shooting: 8-Direction Keyboard + Mouse Aim
    handle_shooting()

func _draw():
    # Render rich creature anatomical accessories that physically animate with swimming
    if has_lineage_art:
        return
    var t = swim_time
    
    match current_accessory:
        "fin":
            var fin_col = current_modulate * Color(1.2, 1.2, 1.2, 0.85)
            # Dorsal fin
            var fin_pts = PackedVector2Array([
                Vector2(-6, -26), Vector2(0, -42 - sin(t * 8.0) * 4.0), Vector2(6, -26)
            ])
            draw_colored_polygon(fin_pts, fin_col)
            # Caudal tail
            var tail_pts = PackedVector2Array([
                Vector2(-14, 26), Vector2(0, 20), Vector2(14, 26), Vector2(0, 42 + sin(t * 10.0) * 6.0)
            ])
            draw_colored_polygon(tail_pts, fin_col)
            
        "carapace":
            var shell_col = current_modulate * Color(0.8, 0.8, 0.8, 0.9)
            for r in [18.0, 24.0, 30.0]:
                draw_arc(Vector2.ZERO, r, -PI * 0.7, PI * 0.7, 12, shell_col, 3.0, true)
            # Lateral spines
            draw_line(Vector2(-26, -10), Vector2(-38, -16), shell_col, 3.0, true)
            draw_line(Vector2(26, -10), Vector2(38, -16), shell_col, 3.0, true)
            draw_line(Vector2(-28, 10), Vector2(-42, 14), shell_col, 3.0, true)
            draw_line(Vector2(28, 10), Vector2(42, 14), shell_col, 3.0, true)
            
        "tentacles":
            var tent_col = current_modulate * Color(1.3, 1.1, 1.4, 0.85)
            for i in range(6):
                var base_angle = (float(i) / 6.0) * TAU
                var start = Vector2(cos(base_angle), sin(base_angle)) * 22.0
                var mid = start + Vector2(cos(base_angle + sin(t * 6.0 + i) * 0.5), sin(base_angle + sin(t * 6.0 + i) * 0.5)) * 18.0
                var tip = mid + Vector2(cos(base_angle + cos(t * 8.0 + i) * 0.7), sin(base_angle + cos(t * 8.0 + i) * 0.7)) * 14.0
                draw_polyline(PackedVector2Array([start, mid, tip]), tent_col, 3.0, true)
                draw_circle(tip, 2.5, Color.WHITE, true, -1.0, true)
                
        "shell":
            var shell_col = current_modulate * Color(1.1, 1.0, 0.8, 0.9)
            draw_arc(Vector2.ZERO, 32.0, 0, TAU, 24, shell_col, 4.0, true)
            draw_arc(Vector2(-6, 2), 22.0, 0, TAU * 0.85, 20, shell_col * 0.85, 3.0, true)
            draw_arc(Vector2(-10, 4), 14.0, 0, TAU * 0.75, 16, shell_col * 0.7, 2.5, true)
            
        "wings":
            var wing_col = Color(0.3, 0.95, 1.0, 0.65)
            var flutter = sin(t * 24.0) * 12.0
            draw_line(Vector2(-16, -6), Vector2(-54, -28 + flutter), wing_col, 3.0, true)
            draw_line(Vector2(-16, 6), Vector2(-48, 18 - flutter), wing_col, 2.5, true)
            draw_line(Vector2(16, -6), Vector2(54, -28 + flutter), wing_col, 3.0, true)
            draw_line(Vector2(16, 6), Vector2(48, 18 - flutter), wing_col, 2.5, true)
            
        "stinger":
            var sting_col = current_modulate * Color(0.9, 1.2, 0.8, 0.95)
            var p1 = Vector2(0, 24)
            var p2 = Vector2(sin(t * 5.0) * 6.0, 38)
            var p3 = Vector2(sin(t * 5.0) * 10.0, 52)
            var p4 = Vector2(sin(t * 5.0) * 8.0, 62)
            draw_polyline(PackedVector2Array([p1, p2, p3, p4]), sting_col, 5.0, true)
            draw_circle(p4, 5.5, Color(0.4, 1.0, 0.2, 1.0), true, -1.0, true)
            draw_line(p4, p4 + Vector2(4, -8), Color.WHITE, 2.0, true)
            
        "horns":
            var horn_col = current_modulate * Color(1.1, 1.2, 1.0, 0.9)
            var left_horn = PackedVector2Array([
                Vector2(-16, -14), Vector2(-55, -2), Vector2(-22, 16)
            ])
            var right_horn = PackedVector2Array([
                Vector2(16, -14), Vector2(55, -2), Vector2(22, 16)
            ])
            draw_colored_polygon(left_horn, horn_col)
            draw_colored_polygon(right_horn, horn_col)
            
        "scythe":
            var scythe_col = current_modulate * Color(1.3, 0.8, 1.2, 0.95)
            draw_arc(Vector2(-26, -14), 22.0, -PI*0.8, -PI*0.2, 12, scythe_col, 4.0, true)
            draw_line(Vector2(-44, -26), Vector2(-36, -34), Color.WHITE, 2.0, true)
            draw_arc(Vector2(26, -14), 22.0, -PI*0.8, -PI*0.2, 12, scythe_col, 4.0, true)
            draw_line(Vector2(44, -26), Vector2(36, -34), Color.WHITE, 2.0, true)
            
        "clubs":
            var club_col = Color(1.0, 0.2, 0.6, 0.95)
            var p_l = Vector2(-22, -24 + sin(t * 8.0) * 4.0)
            var p_r = Vector2(22, -24 + sin(t * 8.0) * 4.0)
            draw_line(Vector2(-14, -10), p_l, club_col, 5.0, true)
            draw_line(Vector2(14, -10), p_r, club_col, 5.0, true)
            draw_circle(p_l, 7.0, Color(1.0, 0.9, 0.2), true, -1.0, true)
            draw_circle(p_r, 7.0, Color(1.0, 0.9, 0.2), true, -1.0, true)
            
        _:
            var cilia_col = current_modulate * Color(1.0, 1.0, 1.0, 0.5)
            for i in range(12):
                var a = (float(i) / 12.0) * TAU
                var p1 = Vector2(cos(a), sin(a)) * 26.0
                var p2 = p1 + Vector2(cos(a + sin(t * 7.0 + i) * 0.4), sin(a + sin(t * 7.0 + i) * 0.4)) * 9.0
                draw_line(p1, p2, cilia_col, 2.0, true)

func perform_bio_dash():
    if escape_style != "dart":
        perform_escape()
        return
    is_dashing = true
    dash_timer = dash_duration
    dash_cooldown = max_dash_cooldown
    
    var iframe_dur = current_dash_perks.get("invulnerable_duration", 0.28) + iframe_bonus
    invincibility_time = iframe_dur
    
    SoundManager.play_sfx("dash")
    
    # Camouflage active stealth (Phantom Cuttlefish)
    if current_dash_perks.get("camouflage", false):
        hide_from_animals(1.5)
        $Sprite2D.modulate.a = 0.25
        var tw = create_tween()
        tw.tween_interval(1.5)
        tw.tween_property($Sprite2D, "modulate:a", 1.0, 0.3)
    
    # Seismic Room Quake (Scolopendra Earth-Crusher)
    if current_dash_perks.get("seismic", false):
        var enemies = get_tree().get_nodes_in_group("enemies")
        for e in enemies:
            if is_instance_valid(e) and e.has_method("apply_stun"):
                e.apply_stun(2.0)
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("shake_camera"):
            main.shake_camera(18.0)
        SoundManager.play_sfx("explosion", 0.8, 3.0)

    # Cavitation Burst (Mantis, Stomatopod Supernova)
    if current_dash_perks.get("cavitation_burst", false):
        var enemies = get_tree().get_nodes_in_group("enemies")
        for e in enemies:
            if is_instance_valid(e) and global_position.distance_to(e.global_position) < 160.0:
                if e.has_method("take_damage"):
                    e.take_damage(12.0)
                if e.has_method("apply_stun"):
                    e.apply_stun(1.5)
        SoundManager.play_sfx("explosion", 1.4, 2.0)
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("shake_camera"):
            main.shake_camera(12.0)

    # Smoke / Ink Cloud (Abyssal Kraken Squid, Architeuthis Void Squid)
    if current_dash_perks.get("smoke_cloud", false):
        spawn_dash_smoke_cloud()

    # Web Snare (Trapdoor Silk Reaper)
    if current_dash_perks.get("web_snare", false):
        spawn_dash_web_snare()

    # Rolling Boulder (Ironclad Roller Titan)
    if current_dash_perks.get("rolling_boulder", false):
        invincibility_time = max(invincibility_time, dash_duration + 0.15)
        var tw = create_tween()
        tw.tween_property($Sprite2D, "rotation", $Sprite2D.rotation + TAU * 2.0, dash_duration)

    $Sprite2D.scale = Vector2(1.45, 0.65)
    $Sprite2D.rotation = dash_direction.angle() + heading_offset
    face_dir = dash_direction
    aim_hold = 0.0

# The dash button for forms that can't dart (see Lineages.ESCAPES): a clam
# clamps shut, an urchin raises its spines, a sea cucumber throws sticky
# threads, a sea hare inks.
func perform_escape():
    var st: Dictionary = lineages.ESCAPE_STYLES[escape_style]
    dash_cooldown = max_dash_cooldown
    invincibility_time = max(invincibility_time, st.invulnerable + iframe_bonus)
    rooted_time = st.rooted
    SoundManager.play_sfx("dash", 0.7)
    var radius: float = st.get("radius", 0.0)
    var hit: float = damage * st.get("damage", 0.0) + current_dash_perks.get("slam_damage", 0.0)
    for e in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(e) or global_position.distance_to(e.global_position) > radius:
            continue
        if hit > 0 and e.has_method("take_damage"):
            e.take_damage(hit)
        if not is_instance_valid(e):
            continue
        if st.has("knockback") and e.has_method("apply_knockback"):
            e.apply_knockback((e.global_position - global_position).normalized() * st.knockback, 0.3)
        if st.has("stun") and e.has_method("apply_stun"):
            e.apply_stun(st.stun)
    match escape_style:
        "withdraw":
            spawn_escape_ring(radius, current_modulate)
        "bristle":
            spawn_escape_ring(radius, Color(1.0, 0.85, 0.6))
        "tubules":
            spawn_dash_web_snare()
            spawn_escape_ring(radius, Color(1.0, 1.0, 0.9))
        "ink":
            spawn_dash_smoke_cloud()
            $Sprite2D.modulate.a = 0.35
            var tw = create_tween()
            tw.tween_interval(1.2)
            tw.tween_property($Sprite2D, "modulate:a", 1.0, 0.3)

# What the dash button says for this form (DASH, HIDE, SPINE, STICK, INK)
func dash_label() -> String:
    return lineages.ESCAPE_STYLES[escape_style].label if escape_style != "dart" else "DASH"

func spawn_escape_ring(radius: float, col: Color):
    var ring = Line2D.new()
    ring.width = 4.0
    ring.default_color = col
    var pts = PackedVector2Array()
    for i in range(25):
        var a = (float(i) / 24.0) * TAU
        pts.append(Vector2(cos(a), sin(a)) * 12.0)
    ring.points = pts
    ring.position = global_position
    get_parent().add_child(ring)
    var tw = ring.create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector2.ONE * (radius / 12.0), 0.25)
    tw.tween_property(ring, "modulate:a", 0.0, 0.25)
    tw.chain().tween_callback(ring.queue_free)

# Multiplier on how close animals must come to notice you (Enemy.process_mood).
# Most animals spot movement first, so holding still helps; so does hiding in
# a shell or behind ink.
func notice_mult() -> float:
    var m = stealth
    if velocity.length() < 20.0:
        m *= 0.7
    if rooted_time > 0:
        m *= 0.5
    if cloak_time > 0:
        m *= 0.3
    return m

# Ink, smoke or a sudden change of colour: animals close by lose track of you
func hide_from_animals(duration: float):
    cloak_time = max(cloak_time, duration)
    for e in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and e.has_method("lose_track") and e.global_position.distance_to(global_position) < 380.0:
            e.lose_track()

func spawn_dash_smoke_cloud():
    hide_from_animals(1.2)
    var cloud = Area2D.new()
    cloud.position = global_position
    cloud.collision_layer = 0
    cloud.collision_mask = 2
    
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 65.0
    col.shape = shape
    cloud.add_child(col)
    
    var p = CPUParticles2D.new()
    p.amount = 24
    p.lifetime = 2.2
    p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 45.0
    p.color = Color(0.12, 0.05, 0.25, 0.85)
    p.initial_velocity_min = 5.0
    p.initial_velocity_max = 25.0
    p.scale_amount_min = 4.0
    p.scale_amount_max = 9.0
    cloud.add_child(p)
    
    get_parent().add_child(cloud)
    
    var timer_node = Timer.new()
    timer_node.wait_time = 0.35
    timer_node.autostart = true
    cloud.add_child(timer_node)
    timer_node.timeout.connect(func():
        for body in cloud.get_overlapping_bodies():
            if body.is_in_group("enemies"):
                if body.has_method("take_damage"):
                    body.take_damage(2.5)
                if body.has_method("apply_stun") and randf() < 0.4:
                    body.apply_stun(0.8)
    )
    var tw = get_tree().create_timer(3.5)
    tw.timeout.connect(cloud.queue_free)

func spawn_dash_web_snare():
    var web = Area2D.new()
    web.position = global_position
    web.collision_layer = 0
    web.collision_mask = 2
    
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 55.0
    col.shape = shape
    web.add_child(col)
    
    # Visual web silk rings
    var line = Line2D.new()
    line.width = 2.0
    line.default_color = Color(0.9, 0.9, 1.0, 0.7)
    var pts = PackedVector2Array()
    for i in range(13):
        var a = (float(i) / 12.0) * TAU
        pts.append(Vector2(cos(a), sin(a)) * 50.0)
    line.points = pts
    web.add_child(line)
    
    get_parent().add_child(web)
    
    var timer_node = Timer.new()
    timer_node.wait_time = 0.25
    timer_node.autostart = true
    web.add_child(timer_node)
    timer_node.timeout.connect(func():
        for body in web.get_overlapping_bodies():
            if body.is_in_group("enemies") and body.has_method("apply_stun"):
                body.apply_stun(1.5)
    )
    var tw = get_tree().create_timer(4.0)
    tw.timeout.connect(web.queue_free)

func spawn_dash_acid_pool():
    var pool = Area2D.new()
    pool.position = global_position
    pool.collision_layer = 0
    pool.collision_mask = 2
    
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 45.0
    col.shape = shape
    pool.add_child(col)
    
    var p = CPUParticles2D.new()
    p.amount = 14
    p.lifetime = 1.8
    p.color = Color(0.4, 1.2, 0.1, 0.8)
    p.initial_velocity_min = 5.0
    p.initial_velocity_max = 20.0
    pool.add_child(p)
    
    get_parent().add_child(pool)
    
    var timer_node = Timer.new()
    timer_node.wait_time = 0.3
    timer_node.autostart = true
    pool.add_child(timer_node)
    timer_node.timeout.connect(func():
        for body in pool.get_overlapping_bodies():
            if body.is_in_group("enemies") and body.has_method("take_damage"):
                body.take_damage(2.0)
    )
    var tw = get_tree().create_timer(3.0)
    tw.timeout.connect(pool.queue_free)

func spawn_dash_particles():
    var p = CPUParticles2D.new()
    p.position = global_position
    p.emitting = true
    p.one_shot = true
    p.explosiveness = 0.85
    p.amount = 8
    p.lifetime = 0.25
    p.spread = 60.0
    p.direction = -dash_direction
    p.initial_velocity_min = 40.0
    p.initial_velocity_max = 120.0
    p.scale_amount_min = 2.0
    p.scale_amount_max = 5.5
    p.color = current_modulate * Color(1, 1, 1, 0.75)
    get_parent().add_child(p)
    var tw = get_tree().create_timer(0.3)
    tw.timeout.connect(p.queue_free)

func perform_bio_discharge():
    discharge_cooldown = max_discharge_cooldown
    discharge_updated.emit(discharge_cooldown, max_discharge_cooldown)
    
    SoundManager.play_sfx("zap")
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(8.0)
        
    spawn_discharge_fx()
    
    # Clear enemy projectiles
    var enemy_tears = get_tree().get_nodes_in_group("enemy_tears")
    for tear in enemy_tears:
        if is_instance_valid(tear):
            var dist = global_position.distance_to(tear.global_position)
            if dist <= discharge_radius:
                spawn_electric_spark_line(global_position, tear.global_position)
                if tear.has_method("destroy_tear"):
                    tear.destroy_tear()
                else:
                    tear.queue_free()
                    
    var all_tears = get_tree().get_nodes_in_group("tears")
    for tear in all_tears:
        if is_instance_valid(tear) and tear.get("is_enemy_tear") == true:
            if global_position.distance_to(tear.global_position) <= discharge_radius:
                spawn_electric_spark_line(global_position, tear.global_position)
                if tear.has_method("destroy_tear"):
                    tear.destroy_tear()
                else:
                    tear.queue_free()

    # Damage nearby enemies
    var enemies = get_tree().get_nodes_in_group("enemies")
    for e in enemies:
        if is_instance_valid(e):
            var dist = global_position.distance_to(e.global_position)
            if dist <= discharge_radius:
                spawn_electric_spark_line(global_position, e.global_position)
                if e.has_method("take_damage"):
                    e.take_damage(damage * 1.8 * (1.0 + zap_power))
                if e.has_method("apply_knockback"):
                    var push_dir = (e.global_position - global_position).normalized()
                    e.apply_knockback(push_dir * 500.0, 0.35 * (1.0 + 2.0 * zap_power))

func spawn_electric_spark_line(from_pos: Vector2, to_pos: Vector2):
    var line = Line2D.new()
    line.width = 3.5
    line.default_color = current_modulate * Color(1.2, 1.2, 1.5, 0.95)
    
    var pts = PackedVector2Array()
    var segs = 4
    for i in range(segs + 1):
        var t = float(i) / float(segs)
        var p = from_pos.lerp(to_pos, t)
        if i > 0 and i < segs:
            p += Vector2(randf_range(-14, 14), randf_range(-14, 14))
        pts.append(p)
        
    line.points = pts
    get_parent().add_child(line)
    
    var tween = create_tween()
    tween.tween_property(line, "modulate:a", 0.0, 0.16)
    tween.tween_callback(line.queue_free)

func spawn_discharge_fx():
    var ring = Line2D.new()
    ring.width = 4.0
    ring.default_color = current_modulate * Color(1.2, 1.2, 1.5, 0.9)
    var num_pts = 36
    var pts = PackedVector2Array()
    for i in range(num_pts + 1):
        var a = (float(i) / float(num_pts)) * TAU
        pts.append(Vector2(cos(a), sin(a)) * 12.0)
    ring.points = pts
    ring.position = global_position
    get_parent().add_child(ring)
    
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(ring, "scale", Vector2.ONE * (discharge_radius / 12.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "modulate:a", 0.0, 0.28)
    tween.chain().tween_callback(ring.queue_free)

func handle_shooting():
    if shoot_cooldown > 0:
        return
        
    var shoot_dir = Vector2.ZERO
    shoot_dir.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
    shoot_dir.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
    
    if shoot_dir != Vector2.ZERO:
        shoot_tear(shoot_dir.normalized())
    # On touch screens taps are also reported as left clicks, so mouse aiming
    # would fire at the move-stick thumb; TouchControls drives shooting there
    elif not TouchControls.should_show() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_pos = get_global_mouse_position()
        var to_mouse = (mouse_pos - global_position).normalized()
        if to_mouse != Vector2.ZERO:
            shoot_tear(to_mouse)

func shoot_tear(dir: Vector2):
    face_dir = dir
    aim_hold = 0.4
    if lineages.weapon_stats(current_weapon).melee:
        melee_attack(dir)
        return
    shoot_cooldown = fire_delay
    SoundManager.play_sfx("shoot", 1.05 + randf_range(-0.08, 0.08))
    shot_kick = 1.0
    recoil_velocity = -dir * 110.0
    var glow: Color = TearScript.PROJECTILE_GLOW.get(current_weapon, Color(0.0, 0.95, 1.0))
    HitFX.muzzle(get_parent(), global_position + dir * muzzle_distance(), glow)
    
    shot_counter += 1
    var is_alpha = (shot_counter % 3 == 0) and (current_attack_type == "needle")

    match current_attack_type:
        "triple":
            for angle in [-0.22, 0.0, 0.22]:
                spawn_tear(dir.rotated(angle), is_alpha)
        "5way":
            for angle in [-0.36, -0.18, 0.0, 0.18, 0.36]:
                spawn_tear(dir.rotated(angle), is_alpha)
        "7way":
            for angle in [-0.48, -0.32, -0.16, 0.0, 0.16, 0.32, 0.48]:
                spawn_tear(dir.rotated(angle), is_alpha)
        "boomerang":
            for angle in [-0.15, 0.15]:
                spawn_tear(dir.rotated(angle), false, true)
        _:
            if current_weapon == "spray":
                # Bombardier-style spray comes out as a hot, spreading cone
                for angle in [-0.2, 0.0, 0.2]:
                    spawn_tear(dir.rotated(angle + randf_range(-0.05, 0.05)), is_alpha)
            else:
                spawn_tear(dir, is_alpha)

# Shots leave from the front of the body rather than its middle
func muzzle_distance() -> float:
    return 24.0

func spawn_tear(dir: Vector2, alpha: bool = false, boomerang: bool = false):
    var tear = tear_scene.instantiate()
    # A touch of spread keeps streams of shots from looking like one rigid line
    dir = dir.rotated(randf_range(-0.035, 0.035))
    tear.position = global_position + dir * muzzle_distance()
    tear.damage = damage * (2.0 if alpha else 1.0)
    tear.lifetime = range_lifetime * (1.3 if alpha else 1.0)
    tear.speed = shot_speed * (1.3 if alpha else 1.0)
    tear.velocity = dir * tear.speed + velocity * 0.25
    
    # Configure tear traits from active character archetype
    tear.is_piercing = current_tear_perks.get("piercing", false) or alpha
    tear.is_electric = current_tear_perks.get("electric", false)
    tear.is_homing = current_tear_perks.get("homing", false)
    tear.is_caustic = current_tear_perks.get("caustic", false)
    tear.is_vampiric = current_tear_perks.get("vampiric", false)
    tear.is_explosive = current_tear_perks.get("explosive", false)
    tear.is_shrapnel = current_tear_perks.get("shrapnel", false)
    tear.is_stun = current_tear_perks.get("stun", false)
    tear.is_boomerang = boomerang or current_tear_perks.get("boomerang", false)
    tear.knockback_force = current_tear_perks.get("knockback", 0.0)

    # Projectile look and handling from the form's weapon (lysosome, venom spit...)
    var w = lineages.weapon_stats(current_weapon)
    tear.projectile_kind = current_weapon
    tear.speed *= w.get("speed", 1.0)
    tear.lifetime *= w.get("life", 1.0)
    tear.velocity = dir * tear.speed + velocity * 0.25
    tear.is_stun = tear.is_stun or w.get("stun", false)
    tear.is_caustic = tear.is_caustic or w.get("caustic", false)
    # Ranged signatures: water jets shove, spitting venom blinds, cone snail
    # harpoons pass through and paralyse
    tear.damage *= w.get("shot_damage", 1.0)
    match current_weapon:
        "jet":
            tear.knockback_force = max(tear.knockback_force, 240.0)
        "spit":
            tear.is_blinding = true
        "harpoon":
            tear.is_piercing = true
            tear.is_stun = true

    if tear.has_node("Sprite2D"):
        tear.get_node("Sprite2D").modulate = Color(1.15, 1.15, 1.15)
        if alpha:
            tear.get_node("Sprite2D").scale = Vector2(1.8, 1.8)
    
    get_parent().add_child(tear)

# Close-range attack for forms whose real weapon is a mouth, claw or arm.
# Hits every enemy (and breakable obstacle) in an arc toward dir, and swats
# enemy shots inside it, so melee forms can fight back against spitters.
func melee_attack(dir: Vector2):
    var w = lineages.weapon_stats(current_weapon)
    shoot_cooldown = fire_delay * w.cooldown
    SoundManager.play_sfx("dash", 1.6 + randf_range(-0.1, 0.1))
    shot_kick = 1.0

    var reach: float = w.reach * range_mult
    var half_arc: float = min(PI, w.arc * 0.5 + melee_arc_bonus)
    var dmg: float = damage * w.damage
    var perk_knock: float = current_tear_perks.get("knockback", 0.0) * 0.6
    var knock: float = w.get("knockback", 0.0)
    if knock >= 0.0:
        knock = max(knock, perk_knock)
    var stun: float = w.get("stun", 0.0) + (0.5 if current_tear_perks.get("stun", false) else 0.0)
    var venom: bool = w.get("venom", false) or current_tear_perks.get("caustic", false)
    var drain: bool = w.get("drain", false) or current_tear_perks.get("vampiric", false)

    # Claws pounce and jaws lunge a little into the strike
    var step = {"claw": 110.0, "bite": 40.0, "smash": 30.0}.get(current_weapon, 0.0)
    if step > 0.0:
        move_and_collide(dir * step)

    var victims: Array = []
    for e in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and e.has_method("take_damage") and in_melee_arc(e.global_position, body_radius(e, 30.0), dir, reach, half_arc):
            victims.append(e)
    var special_hit := false
    if current_weapon == "bite":
        bite_chain = bite_chain + 1 if bite_chain_time > 0.0 else 1
        bite_chain_time = 1.6
    for e in victims:
        if not is_instance_valid(e):
            continue
        var away = (e.global_position - global_position).normalized()
        var mult = weapon_special(e, away, reach)
        if mult < 0.0:
            special_hit = true
            continue # devoured or swallowed whole
        if mult > 1.0:
            special_hit = true
        if e.has_method("apply_knockback") and (knock != 0.0 or stun > 0.0):
            var k = knock * (1.8 if current_weapon == "lash" and mult > 1.0 else 1.0)
            e.apply_knockback(away * k, max(stun, 0.15))
        elif e.has_method("apply_hit_push"):
            e.apply_hit_push(away * 260.0)
        HitFX.impact(get_parent(), e.global_position - away * body_radius(e, 30.0) * 0.6, away, current_modulate, 1.2)
        e.take_damage(dmg * mult)
        if venom:
            apply_venom(e, dmg * 0.25)
        if current_weapon in ["arms", "tongue"] and is_instance_valid(e):
            e.set("grabbed_time", 1.2)
        if current_weapon == "rasp":
            # The radula keeps grinding: two quick follow-up scrapes
            for i in 2:
                get_tree().create_timer(0.11 * (i + 1)).timeout.connect(e.take_damage_if_alive.bind(dmg * 0.3))
    for o in get_tree().get_nodes_in_group("obstacles"):
        if is_instance_valid(o) and o.has_method("take_damage") and in_melee_arc(o.global_position, 40.0, dir, reach, half_arc):
            o.take_damage(dmg)
    for t in get_tree().get_nodes_in_group("enemy_tears"):
        if is_instance_valid(t) and in_melee_arc(t.global_position, 14.0, dir, reach + 10.0, half_arc) and t.has_method("destroy_tear"):
            t.destroy_tear()

    if not victims.is_empty():
        SoundManager.play_sfx("hit", 0.85)
        var first = victims[0]
        var hit_pos: Vector2 = first.global_position if is_instance_valid(first) else global_position + dir * reach
        if drain and randf() < 0.3:
            heal(1)
        if current_tear_perks.get("electric", false):
            melee_electric_arc(hit_pos, victims)
        if current_tear_perks.get("explosive", false):
            melee_blast(hit_pos, dmg * 0.5)
        if w.get("cavitation", false):
            # Mantis shrimp strikes boil the water: a collapsing bubble hits again
            get_tree().create_timer(0.09).timeout.connect(func():
                for v in victims:
                    if is_instance_valid(v) and v.get("health") != null and v.health > 0:
                        v.take_damage(dmg * 0.4)
            )
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("shake_camera"):
            main.shake_camera((9.0 if special_hit else 0.0) + (5.0 if w.damage >= 2.5 else 2.5))
        # A tiny freeze on every connecting strike gives melee its crunch
        if main and main.has_method("hit_stop"):
            main.hit_stop(0.06 if special_hit else 0.03)

    var swing = melee_swing_script.new()
    swing.style = current_weapon
    swing.reach = reach
    swing.half_arc = half_arc
    swing.color = current_modulate
    swing.rotation = dir.angle()
    add_child(swing)

# Each attack's signature move (Lineages.WEAPONS "special" describes them).
# Returns the damage multiplier for this victim, or -1 when it was eaten whole.
var bite_chain: int = 0
var spine_aura_timer: float = 0.0
var bite_chain_time: float = 0.0

func weapon_special(e: Node, away: Vector2, reach: float) -> float:
    var boss = e.has_method("is_boss") and e.is_boss()
    var hp_frac = e.health / max(1.0, e.max_health)
    match current_weapon:
        "engulf":
            # Phagocytosis: a weakened prey is wrapped up and digested whole
            if not boss and hp_frac <= 0.35:
                popup_text(e.global_position, "DEVOUR", Color(0.4, 1.0, 0.8))
                add_biomass(1.0)
                e.take_damage(e.health + 1.0)
                return -1.0
        "tongue":
            # Frogs swallow small prey whole
            if not boss and hp_frac <= 0.4:
                popup_text(e.global_position, "GULP", Color(1.0, 0.55, 0.65))
                heal(1)
                e.take_damage(e.health + 1.0)
                return -1.0
            if e.get("grabbed_time") and e.grabbed_time > 0.0:
                return 1.8
        "arms":
            if e.get("grabbed_time") and e.grabbed_time > 0.0:
                popup_text(e.global_position, "GRIP", Color(1.0, 0.7, 0.95))
                return 1.8
        "bite":
            if bite_chain >= 3:
                popup_text(e.global_position, "CRUNCH", Color(1.0, 0.85, 0.4))
                return 2.5
        "pincer", "clamp":
            # A second pinch on a stunned animal crushes it
            if e.get("stun_timer") and e.stun_timer > 0.05:
                popup_text(e.global_position, "CRUSH", Color(1.0, 0.6, 0.3))
                return 2.0
        "lash":
            # The tip of a whip moves fastest: hits at the far end crack
            if e.global_position.distance_to(global_position) > reach * 0.6:
                popup_text(e.global_position, "CRACK", Color(0.8, 0.95, 1.0))
                return 2.0
        "sting":
            # Venom builds up; the third sting floods the wound
            e.set("venom_stacks", e.get("venom_stacks") + 1)
            if e.venom_stacks >= 3:
                e.venom_stacks = 0
                popup_text(e.global_position, "VENOM", Color(0.6, 1.0, 0.3))
                return 3.0
        "smash":
            popup_text(e.global_position, "SMASH", Color(1.0, 1.0, 1.0))
            return 1.0
    return 1.0

# Short floating word over a special hit
func popup_text(pos: Vector2, text: String, col: Color):
    var l = Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 34)
    l.add_theme_color_override("font_color", col)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 8)
    l.z_index = 20
    l.self_modulate = Color(1.9, 1.9, 1.9) # stay readable under the room's dark tint
    l.position = pos + Vector2(-50, -70)
    get_parent().add_child(l)
    var tw = l.create_tween()
    tw.set_parallel(true)
    tw.tween_property(l, "position:y", l.position.y - 50.0, 0.6)
    tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
    tw.chain().tween_callback(l.queue_free)

func in_melee_arc(target: Vector2, radius: float, dir: Vector2, reach: float, half_arc: float) -> bool:
    var to = target - global_position
    var dist = to.length()
    if dist > reach + radius:
        return false
    if half_arc >= PI or dist < radius + 20.0:
        return true
    return abs(dir.angle_to(to)) <= half_arc + atan2(radius, dist)

func body_radius(node: Node2D, fallback: float) -> float:
    var cs = node.get_node_or_null("CollisionShape2D")
    if cs and cs.shape is CircleShape2D:
        return cs.shape.radius * max(abs(node.scale.x), abs(node.scale.y)) * max(abs(cs.scale.x), abs(cs.scale.y))
    return fallback

# Venom keeps hurting for a moment after the sting or bite
func apply_venom(enemy: Node, per_tick: float):
    if not enemy.has_method("take_damage_if_alive"):
        return
    for i in 3:
        # Bound to the enemy, so the timer is dropped if it dies first
        get_tree().create_timer(0.45 * (i + 1)).timeout.connect(enemy.take_damage_if_alive.bind(per_tick))

func melee_electric_arc(from_pos: Vector2, already_hit: Array):
    for e in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and not already_hit.has(e) and e.global_position.distance_to(from_pos) < 260.0:
            e.take_damage(2.5)
            spawn_electric_spark_line(from_pos, e.global_position)
            break

func melee_blast(pos: Vector2, amount: float):
    for e in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and e.global_position.distance_to(pos) < 120.0:
            e.take_damage(amount)
    var p = CPUParticles2D.new()
    p.position = pos
    p.one_shot = true
    p.emitting = true
    p.amount = 18
    p.lifetime = 0.35
    p.explosiveness = 0.95
    p.spread = 180.0
    p.color = Color(1.0, 0.55, 0.15, 1.0)
    p.initial_velocity_min = 60.0
    p.initial_velocity_max = 160.0
    p.scale_amount_min = 3.0
    p.scale_amount_max = 6.0
    get_parent().add_child(p)
    get_tree().create_timer(0.4).timeout.connect(p.queue_free)
    SoundManager.play_sfx("explosion", 1.3, -4.0)

func emit_biomass():
    dna_changed.emit(int(biomass), adaptations.biomass_needed(adapt_level), adapt_level + 1)

# BiomassOrb.gd calls this when an orb from a kill reaches the player
func add_biomass(amount: float):
    biomass += amount * biomass_mult
    # Gut symbionts: digestion pays back in health
    if symbionts > 0.0:
        symbiont_meter += amount * biomass_mult * symbionts
        if symbiont_meter >= 12.0:
            symbiont_meter -= 12.0
            if health < max_health:
                heal(1)
                popup_text(global_position, "+½ ♥", Color(0.62, 0.93, 0.5))
    emit_biomass()
    try_offer_adaptation()

func try_offer_adaptation():
    if adapt_pending or biomass < adaptations.biomass_needed(adapt_level):
        return
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("offer_adaptation"):
        adapt_pending = true
        main.offer_adaptation()

# Called by Main.gd with the id the player picked
func apply_adaptation(id: String):
    var a = adaptations.get_adaptation(id)
    biomass = max(0.0, biomass - adaptations.biomass_needed(adapt_level))
    adapt_level += 1
    adapt_pending = false
    grant_adaptation(id)
    SoundManager.play_sfx("level_up", 1.2)
    emit_biomass()
    # Enough left over for another? Offer it once this pick has closed
    call_deferred("try_offer_adaptation")

# Adds an adaptation without spending biomass (also the menu's starting trait)
func grant_adaptation(id: String):
    var a = adaptations.get_adaptation(id)
    if a.is_empty():
        return
    adaptations_taken[id] = adaptations_taken.get(id, 0) + 1
    if a.mods.has("autotomy"):
        autotomy_ready = true
    var hp = a.mods.get("hp", 0)
    if hp > 0:
        add_max_health(hp)
    recompute_stats()
    creature_changed.emit(current_character_name, current_character_clade, current_modulate)

# Sum of every adaptation taken, e.g. {"damage": 0.4, "perk": ["caustic"]}
func adaptation_mods() -> Dictionary:
    var total = {"perk": []}
    for id in adaptations_taken:
        var a = adaptations.get_adaptation(id)
        for k in a.get("mods", {}):
            var v = a.mods[k]
            if k == "perk":
                total.perk.append(v)
            else:
                total[k] = total.get(k, 0.0) + v * adaptations_taken[id]
    return total

# Form stats, then items and refines, then adaptations
func recompute_stats():
    if form_stats.is_empty():
        return
    var m = adaptation_mods()
    damage = (form_stats.damage + flat_damage) * (1.0 + m.get("damage", 0.0))
    speed = (form_stats.speed + flat_speed) * (1.0 + m.get("speed", 0.0))
    fire_delay = max(0.06, max(0.08, form_stats.fire_delay - flat_fire) * item_fire_mult / (1.0 + m.get("fire", 0.0)))
    shot_speed = form_stats.shot_speed
    range_mult = 1.0 + m.get("range", 0.0)
    range_lifetime = 0.85 * range_mult
    max_dash_cooldown = form_stats.dash_cd / (1.0 + m.get("dash_cd", 0.0))
    max_discharge_cooldown = 4.5 / (1.0 + m.get("zap_cd", 0.0))
    discharge_radius = 290.0 * (1.0 + m.get("zap_radius", 0.0))
    vision = clampi(form_stats.vision + int(m.get("vision", 0)), 1, 10)
    sense = clampi(form_stats.sense + int(m.get("sense", 0)), 1, 10)
    stealth = form_stats.get("stealth", 1.0) * max(0.4, 1.0 - m.get("stealth", 0.0))
    biomass_mult = 1.0 + m.get("biomass", 0.0)
    armour = int(m.get("armour", 0))
    regen_on_clear = int(m.get("regen", 0))
    autotomy = m.get("autotomy", 0.0) > 0.0
    iframe_bonus = m.get("iframes", 0.0)
    crit_chance = m.get("crit", 0.0)
    symbionts = m.get("symbiont", 0.0)
    thorns = m.get("thorns", 0.0)
    zap_power = m.get("zap_power", 0.0)

    current_tear_perks = form_stats.perks.duplicate()
    for perk in m.perk:
        current_tear_perks[perk] = true
    if m.get("knockback", 0.0) > 0.0:
        current_tear_perks["knockback"] = current_tear_perks.get("knockback", 0.0) + m.knockback
    current_attack_type = form_stats.attack_type
    if item_triple and current_attack_type == "single":
        current_attack_type = "triple"

# Room.gd calls this when the last enemy in a room dies
func on_room_cleared():
    if regen_on_clear > 0 and health < max_health:
        heal(regen_on_clear)
    if autotomy:
        autotomy_ready = true

func add_dna(amount: int):
    dna_biomass += amount
    SoundManager.play_sfx("dna_pickup", 1.0 + (dna_biomass % 10) * 0.05)
    stats_changed.emit(dna_biomass, keys)
    emit_biomass()

# Called by Main.gd after the player picks an evolution on the choice screen.
# choice is the index of the card picked; a form with no real split known
# shows a single "refine" card, which keeps the form and strengthens it.
func apply_evolution(floor_num: int, choice: int):
    evolution_choices.append(choice)
    SoundManager.play_sfx("level_up", 1.0)

    var path_key = lineages.path_key(evolution_choices)
    var refined = not lineages.has_form(path_key)
    var data: Dictionary
    if refined:
        # In-clade upgrade: same form, stronger
        flat_damage += 1.5
        flat_speed += 20.0
        flat_fire += 0.02
        recompute_stats()
        add_max_health(2)
        heal(2)
    else:
        data = lineages.get_form(path_key)
        apply_form(data)
        var hp_add = data.get("max_health_add", 0)
        if hp_add > 0:
            add_max_health(hp_add)
            heal(hp_add)
        codex.discover(data.id)

    evolution_history.append({
        "floor": floor_num,
        "title": current_character_name if not refined else "REFINED " + current_character_name,
        "clade": current_character_clade,
        "living": current_living_example,
        "choice": choice
    })

    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("display_item_banner"):
        if refined:
            main.display_item_banner("REFINED " + current_character_name, "No real split is known here, so your lineage adapts: +damage, +speed, +2 health")
        else:
            main.display_item_banner(current_character_name, data.fact)

    creature_changed.emit(current_character_name, current_character_clade, current_modulate)
    emit_biomass()
    health_changed.emit(health, max_health)

# Copies a form from data/Lineages.gd onto the player
func apply_form(data: Dictionary):
    current_character_id = data.id
    current_character_name = data.name
    current_character_clade = data.clade
    current_living_example = data.living_example
    current_modulate = data.color
    current_accessory = data.accessory
    current_weapon = data.get("weapon", "vesicle")
    current_weapon_name = data.get("weapon_name", "Engulf (phagocytosis)")
    current_dash_perks = data.dash_perks
    current_passive = data.passive
    vision = lineages.get_vision(data)
    sense = lineages.get_sense(data)
    sense_kind = lineages.SENSES.get(data.id, [1, "Touch"])[1]

    escape_style = lineages.get_escape(data)[0]
    rooted_time = 0.0
    form_stats = {
        "speed": data.speed, "damage": data.damage, "fire_delay": data.fire_delay,
        "shot_speed": data.shot_speed, "attack_type": data.attack_type,
        "perks": data.tear_perks, "vision": vision, "sense": sense,
        "stealth": lineages.get_stealth(data),
        "dash_cd": dash_cooldown_for_speed(data.speed) if escape_style == "dart" \
            else lineages.ESCAPE_STYLES[escape_style].cooldown,
    }
    recompute_stats()

    # Flight collision mask
    if current_passive == "flight":
        set_collision_mask_value(3, false) # Fly over obstacle layer
    else:
        set_collision_mask_value(3, true)

    update_creature_visuals()

# Slow forms (sea lilies, clams, sea cucumbers) recharge their dash sooner and
# fast swimmers later, so a slow body can still dart out of trouble.
# 0.54 s at 270 speed, 0.9 s at 440, 1.03 s from 505 up.
static func dash_cooldown_for_speed(spd: float) -> float:
    return 0.9 * clamp(spd / 440.0, 0.6, 1.15)

func update_creature_visuals():
    if default_texture == null:
        default_texture = $Sprite2D.texture
    var sheet_path = "res://assets/lineages/%s_sheet.png" % current_character_id
    has_lineage_art = ResourceLoader.exists(sheet_path)
    $Sprite2D.texture = load(sheet_path) if has_lineage_art else default_texture
    $Sprite2D.hframes = 4
    heading_offset = PI/2 if has_lineage_art else -PI/2
    # Lineage art carries its own colours and anatomy, so no tint or drawn accessory
    $Sprite2D.modulate = Color.WHITE if has_lineage_art else current_modulate
    queue_redraw()
    if has_node("PointLight2D"):
        $PointLight2D.color = current_modulate
        $PointLight2D.energy = 1.5
    if has_node("SwimParticles"):
        $SwimParticles.color = current_modulate * Color(1, 1, 1, 0.6)

func get_evolution_summary() -> Dictionary:
    return {
        "title": current_character_name,
        "clade": current_character_clade,
        "history": evolution_history
    }

func add_coin(amount: int):
    add_dna(amount)

func take_damage(amount: int):
    if invincibility_time > 0 or is_dashing:
        return
    # Autotomy: drop a limb or tail tip instead of taking the hit
    if autotomy_ready:
        autotomy_ready = false
        invincibility_time = 1.0
        SoundManager.play_sfx("hit", 0.7)
        popup_text(global_position, "AUTOTOMY", Color(1.0, 0.8, 0.4))
        HitFX.impact(get_parent(), global_position, Vector2.UP, Color(1.0, 0.8, 0.5), 1.2)
        return
    
    var actual_amount = amount
    
    # Passive damage reduction (Ammonite, Prismatic Ammonite)
    if (current_passive == "damage_reduction" or current_passive == "damage_reduction_plus_reflect") and actual_amount > 1:
        actual_amount = max(1, actual_amount - 1)
    # Mineralised armour adaptation
    if armour > 0 and actual_amount > 1:
        actual_amount = max(1, actual_amount - armour)
        
    health = max(0, health - actual_amount)
    
    # Invincibility frames (doubled for heavy carapace)
    invincibility_time = 2.0 if current_passive == "double_iframes" else 1.0
    
    SoundManager.play_sfx("player_hurt", 1.0)
    $Sprite2D.scale = Vector2(0.7, 1.4)
    
    # White flash tween
    $Sprite2D.modulate = Color(2.5, 2.5, 2.5, 1.0)
    var flash_tween = create_tween()
    flash_tween.tween_property($Sprite2D, "modulate", Color.WHITE if has_lineage_art else current_modulate, 0.25)
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(9.0)
        
    # Retaliatory spine darts (Trilobita)
    if current_passive == "retaliatory_spines":
        for angle_deg in [0, 90, 180, 270]:
            var a = deg_to_rad(angle_deg)
            spawn_tear(Vector2(cos(a), sin(a)))
        
    health_changed.emit(health, max_health)
    
    if health <= 0:
        die()

# Slime or venom: slower movement for a while (mult 0.5 = half speed)
func apply_slow(duration: float, mult: float, label: String = ""):
    if invincibility_time > 0 or is_dashing:
        return
    if slow_timer <= 0 and label != "":
        popup_text(global_position, label, Color(0.75, 1.0, 0.7))
    slow_timer = max(slow_timer, duration)
    slow_mult = mult

func heal(amount: int):
    health = min(max_health, health + amount)
    SoundManager.play_sfx("heart_pickup", 1.0)
    health_changed.emit(health, max_health)

func add_max_health(amount: int):
    max_health += amount
    health += amount
    SoundManager.play_sfx("heart_pickup", 1.1)
    health_changed.emit(health, max_health)

func add_key(amount: int):
    keys = min(99, keys + amount)
    SoundManager.play_sfx("dna_pickup", 0.9)
    stats_changed.emit(dna_biomass, keys)

func apply_item_upgrade(item_id: String):
    # Kept as bonuses so they survive the next evolution
    if item_id == "onion":
        flat_fire += 0.08
    elif item_id == "eye":
        item_triple = true
        item_fire_mult *= 1.15
        melee_arc_bonus += 0.25
    elif item_id == "hormones":
        flat_damage += 2.0
        flat_speed += 50.0
    elif item_id == "cells":
        add_max_health(2)
        heal(2)
    recompute_stats()

    health_changed.emit(health, max_health)
    stats_changed.emit(dna_biomass, keys)

func die():
    SoundManager.play_sfx("player_hurt", 0.7)
    player_died.emit()
    set_physics_process(false)
    set_process(false)
    
    var burst = CPUParticles2D.new()
    burst.position = global_position
    burst.amount = 48
    burst.lifetime = 1.2
    burst.one_shot = true
    burst.explosiveness = 0.95
    burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    burst.emission_sphere_radius = 10.0
    burst.initial_velocity_min = 80.0
    burst.initial_velocity_max = 320.0
    burst.gravity = Vector2(0, 0)
    burst.scale_amount_min = 3.0
    burst.scale_amount_max = 8.0
    burst.color = current_modulate * Color(1, 1, 1, 0.9)
    get_parent().add_child(burst)
    burst.restart()
    
    var tween = create_tween()
    tween.tween_property($Sprite2D, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
