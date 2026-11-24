# Main.gd
extends Node2D

@onready var hud = $HUD
@onready var player = $Player
# Not physics-interpolated (Main.tscn): it moves only by tweens and shake,
# so it draws exactly where it is set each frame
@onready var camera = $Camera2D
@onready var transition_rect = $TransitionLayer/ColorRect

var level_gen = preload("res://LevelGenerator.gd")
var room_scene = preload("res://Room.tscn")
var fauna = preload("res://data/Fauna.gd")
var era_look = preload("res://data/EraLook.gd")
const Worlds = preload("res://data/Worlds.gd")

var floor_number: int = 1
var dungeon_rooms: Dictionary = {}
var current_room_pos: Vector2i = Vector2i(4, 4)
var current_room_node = null
var is_transitioning: bool = false

var camera_shake_amount: float = 0.0

func _ready():
    preload("res://data/ArtStyles.gd").apply_environment($WorldEnvironment.environment, SettingsManager.art_style)
    SettingsManager.art_style_changed.connect(func(id): preload("res://data/ArtStyles.gd").apply_environment($WorldEnvironment.environment, id))
    add_to_group("main")
    setup_inputs()
    
    # Connect player signals to HUD
    player.health_changed.connect(hud.update_health)
    player.health_changed.connect(_on_player_health_feedback)
    Engine.time_scale = 1.0 # in case a restart happened mid hit-stop
    player.stats_changed.connect(hud.update_inventory)
    player.dna_changed.connect(hud.update_dna)
    player.elements_changed.connect(hud.update_elements)
    player.player_died.connect(_on_player_died)
    if hud.has_method("update_discharge_cooldown"):
        player.discharge_updated.connect(hud.update_discharge_cooldown)
    hud.evolution_selected.connect(_on_evolution_selected)
    hud.adaptation_selected.connect(player.apply_adaptation)
    player.creature_changed.connect(_on_player_creature_changed)
    hud.adaptation_selected.connect(func(_id): check_challenges())
    
    SettingsManager.set_brightness(SettingsManager.brightness)
    
    start_new_game()
    # How-to-play card; tools/*.gd drive the game from a script, so skip it there
    if get_tree().get_script() == null:
        hud.show_era_card(1, hud.lineages.get_form(""))

func setup_inputs():
    var inputs = {
        "move_left": [KEY_A, KEY_LEFT],
        "move_right": [KEY_D, KEY_RIGHT],
        "move_up": [KEY_W, KEY_UP],
        "move_down": [KEY_S, KEY_DOWN],
        "shoot_left": [KEY_J],
        "shoot_right": [KEY_L],
        "shoot_up": [KEY_I],
        "shoot_down": [KEY_K],
        "dash": [KEY_SHIFT, KEY_SPACE],
        "discharge": [KEY_E, KEY_Q]
    }
    for action in inputs:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for key in inputs[action]:
            var ev = InputEventKey.new()
            ev.physical_keycode = key
            InputMap.action_add_event(action, ev)
            
    # Also bind Middle Mouse Button to discharge
    var mouse_ev = InputEventMouseButton.new()
    mouse_ev.button_index = MOUSE_BUTTON_MIDDLE
    InputMap.action_add_event("discharge", mouse_ev)

func _process(delta: float):
    # Process camera shake
    if camera_shake_amount > 0:
        camera.offset = Vector2(
            randf_range(-camera_shake_amount, camera_shake_amount),
            randf_range(-camera_shake_amount, camera_shake_amount)
        )
        camera_shake_amount = move_toward(camera_shake_amount, 0.0, delta * 40.0)
    else:
        camera.offset = Vector2.ZERO
        
    # Check restart key
    if (hud.game_over_screen.visible or hud.victory_screen.visible) and hud.end_screen_ready():
        if Input.is_key_pressed(KEY_R):
            get_tree().paused = false
            get_tree().reload_current_scene()

func _input(event: InputEvent):
    # Tap anywhere to restart on touch screens (no R key on a phone)
    # A on the gamepad does the same
    var pad_a = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A
    if (event is InputEventScreenTouch and event.pressed) or pad_a:
        if (hud.game_over_screen.visible or hud.victory_screen.visible) and hud.end_screen_ready():
            get_tree().paused = false
            get_tree().reload_current_scene()

func _notification(what: int):
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        hud.back_pressed()
    elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        # Switching apps or tabs mid-fight shouldn't cost the run
        flush_bank()
        if get_tree().get_script() == null and player.health > 0:
            hud.auto_pause()

func shake_camera(amount: float):
    if not SettingsManager.screen_shake:
        return
    # Phones are held close to the eyes; keep the shake gentler there
    if TouchControls.should_show():
        amount *= 0.6
    camera_shake_amount = max(camera_shake_amount, amount)

# Freeze-frame on big impacts: time nearly stops for a moment. The timer runs
# in real time so it always ends; only the newest hit-stop restores the speed.
var hit_stop_id: int = 0

func hit_stop(duration: float, time_scale: float = 0.05):
    if get_tree().paused:
        return
    hit_stop_id += 1
    var my_id = hit_stop_id
    Engine.time_scale = time_scale
    await get_tree().create_timer(duration, true, false, true).timeout
    if my_id == hit_stop_id:
        Engine.time_scale = 1.0

var last_player_health: int = -1

func _on_player_health_feedback(health, _max_health):
    if last_player_health >= 0 and health < last_player_health:
        hit_this_floor = true
        hit_this_room = true
        hit_stop(0.07)
        hud.flash_hurt()
        PadInput.rumble(0.55, 0.18)
    last_player_health = health

var progress = preload("res://data/Progress.gd")
var hit_this_floor: bool = false
var hit_this_room: bool = false

# ---- Field notes: two fixed goals per era (data/FieldNotes.gd) ----
var field_notes = preload("res://data/FieldNotes.gd")
var notes_progress: Dictionary = {} # note index -> count, this floor only

func field_event(event: String, amount: int = 1):
    if player == null or player.health <= 0:
        return
    var notes = field_notes.for_floor(floor_number)
    for i in notes.size():
        var n = notes[i]
        var got = int(notes_progress.get(i, 0))
        if n.event != event or got >= n.need:
            continue
        notes_progress[i] = got + amount
        if notes_progress[i] >= n.need:
            _field_note_done(n)
        elif n.need > 1:
            player.popup_text(player.global_position + Vector2(0, -70), "%d/%d" % [notes_progress[i], n.need], Color(0.98, 0.76, 0.38))

func _field_note_done(n: Dictionary):
    var els = preload("res://MineralSeep.gd").era_elements(floor_number)
    els.shuffle()
    els = els.slice(0, 2)
    for i in field_notes.REWARD_ORBS:
        var orb = preload("res://BiomassOrb.gd").new()
        orb.value = field_notes.REWARD_UNITS / field_notes.REWARD_ORBS
        orb.element = els[i % els.size()]
        orb.position = current_room_node.to_local(player.global_position) + Vector2.from_angle(TAU * i / field_notes.REWARD_ORBS) * 70.0
        current_room_node.add_child(orb)
    if player.has_method("heal"):
        player.heal(field_notes.REWARD_HEAL)
    SoundManager.play_sfx("level_up", 1.1, -4.0)
    # No banner over the room: a short tag rises off you and the quest mark
    # under the map pops; the fact waits on the pause screen
    player.popup_text(player.global_position + Vector2(0, -90), "QUEST ✓", Color(0.98, 0.76, 0.38))
    _update_quest_mark(true)
    hud.last_banner = ["QUEST: " + n.text, n.fact]
    hud.note_journal("QUEST: " + n.text, n.fact)

func _update_quest_mark(pop: bool = false):
    var notes = field_notes.for_floor(floor_number)
    var done = 0
    for i in notes.size():
        if int(notes_progress.get(i, 0)) >= notes[i].need:
            done += 1
    hud.update_quests(done, notes.size(), pop)

func start_new_game():
    floor_number = 1
    Worlds.sea = false # floors 1-3 are sea anyway; advance_floor picks 4 and 5
    generate_floor()
    # Starting trait chosen on the main menu (unlocked by a challenge)
    var start_trait = progress.start_trait()
    if start_trait != "" and get_tree().get_script() == null:
        player.grant_adaptation(start_trait)
    # Parts grown into the lineage on the main menu GROW page
    if get_tree().get_script() == null:
        apply_lineage(progress.lineage_ranks())

func apply_lineage(ranks: Dictionary):
    for id in ranks:
        for i in int(ranks[id]):
            player.grant_adaptation(id)
    player.health = player.max_health

# ---- The bank: everything eaten goes to the lineage (data/Progress.gd) ----
# Elements in hand are what you can still spend in this run (healing, the
# clutch); the bank follows them, so spending in the run banks less. Written
# on each cleared room, new floor, run end, quitting and app switch.
var bank_synced: Dictionary = {}

func _exit_tree():
    flush_bank() # quitting to the menu or restarting keeps what you ate

func flush_bank(force: bool = false):
    if (get_tree().get_script() != null and not force) or player == null:
        return
    var delta := {}
    for el in player.elements:
        var d = float(player.elements[el]) - float(bank_synced.get(el, 0.0))
        if absf(d) > 0.001:
            delta[el] = d
    for el in bank_synced:
        if not player.elements.has(el):
            delta[el] = -float(bank_synced[el])
    progress.add_to_bank(delta)
    bank_synced = player.elements.duplicate()

# Saves a challenge and announces it the first time it is completed
func complete_challenge(id: String):
    if get_tree().get_script() != null:
        return # tools/*.gd runs shouldn't fill the real save
    if progress.complete(id):
        var c = progress.get_challenge(id)
        var a = player.adaptations.get_adaptation(c.unlock)
        SoundManager.play_sfx("level_up", 0.9)
        hud.show_item_banner("CHALLENGE: " + c.name, "%s. New starting trait on the main menu: %s." % [c.goal, a.name], true, -1.0, "New starting trait: " + a.name)

# Codex, form and adaptation challenges, checked whenever they could change
func check_challenges():
    var found = player.codex.load_discovered().size()
    if found >= 10:
        complete_challenge("codex_10")
    if found >= 25:
        complete_challenge("codex_25")
    if player.elements_eaten >= 60.0:
        complete_challenge("well_fed")
    var form = current_form()
    if form.get("clade_path", "").contains("Arthropoda"):
        complete_challenge("arthropod")

func generate_floor():
    hit_this_floor = false
    # Tests and screenshots can force the world (WORLD=sea / land)
    if Worlds.forced() != "" and Worlds.splits(floor_number):
        Worlds.sea = Worlds.forced() == "sea"
    # A key belongs to its own floor: a spare one never opens the next
    if player.keys > 0:
        player.keys = 0
        player.stats_changed.emit(player.dna_biomass, 0)
    notes_progress = {}
    _update_quest_mark()
    hud.update_floor(floor_number)
    if floor_number == 1:
        SoundManager.new_run()
    SoundManager.play_music(SoundManager.music_for_floor(floor_number))
    
    if floor_number == 1:
        specials_seen = []
    dungeon_rooms = level_gen.generate_level(floor_number, specials_seen)
    for pos in dungeon_rooms:
        if dungeon_rooms[pos].special != "":
            specials_seen.append(dungeon_rooms[pos].special)
    # A follower (rooms/Companion.gd) stays for one era
    for c in get_tree().get_nodes_in_group("companions"):
        c.queue_free()
    current_room_pos = Vector2i(4, 4)
    
    # Position player at 1080p center
    player.global_position = Vector2(960, 540)
    player.velocity = Vector2.ZERO
    player.reset_physics_interpolation() # teleport, don't glide there
    
    load_room(current_room_pos)
    hud.update_minimap(dungeon_rooms, current_room_pos)
    # The era page (HUD.show_era_card) shows the wildlife and field notes now;
    # this note stays for the pause screen's "last discovery"
    hud.last_banner = ["WILDLIFE OF THIS ERA", fauna.describe_floor(floor_number, true)]
    if floor_number >= 3:
        complete_challenge("ordovician")

var specials_seen: Array = [] # special room kinds dealt this run (LevelGenerator)

func load_room(grid_pos: Vector2i):
    hud.hide_boss_health()
    
    if current_room_node:
        if current_room_node.has_method("save_room_state"):
            current_room_node.save_room_state()
        current_room_node.queue_free()
        
    var room_data = dungeon_rooms[grid_pos]
    room_data.visited = true
    hit_this_room = false
    
    current_room_node = room_scene.instantiate()
    current_room_node.position = Vector2.ZERO
    add_child(current_room_node)
    move_child(current_room_node, 0)
    
    current_room_node.setup_room(room_data, floor_number)
    current_room_node.room_transition_requested.connect(_on_room_transition_requested)
    
    update_ambient_lighting(room_data.type)
    
    camera.position = Vector2(960, 540)
    hud.update_minimap(dungeon_rooms, current_room_pos)

# Mid-fight: no growing until the room is clear (HUD.show_grow_screen)
func in_combat() -> bool:
    if is_transitioning or current_room_node == null or not is_instance_valid(current_room_node):
        return false
    return current_room_node.has_method("in_combat") and current_room_node.in_combat()

func get_room_type(grid_pos: Vector2i) -> int:
    if dungeon_rooms.has(grid_pos):
        return dungeon_rooms[grid_pos].type
    return -1

func is_room_visited(grid_pos: Vector2i) -> bool:
    if dungeon_rooms.has(grid_pos):
        return dungeon_rooms[grid_pos].visited
    return false

func register_boss(boss_node: Node):
    SoundManager.play_sfx("boss_intro")
    SoundManager.play_music(SoundManager.boss_music_for_floor(floor_number))
    boss_node.boss_health_changed.connect(hud.show_boss_health)
    boss_node.enemy_died.connect(hud.hide_boss_health)
    var boss_floor_color = get_boss_floor_color(floor_number)
    if has_node("CanvasModulate"):
        var tween = create_tween()
        tween.tween_property($CanvasModulate, "color", boss_floor_color, 0.6)

func get_boss_floor_color(floor_num: int) -> Color:
    return era_look.get_look(floor_num).boss_tint * (SettingsManager.brightness / 1.2)

# -------------------------------------------------------------
# Smooth 1080p Sliding Camera Room Transition with Anti-Loop Lock
# -------------------------------------------------------------
func _on_room_transition_requested(direction: Vector2i):
    if is_transitioning or player.door_cooldown > 0:
        return
        
    var target_pos = current_room_pos + direction
    if not dungeon_rooms.has(target_pos):
        return
        
    is_transitioning = true
    player.set_physics_process(false)
    player.door_cooldown = 0.5
    
    # Save current room state (surviving pickups, pedestals, shop items)
    if current_room_node and current_room_node.has_method("save_room_state"):
        current_room_node.save_room_state()
    
    # Delete active projectiles on room transition
    for tear in get_tree().get_nodes_in_group("tears"):
        tear.queue_free()
        
    # 1080p full screen offset
    # Rooms are 1920px plus a side margin on wide screens (Room.side_margin)
    var margin = current_room_node.side_margin if current_room_node else 0.0
    var room_offset = Vector2(direction.x * (1920 + margin * 2), direction.y * 1080)
    var next_room_data = dungeon_rooms[target_pos]
    next_room_data.visited = true
    
    var next_room_node = room_scene.instantiate()
    next_room_node.position = room_offset
    add_child(next_room_node)
    move_child(next_room_node, 0)
    next_room_node.entry_dir = direction
    next_room_node.setup_room(next_room_data, floor_number)
    
    # Safe entry position inside new room (safely away from door trigger area)
    var local_enter_pos = Vector2(960, 540)
    if direction == Vector2i.UP:
        local_enter_pos = Vector2(960, 840) # Spawn well above bottom door (y=988)
    elif direction == Vector2i.DOWN:
        local_enter_pos = Vector2(960, 240) # Spawn well below top door (y=92)
    elif direction == Vector2i.LEFT:
        local_enter_pos = Vector2(1660 + margin, 540) # Spawn well left of right door
    elif direction == Vector2i.RIGHT:
        local_enter_pos = Vector2(260 - margin, 540) # Spawn well right of left door
        
    var target_player_world_pos = local_enter_pos + room_offset
    var target_cam_pos = Vector2(960, 540) + room_offset
    
    SoundManager.play_sfx("door_open", 1.1, -4.0)
    
    var target_ambient = get_room_theme_color(next_room_data.type)
    # The tween moves the player every frame; draw it there directly
    player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(camera, "position", target_cam_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(player, "global_position", target_player_world_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property($CanvasModulate, "color", target_ambient, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    
    tween.chain().tween_callback(func():
        if current_room_node:
            current_room_node.queue_free()
            
        current_room_node = next_room_node
        current_room_node.position = Vector2.ZERO
        current_room_node.room_transition_requested.connect(_on_room_transition_requested)
        
        camera.position = Vector2(960, 540)
        player.global_position = local_enter_pos
        player.velocity = Vector2.ZERO
        player.door_cooldown = 0.4
        # Both jumped back to the origin together with the camera
        current_room_node.reset_physics_interpolation()
        player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
        player.reset_physics_interpolation()
        player.invincibility_time = 0.8 # Buffer to prevent immediate contact damage
        
        current_room_pos = target_pos
        room_entered_at = Time.get_ticks_msec()
        hud.update_minimap(dungeon_rooms, current_room_pos)
        
        player.set_physics_process(true)
        is_transitioning = false
    )

var advancing: bool = false
var room_entered_at: int = 0 # when the last room change finished (Door.gd hints)

# pick: the world an amphibious form chose at the trapdoor ("sea"/"land")
func advance_floor(pick: String = ""):
    # The trapdoor can report the player more than once during the fade
    if advancing:
        return
    if floor_number >= 5:
        record_run(true)
        hud.show_victory(player.get_evolution_summary())
        player.set_physics_process(false)
        return
        
    floor_number += 1
    advancing = true
    # From the Carboniferous on, sea animals and land animals go to
    # different worlds (data/Worlds.gd)
    Worlds.sea = Worlds.sea_for(floor_number, current_form().get("id", ""), pick)
    
    transition_rect.visible = true
    transition_rect.color.a = 0.0
    player.set_physics_process(false)
    
    var tween = create_tween()
    tween.tween_property(transition_rect, "color:a", 1.0, 0.4)
    tween.tween_callback(func():
        for tear in get_tree().get_nodes_in_group("tears"):
            tear.queue_free()

        for pickup in get_tree().get_nodes_in_group("pickups"):
            pickup.queue_free()
            
        generate_floor()
    )
    tween.tween_property(transition_rect, "color:a", 0.0, 0.4)
    tween.tween_callback(func():
        transition_rect.visible = false
        advancing = false
        player.set_physics_process(true)
        flush_bank()
        # Arthropods shed their skin for each new era
        player.molt_into_era()
        apply_air()
        if get_tree().get_script() == null:
            hud.show_era_card(floor_number, current_form())
    )

# The Carboniferous coal-swamp air held far more oxygen than today's, and
# arthropods, which breathe through fine tubes oxygen has to diffuse along,
# grew to giant sizes: arthropod forms get an extra heart on land in era 4
const AIR_FACT = "Late Carboniferous air was about 35% oxygen, against 21% today. Insects, millipedes and spiders breathe through fine tubes that oxygen has to seep along, so richer air is thought to be why they grew so big: the griffinfly Meganeura spanned 70 cm and Arthropleura grew longer than 2 m."

func apply_air():
    var hp = 2 if Worlds.era(floor_number) == 4 and player.is_arthropod() else 0
    var had = player.air_bonus
    player.set_air_bonus(hp)
    if hp > had:
        player.popup_text(player.global_position + Vector2(0, -80), "OXYGEN-RICH AIR: +1 HEART", Color(0.85, 0.95, 0.75))
        hud.note_journal("HIGH OXYGEN", AIR_FACT)
    elif hp < had:
        player.popup_text(player.global_position + Vector2(0, -80), "THINNER AIR: -1 HEART", Color(0.9, 0.8, 0.7))

# A species eaten for the first time joins the fossil record (main menu)
func note_new_fossil(species: String):
    player.popup_text(player.global_position + Vector2(0, -60), "NEW FOSSIL: " + species.to_upper(), Color(0.98, 0.76, 0.38))

# First time a hunt is watched: a short tag over the hunter; the fossil
# record lists it from now on (data/FoodWeb.gd, MainMenu.fossil_row)
func note_new_hunt(hunter: String, prey: String, pos: Vector2):
    var text = "%s EATS %s" % [hunter.to_upper(), prey.to_upper()]
    # Keep the whole tag inside the room, even when the catch is by a wall
    var o = current_room_node.global_position if current_room_node else Vector2.ZERO
    var w = text.length() * 21.0
    pos.x = clamp(pos.x, o.x + 110.0, o.x + 1860.0 - w)
    pos.y = clamp(pos.y, o.y + 220.0, o.y + 1000.0)
    player.popup_text(pos + Vector2(0, -40), text, Color(0.98, 0.76, 0.38))

# An animal sketched from life (rooms/FieldSketch.gd)
func note_sketch(species: String, fact: String):
    hud.show_item_banner("FIELD SKETCH: " + species.to_upper(), fact, false, 3.0, "You know its weak spots: hits on it land harder this run")

# The first time you see a kind of trace being made (rooms/TraceLayer.gd)
func note_new_trace(id: String):
    var t = preload("res://data/Traces.gd").TRACES[id]
    hud.show_item_banner("TRACE FOSSIL: " + String(t.name).to_upper(), t.fact, false, 3.2, t.short)

func display_item_banner(title: String, desc: String, hold: float = -1.0, short: String = ""):
    hud.show_item_banner(title, desc, false, hold, short)

func on_boss_defeated(f_num: int):
    # A poison tick or acid pool can finish the boss after you have died:
    # the game over screen stands, no victory or evolution on top of it
    if player.health <= 0:
        return
    if f_num == 1:
        complete_challenge("ediacaran")
    if not hit_this_floor:
        complete_challenge("untouched")
    if f_num >= 5:
        complete_challenge("survivor")
    SoundManager.play_music(SoundManager.music_for_floor(f_num))
    if f_num >= 5:
        # Ultimate Final Boss Defeated!
        record_run(true)
        hud.show_victory(player.get_evolution_summary())
        player.set_physics_process(false)
        return
        
    # Trigger biological evolution selection for Floors 1 to 4 with current phylogenetic path
    hud.show_evolution_modal(f_num, player.evolution_choices)

func _on_evolution_selected(floor_num: int, choice_index: int):
    player.apply_evolution(floor_num, choice_index)
    check_challenges()
    # The new form and its attack are shown on the next era's card
    if current_room_node and current_room_node.has_method("spawn_trapdoor"):
        current_room_node.spawn_trapdoor()

# The biomass bar is full: after a short beat, offer three adaptations.
# Waits while another card or menu has the game paused.
var adaptation_offer_queued: bool = false

func offer_adaptation():
    if adaptation_offer_queued:
        return
    adaptation_offer_queued = true
    await get_tree().create_timer(0.35).timeout
    while get_tree().paused or hud.is_card_up():
        await get_tree().create_timer(0.25).timeout
    adaptation_offer_queued = false
    if player.health <= 0:
        return
    hud.show_adaptation_modal(player.adaptations.roll(player.adaptations_taken), player.adaptations_taken)

# The player's current form; a refine keeps the last real form on the path
func current_form() -> Dictionary:
    var choices = player.evolution_choices.duplicate()
    while choices.size() > 0 and not hud.lineages.has_form(hud.lineages.path_key(choices)):
        choices.pop_back()
    return hud.lineages.get_form(hud.lineages.path_key(choices))

func _on_player_creature_changed(c_name: String, _c_clade: String, _c_color: Color):
    hud.set_current_creature(c_name)
    $VisionFog.set_vision(player.vision)
    $VisionFog.set_sense(player.sense, player.sense_kind, player.sense_profile)
    hud.update_floor(floor_number)

func get_room_theme_color(room_type: int) -> Color:
    var b = SettingsManager.brightness / 1.2
    # Each era has its own light (data/EraLook.gd); special rooms shade it
    var era_tint: Color = era_look.get_look(floor_number).tint
    match room_type:
        2: return era_tint * Color(0.92, 1.05, 0.95) * b # Treasure
        4: return era_tint * Color(1.05, 0.98, 0.85) * b # Shop
        3: return get_boss_floor_color(floor_number) # Boss
        _: return era_tint * b

func update_ambient_lighting(target_type: int = -1):
    if not has_node("CanvasModulate"):
        return
    var r_type = target_type
    if r_type < 0:
        r_type = get_room_type(current_room_pos)
    $CanvasModulate.color = get_room_theme_color(r_type)

# Furthest era and run count for the main menu (not from tools/*.gd runs)
var run_recorded: bool = false

func record_run(won: bool) -> bool:
    flush_bank()
    if get_tree().get_script() != null or run_recorded:
        return false
    run_recorded = true
    # The lineage you walked, as form ids, for the past-runs page
    var ids: Array = []
    var L = player.lineages
    for n in range(player.evolution_choices.size() + 1):
        var key = L.path_key(player.evolution_choices.slice(0, n))
        if L.has_form(key) and (ids.is_empty() or ids[-1] != L.get_form(key).id):
            ids.append(L.get_form(key).id)
    return progress.record_run(floor_number, player.current_character_name, won, {
        "path": ids,
        "world_era": Worlds.era(floor_number),
        "killer": "" if won else player.last_hurt_by,
        "kills": player.kills,
        "parts": player.adaptations_taken.size(),
    })

# ---- Your clutch (GROW screen, data/Reproduction.gd) ----
# One clutch at a time, left in a cleared room of this floor. Dying on this
# floor hatches it; going down to the next era leaves it behind.
var clutch_floor: int = 0
var clutch_room: Vector2i = Vector2i.ZERO
var clutch_pos: Vector2 = Vector2.ZERO
var hatching: bool = false

func has_clutch() -> bool:
    return clutch_floor == floor_number

func can_lay_clutch() -> bool:
    if has_clutch() or hatching or is_transitioning or player == null or player.health <= 0:
        return false
    if current_room_node == null or in_combat():
        return false
    return current_room_node.room_data != null and current_room_node.room_data.cleared

func lay_clutch(world_pos: Vector2):
    var local = current_room_node.to_local(world_pos)
    # Keep it clear of the walls and doors
    local.x = clamp(local.x, 260.0, 1660.0)
    local.y = clamp(local.y, 230.0, 850.0)
    clutch_floor = floor_number
    clutch_room = current_room_pos
    clutch_pos = local
    current_room_node.room_data.clutch_pos = local
    current_room_node.room_data.clutch_hatched = false
    current_room_node.add_clutch()

# A molted skin stays in the room (rooms/Exuvia.gd)
func add_exuvia(world_pos: Vector2, rot: float, form: String, parts: Dictionary):
    if current_room_node == null or current_room_node.room_data == null:
        return
    var e = {"pos": current_room_node.to_local(world_pos), "rot": rot, "form": form, "parts": parts, "eaten": false}
    current_room_node.room_data.exuviae.append(e)
    current_room_node.add_exuvia(e)

func _hatch_from_clutch():
    hatching = true
    clutch_floor = 0
    var data = dungeon_rooms[clutch_room]
    data.clutch_hatched = true
    await get_tree().create_timer(1.1, true, false, true).timeout
    transition_rect.visible = true
    transition_rect.color.a = 0.0
    var tween = create_tween()
    tween.tween_property(transition_rect, "color:a", 1.0, 0.45)
    await tween.finished
    for tear in get_tree().get_nodes_in_group("tears"):
        tear.queue_free()
    current_room_pos = clutch_room
    player.global_position = clutch_pos
    load_room(clutch_room)
    SoundManager.play_music(SoundManager.music_for_floor(floor_number))
    player.hatch(clutch_pos, preload("res://data/Reproduction.gd").hatch_health(player.current_character_id, player.max_health))
    var t2 = create_tween()
    t2.tween_property(transition_rect, "color:a", 0.0, 0.45)
    await t2.finished
    transition_rect.visible = false
    hatching = false

func _on_player_died():
    if hatching:
        return # a blow landing on the body while the young one hatches
    if has_clutch():
        _hatch_from_clutch()
        return
    var record = record_run(false)
    hud.show_game_over({
        "record": record,
        "floor": floor_number,
        "era": Worlds.era(floor_number),
        "form": player.current_character_name,
        "kills": player.kills,
        "killed_by": player.last_hurt_by,
        "rooms": dungeon_rooms.values().filter(func(r): return r.cleared and r.type == 1).size(),
    })
