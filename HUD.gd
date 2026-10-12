# HUD.gd
extends CanvasLayer

signal evolution_selected(floor_num: int, choice_index: int)

const ERA_NAMES = {
    1: "ERA 1: EDIACARAN SOUP (600 MYA)",
    2: "ERA 2: CAMBRIAN RADIANCE (540 MYA)",
    3: "ERA 3: ORDOVICIAN SEAS (460 MYA)",
    4: "ERA 4: CARBONIFEROUS SWAMPS (350 MYA)",
    5: "ERA 5: APEX EXTINCTION BOUNDARY (250 MYA)"
}

# Shown on the card at the start of each floor: period, its dates and one
# thing that happened then (dates from the ICS chronostratigraphic chart)
const ERA_INFO = {
    1: {"name": "EDIACARAN PERIOD", "dates": "635 to 539 million years ago",
        "fact": "The first large animals appear: soft-bodied creatures grazing on microbial mats, with no shells, eyes or predators yet."},
    2: {"name": "CAMBRIAN PERIOD", "dates": "539 to 485 million years ago",
        "fact": "The Cambrian explosion: most animal body plans appear in a few million years, along with the first eyes, shells and hunters."},
    3: {"name": "ORDOVICIAN PERIOD", "dates": "485 to 444 million years ago",
        "fact": "Sea life diversifies fast, the first jawless fish swim and giant nautiloids rule, until the first great mass extinction."},
    4: {"name": "CARBONIFEROUS PERIOD", "dates": "359 to 299 million years ago",
        "fact": "Vast coal-swamp forests push oxygen far above today's level, so insects like the dragonfly Meganeura grow huge."},
    5: {"name": "PERMIAN PERIOD", "dates": "299 to 252 million years ago",
        "fact": "Synapsids, our own distant relatives, rule the land until the end-Permian extinction wipes out most life on Earth."},
}

# Evolution choices come from data/Lineages.gd (the accurate tree of life)
var lineages = preload("res://data/Lineages.gd")
var codex = preload("res://data/Codex.gd")

var evolution_modal: Control = null

@onready var coins_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Coins/Label

@onready var keys_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Keys/Label
@onready var hearts_container = $HUDPanel/MarginContainer/HBoxContainer/Hearts
@onready var floor_label = $HUDPanel/MarginContainer/HBoxContainer/FloorLabel
@onready var dna_label = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaLabel
@onready var dna_bar = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaBar
@onready var ability_label = $HUDPanel/MarginContainer/HBoxContainer/AbilityContainer/AbilityLabel
@onready var ability_bar = $HUDPanel/MarginContainer/HBoxContainer/AbilityContainer/AbilityBar
@onready var settings_btn = $HUDPanel/MarginContainer/HBoxContainer/SettingsBtn

@onready var minimap_ctrl = $MinimapContainer/Minimap

@onready var boss_container = $BossHealthContainer
@onready var boss_bar = $BossHealthContainer/ProgressBar
@onready var boss_name_label = $BossHealthContainer/Label

@onready var item_banner = $ItemBanner
@onready var item_title = $ItemBanner/Title
@onready var item_desc = $ItemBanner/Desc

# Settings Modal Nodes
@onready var settings_modal = $SettingsModal
@onready var brightness_label = $SettingsModal/Panel/Margin/VBox/BrightnessSection/BrightnessLabel
@onready var brightness_slider = $SettingsModal/Panel/Margin/VBox/BrightnessSection/BrightnessSlider
@onready var display_option = $SettingsModal/Panel/Margin/VBox/DisplaySection/DisplayOption
@onready var volume_label = $SettingsModal/Panel/Margin/VBox/VolumeSection/VolumeLabel
@onready var volume_slider = $SettingsModal/Panel/Margin/VBox/VolumeSection/VolumeSlider
@onready var resume_btn = $SettingsModal/Panel/Margin/VBox/ResumeBtn

@onready var game_over_screen = $GameOverScreen
@onready var victory_screen = $VictoryScreen

var heart_full_tex = preload("res://assets/pickup_heart.png")
var heart_half_tex = preload("res://assets/pickup_heart_half.png")
var heart_empty_tex = preload("res://assets/pickup_heart_empty.png")

# Minimap data
var dungeon_rooms: Dictionary = {}
var current_room_pos: Vector2i = Vector2i(4, 4)

func _ready():
    boss_container.visible = false
    item_banner.visible = false
    game_over_screen.visible = false
    victory_screen.visible = false
    settings_modal.visible = false
    clear_hearts()
    
    if minimap_ctrl:
        minimap_ctrl.draw.connect(_on_minimap_draw)
        
    setup_settings_ui()
    if TouchControls.should_show():
        use_touch_texts()

func setup_settings_ui():
    settings_btn.pressed.connect(toggle_settings)
    resume_btn.pressed.connect(toggle_settings)
    
    # Initialize display options (1080p Standard)
    display_option.clear()
    display_option.add_item("Windowed (1280 x 720 - HD)", 0)
    display_option.add_item("Windowed (1920 x 1080 - 1080p Full HD Default)", 1)
    display_option.add_item("Windowed (2560 x 1440 - 2K QHD)", 2)
    display_option.add_item("Fullscreen Mode", 3)
    display_option.select(SettingsManager.window_mode_index)
    display_option.item_selected.connect(_on_display_mode_selected)
    
    # Initialize brightness slider
    brightness_slider.value = SettingsManager.brightness
    update_brightness_label(SettingsManager.brightness)
    brightness_slider.value_changed.connect(_on_brightness_changed)
    
    # Initialize volume slider
    volume_slider.value = SettingsManager.sfx_volume
    update_volume_label(SettingsManager.sfx_volume)
    volume_slider.value_changed.connect(_on_volume_changed)

    # Music volume: a copy of the SFX row, added under it
    var music_section = $SettingsModal/Panel/Margin/VBox/VolumeSection.duplicate()
    music_section.name = "MusicSection"
    $SettingsModal/Panel/Margin/VBox.add_child(music_section)
    $SettingsModal/Panel/Margin/VBox.move_child(music_section, $SettingsModal/Panel/Margin/VBox/VolumeSection.get_index() + 1)
    music_label = music_section.get_node("VolumeLabel")
    var music_slider: HSlider = music_section.get_node("VolumeSlider")
    music_slider.value = SettingsManager.music_volume
    update_music_label(SettingsManager.music_volume)
    music_slider.value_changed.connect(func(val):
        SettingsManager.set_music_volume(val)
        update_music_label(val)
    )

var music_label: Label

# Red edges that flash when the player is hurt
var hurt_vignette: TextureRect

func flash_hurt():
    if hurt_vignette == null:
        var grad = Gradient.new()
        grad.set_color(0, Color(0.8, 0.0, 0.1, 0.0))
        grad.set_color(1, Color(0.85, 0.0, 0.1, 0.9))
        grad.add_point(0.42, Color(0.8, 0.0, 0.1, 0.0))
        var tex = GradientTexture2D.new()
        tex.gradient = grad
        tex.fill = GradientTexture2D.FILL_RADIAL
        tex.fill_from = Vector2(0.5, 0.5)
        tex.fill_to = Vector2(1.05, 1.05)
        tex.width = 256
        tex.height = 256
        hurt_vignette = TextureRect.new()
        hurt_vignette.texture = tex
        hurt_vignette.stretch_mode = TextureRect.STRETCH_SCALE
        hurt_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(hurt_vignette)
        move_child(hurt_vignette, 0)
    hurt_vignette.modulate.a = 1.0
    var tw = create_tween()
    tw.tween_property(hurt_vignette, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)

func update_music_label(val: float):
    music_label.text = "🎵 Music Volume: %d%%" % int(val * 100)

func _unhandled_input(event: InputEvent):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            toggle_settings()

func toggle_settings():
    settings_modal.visible = not settings_modal.visible
    get_tree().paused = settings_modal.visible
    
    if not settings_modal.visible:
        SettingsManager.save_settings()

func _on_brightness_changed(val: float):
    SettingsManager.set_brightness(val)
    update_brightness_label(val)

func update_brightness_label(val: float):
    brightness_label.text = "🔆 Brightness: %d%%" % int(val * 100)

func _on_display_mode_selected(index: int):
    SettingsManager.set_window_mode(index)

func _on_volume_changed(val: float):
    SettingsManager.set_sfx_volume(val)
    update_volume_label(val)

func update_volume_label(val: float):
    volume_label.text = "🔊 SFX Volume: %d%%" % int(val * 100)

func clear_hearts():
    for child in hearts_container.get_children():
        child.queue_free()

func update_health(health: int, max_health: int):
    clear_hearts()
    
    var full_hearts = health / 2
    var half_heart = health % 2 == 1
    var total_containers = max_health / 2
    
    for i in range(total_containers):
        var heart_rect = TextureRect.new()
        heart_rect.custom_minimum_size = Vector2(36, 36)
        heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        
        if i < full_hearts:
            heart_rect.texture = heart_full_tex
        elif i == full_hearts and half_heart:
            heart_rect.texture = heart_half_tex
        else:
            heart_rect.texture = heart_empty_tex
            
        hearts_container.add_child(heart_rect)

func update_inventory(dna: int, keys: int):
    coins_label.text = "%02d" % dna
    keys_label.text = "%02d" % keys

func update_dna(current_dna: int, max_dna: int, level: int):
    dna_label.text = "BIOMASS: %d / %d (LVL %d)" % [current_dna, max_dna, level]
    dna_bar.max_value = max_dna
    dna_bar.value = current_dna

# Phones have no keyboard: name the on-screen buttons instead of keys
func use_touch_texts():
    resume_btn.text = "RESUME GAME"
    # The settings menu pauses the game; make it a thumb-sized pause button
    settings_btn.text = " ⏸ PAUSE "
    settings_btn.custom_minimum_size = Vector2(190, 56)
    settings_btn.add_theme_font_size_override("font_size", 24)
    # Window sizes mean nothing on a phone, which is always fullscreen
    $SettingsModal/Panel/Margin/VBox/DisplaySection.visible = false
    $GameOverScreen/Center/SubLabel.text = "Your genetic lineage was severed.
Tap to Mutate Anew"
    $VictoryScreen/Center/RestartLabel.text = "Tap to Restart Genetic Lineage"

func update_discharge_cooldown(current_cd: float, max_cd: float):
    if not is_instance_valid(ability_label) or not is_instance_valid(ability_bar):
        return
    if current_cd <= 0.0:
        ability_bar.value = 1.0
        ability_label.text = "⚡ ZAP: READY" if TouchControls.should_show() else "⚡ [E / MMB] DISCHARGE: READY"
        ability_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9, 1.0))
    else:
        var ratio = 1.0 - (current_cd / max(0.001, max_cd))
        ability_bar.value = ratio
        ability_label.text = ("⚡ ZAP RECHARGING (%.1fs)" if TouchControls.should_show() else "⚡ [E] RECHARGING (%.1fs)") % current_cd
        ability_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.85, 0.85))

var current_creature_name: String = "PRIMORDIAL PROTOZOA"

func set_current_creature(creature_name: String):
    current_creature_name = creature_name

func update_floor(floor_num: int):
    var era_str = ERA_NAMES.get(floor_num, "ERA %d" % floor_num)
    floor_label.text = "%s | 🧬 %s" % [era_str, current_creature_name]

func update_minimap(rooms: Dictionary, current_pos: Vector2i):
    dungeon_rooms = rooms
    current_room_pos = current_pos
    if minimap_ctrl:
        minimap_ctrl.queue_redraw()

func _on_minimap_draw():
    if dungeon_rooms.is_empty():
        return
        
    var center_screen = minimap_ctrl.size / 2.0
    var cell_size = Vector2(22, 16)
    var gap = Vector2(4, 4)
    var step = cell_size + gap
    
    minimap_ctrl.draw_rect(Rect2(Vector2.ZERO, minimap_ctrl.size), Color(0.04, 0.08, 0.14, 0.75), true)
    minimap_ctrl.draw_rect(Rect2(Vector2.ZERO, minimap_ctrl.size), Color(0.0, 0.7, 0.9, 0.5), false, 2.0)
    
    for pos in dungeon_rooms:
        var r_data = dungeon_rooms[pos]
        var is_current = (pos == current_room_pos)
        var is_visited = r_data.visited
        
        var is_adjacent = false
        for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var n_pos = pos + d
            if dungeon_rooms.has(n_pos) and dungeon_rooms[n_pos].visited:
                is_adjacent = true
                break
                
        if not is_visited and not is_adjacent:
            continue
            
        var offset_grid = pos - current_room_pos
        var draw_pos = center_screen + Vector2(offset_grid.x * step.x, offset_grid.y * step.y) - (cell_size / 2.0)
        var rect = Rect2(draw_pos, cell_size)
        
        var room_col = Color(0.15, 0.25, 0.35, 0.7)
        if is_visited:
            room_col = Color(0.25, 0.45, 0.65, 0.9)
            
        minimap_ctrl.draw_rect(rect, room_col, true)
        
        if is_visited or is_adjacent:
            if r_data.type == 3: # BOSS
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.5, Color(1.0, 0.2, 0.3, 1.0))
            elif r_data.type == 2: # TREASURE / MUTATION
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.0, Color(0.0, 1.0, 0.8, 1.0))
            elif r_data.type == 4: # SHOP / SHRINE
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.0, Color(1.0, 0.85, 0.2, 1.0))
                
        if is_current:
            minimap_ctrl.draw_rect(rect, Color(0.0, 1.0, 1.0, 1.0), false, 2.5)
        else:
            minimap_ctrl.draw_rect(rect, Color(0.1, 0.2, 0.3, 0.8), false, 1.0)

func show_boss_health(current: float, max_value: float, boss_title: String = ""):
    boss_container.visible = true
    boss_bar.max_value = max_value
    boss_bar.value = current
    if boss_title != "" and boss_name_label:
        boss_name_label.text = boss_title
    if current <= 0:
        boss_container.visible = false

func hide_boss_health():
    boss_container.visible = false

# near_top keeps the banner clear of the room centre, where the player spawns
func show_item_banner(title: String, desc: String, near_top: bool = false):
    item_banner.offset_top = -440.0 if near_top else -80.0
    item_banner.offset_bottom = -280.0 if near_top else 80.0
    item_banner.visible = true
    item_title.text = title
    item_desc.text = desc
    item_banner.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(item_banner, "modulate:a", 0.0, 0.4).set_delay(1.8)
    tween.tween_callback(func(): item_banner.visible = false)

func show_game_over():
    game_over_screen.visible = true
    
func show_victory(summary: Dictionary = {}):
    victory_screen.visible = true
    var label = $VictoryScreen/Center/Label
    var sublabel = $VictoryScreen/Center/SubLabel
    if summary.is_empty():
        label.text = "600 MILLION YEARS OF EVOLUTION COMPLETE!"
        sublabel.text = "Your lineage dominated Earth through all 5 eras!"
    else:
        label.text = "APEX EVOLUTION: VICTORY!"
        var text = "Final Evolved Lineage: " + summary.get("title", "Apex Organism") + "\n"
        text += summary.get("clade", "") + "\n\nPhylogenetic Path Across Earth's Eras:\n"
        for h in summary.get("history", []):
            text += "• Era %d: %s (%s)\n" % [h["floor"], h["title"], h["clade"]]
            if h.get("living", "") != "":
                text += "    Living today: %s\n" % h["living"]
        text += "\nCodex: %d of %d lineages discovered" % [codex.load_discovered().size(), lineages.TREE.size()]
        sublabel.text = text

func show_evolution_modal(floor_num: int, current_path: Array = []):
    var path_key = lineages.path_key(current_path)
    var form = lineages.get_form(path_key)
    var child_paths = lineages.get_child_paths(path_key)

    _create_evolution_modal()

    var header = evolution_modal.get_node("CenterBox/Header") as Label
    var subheader = evolution_modal.get_node("CenterBox/SubHeader") as Label
    header.text = "🧬 " + ERA_NAMES.get(floor_num, "ERA %d" % floor_num) + " COMPLETE"

    var cards_row = evolution_modal.get_node("CenterBox/CardsRow") as HBoxContainer
    for c in cards_row.get_children():
        c.queue_free()

    if child_paths.is_empty():
        # No real split known for this lineage here: offer an in-clade upgrade
        var name_text = form.get("name", "YOUR LINEAGE") if not form.is_empty() else "YOUR LINEAGE"
        subheader.text = "No real split is known for your lineage in this era, so it adapts instead:"
        _build_choice_card(cards_row, floor_num, 0, {
            "title": "REFINE: " + name_text,
            "clade": "Lineage: " + form.get("clade", "in-clade adaptation"),
            "desc": "Evolution does not always branch. Your lineage stays itself and gets better at what it does.",
            "perks": "+1.5 damage, +20 speed, faster fire\n+2 max health (heals 2)",
            "color": form.get("color", Color(0.0, 1.0, 0.85)),
        }, 1)
    else:
        subheader.text = "Pick which real descendant group your lineage becomes:"
        for i in range(child_paths.size()):
            var child = lineages.get_form(child_paths[i])
            var desc = child.fact + "\n\nLiving today: " + child.living_example + "\n" + child.clade_path
            if not codex.is_discovered(child.id):
                desc = "NEW TO YOUR CODEX\n" + desc
            _build_choice_card(cards_row, floor_num, i, {
                "title": child.name,
                "clade": "Lineage: " + child.clade,
                "desc": desc,
                "perks": lineages.describe_perks(child),
                "color": child.color,
            }, child_paths.size())

    evolution_modal.visible = true
    get_tree().paused = true

func _create_evolution_modal():
    if evolution_modal:
        return
        
    evolution_modal = Control.new()
    evolution_modal.name = "EvolutionModal"
    evolution_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    evolution_modal.visible = false
    evolution_modal.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(evolution_modal)
    
    var bg = ColorRect.new()
    bg.name = "Backdrop"
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.02, 0.04, 0.08, 0.95)
    evolution_modal.add_child(bg)
    
    var center_box = VBoxContainer.new()
    center_box.name = "CenterBox"
    # Fill the screen with a margin so the cards stay centred on any aspect
    center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 60)
    center_box.alignment = BoxContainer.ALIGNMENT_CENTER
    center_box.add_theme_constant_override("separation", 24)
    evolution_modal.add_child(center_box)
    
    var header = Label.new()
    header.name = "Header"
    header.text = "🧬 EPOCH TRANSCENDED: GEOLOGICAL EVOLUTION"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 40)
    header.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
    center_box.add_child(header)
    
    var subheader = Label.new()
    subheader.name = "SubHeader"
    subheader.text = "Select your taxonomic branch to permanently alter your organism's lineage:"
    subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subheader.add_theme_font_size_override("font_size", 22)
    subheader.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
    center_box.add_child(subheader)
    
    var cards_row = HBoxContainer.new()
    cards_row.name = "CardsRow"
    cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
    cards_row.add_theme_constant_override("separation", 50)
    center_box.add_child(cards_row)

func _build_choice_card(parent: HBoxContainer, floor_num: int, choice_idx: int, data: Dictionary, total: int = 2):
    var card = PanelContainer.new()
    # Up to four cards share the row
    var gap = 50 if total <= 2 else 24
    card.custom_minimum_size = Vector2(min(680.0, (1640.0 - gap * (total - 1)) / total), 560)
    parent.add_theme_constant_override("separation", gap)
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.09, 0.15, 0.96)
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    style.border_color = data["color"]
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_right = 12
    style.corner_radius_bottom_left = 12
    style.shadow_color = data["color"] * Color(1, 1, 1, 0.25)
    style.shadow_size = 20
    card.add_theme_stylebox_override("panel", style)
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 36)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_right", 36)
    margin.add_theme_constant_override("margin_bottom", 30)
    card.add_child(margin)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    margin.add_child(vbox)
    
    var clade_lbl = Label.new()
    clade_lbl.text = data["clade"].to_upper()
    clade_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    clade_lbl.add_theme_font_size_override("font_size", 16)
    clade_lbl.add_theme_color_override("font_color", data["color"] * Color(1, 1, 1, 0.8))
    vbox.add_child(clade_lbl)
    
    var title_lbl = Label.new()
    title_lbl.text = data["title"]
    title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_lbl.add_theme_font_size_override("font_size", 28)
    title_lbl.add_theme_color_override("font_color", Color.WHITE)
    vbox.add_child(title_lbl)
    
    var desc_lbl = Label.new()
    desc_lbl.text = data["desc"]
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_lbl.add_theme_font_size_override("font_size", 17)
    desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
    vbox.add_child(desc_lbl)
    
    var sep = HSeparator.new()
    vbox.add_child(sep)
    
    var perks_lbl = Label.new()
    perks_lbl.text = data["perks"]
    perks_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    perks_lbl.add_theme_font_size_override("font_size", 19)
    perks_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.75))
    vbox.add_child(perks_lbl)
    
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)
    
    var btn = Button.new()
    btn.text = "⚡ MUTATE & ADAPT"
    btn.custom_minimum_size = Vector2(0, 56)
    btn.add_theme_font_size_override("font_size", 22)
    btn.pressed.connect(func():
        _on_evolution_choice_clicked(floor_num, choice_idx)
    )
    vbox.add_child(btn)
    
    parent.add_child(card)

func _on_evolution_choice_clicked(floor_num: int, choice_idx: int):
    if evolution_modal:
        evolution_modal.visible = false
    get_tree().paused = false
    SoundManager.play_sfx("evolve")
    evolution_selected.emit(floor_num, choice_idx)

# ---- How-to-play cards ----
# A card at the start of each floor: the era and what you are on the left,
# how to play on the right. Pauses until a tap or key.

var intro_card: Control = null
var intro_ready_time: int = 0

# One card per floor: the era on the left, how to play on the right
func show_era_card(floor_num: int, form: Dictionary):
    var touch = TouchControls.should_show()
    var weapon = lineages.weapon_stats(form.get("weapon", "vesicle"))
    var rows: Array
    if touch:
        rows = [
            ["MOVE", "Drag the left side of the screen"],
            ["AIM & FIRE", "Drag the right side; you fire while you hold it"],
            ["DASH", "Tap DASH to dart away, untouchable for a moment"],
            ["ZAP", "Tap ZAP for an electric burst around you (recharges)"],
            ["PAUSE", "⏸ PAUSE, top right"],
        ]
    else:
        rows = [
            ["MOVE", "W A S D or the arrow keys"],
            ["AIM & FIRE", "I J K L, or hold the left mouse button"],
            ["DASH", "Space / Shift / right-click to dart away, untouchable for a moment"],
            ["ZAP", "E / Q / middle-click for an electric burst around you (recharges)"],
            ["PAUSE", "Esc"],
        ]
    rows.append(["SIGHT", lineages.describe_vision(form).trim_prefix("Vision: ")])
    var color: Color = form.get("color", Color(0.0, 0.95, 1.0))
    var era: Dictionary = ERA_INFO.get(clampi(floor_num, 1, 5), {})
    var vbox = _open_card(color, 1300)

    var cols = HBoxContainer.new()
    cols.add_theme_constant_override("separation", 30)
    vbox.add_child(cols)

    var left = VBoxContainer.new()
    left.add_theme_constant_override("separation", 12)
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_stretch_ratio = 0.85
    cols.add_child(left)
    left.add_child(_card_label("ERA %d OF 5" % floor_num, 18, Color(0.75, 0.85, 0.95)))
    left.add_child(_card_label(era.get("name", ""), 36, Color(1.0, 0.85, 0.3)))
    left.add_child(_card_label(era.get("dates", ""), 22, Color(0.2, 1.0, 0.75)))
    left.add_child(_card_label(era.get("fact", ""), 22, Color.WHITE))
    left.add_child(HSeparator.new())
    var who = ("YOU ARE THE " if floor_num == 1 else "YOU ARE NOW ") + form.get("name", current_creature_name)
    left.add_child(_card_label(who, 24, color))
    left.add_child(_card_label("Your attack: %s, %s." % [form.get("weapon_name", "Lysosome vesicles").to_lower(), _weapon_hint(weapon)], 19, Color(0.75, 0.85, 0.95)))

    cols.add_child(VSeparator.new())

    var right = VBoxContainer.new()
    right.add_theme_constant_override("separation", 12)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cols.add_child(right)
    right.add_child(_card_label("HOW TO PLAY", 24, Color(0.2, 1.0, 0.75)))
    _add_rows(right, rows)
    right.add_child(_card_label("Clear each room, beat the era's boss, then pick what your lineage evolves into.", 19, Color(0.75, 0.85, 0.95)))

    _close_card(vbox, "start" if floor_num == 1 else "continue")

func _weapon_hint(weapon: Dictionary) -> String:
    if weapon.get("melee", false):
        return "a close-range %s toward where you aim" % weapon.get("label", "strike")
    return "shot toward where you aim"

func _show_card(title: String, sub: String, rows: Array, footer: String, color: Color, verb: String = "start"):
    var vbox = _open_card(color, 1100)
    var title_lbl = _card_label(title, 36, color)
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_lbl)
    if sub != "":
        var sub_lbl = _card_label(sub, 19, Color(0.75, 0.85, 0.95))
        sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(sub_lbl)
    vbox.add_child(HSeparator.new())
    _add_rows(vbox, rows)
    if footer != "":
        vbox.add_child(HSeparator.new())
        vbox.add_child(_card_label(footer, 19, Color(0.75, 0.85, 0.95)))
    _close_card(vbox, verb)

# Builds the dimmed backdrop and bordered panel; returns the panel's column
func _open_card(color: Color, width: float) -> VBoxContainer:
    if intro_card:
        intro_card.queue_free()
    intro_card = Control.new()
    intro_card.name = "HowToPlay"
    intro_card.set_anchors_preset(Control.PRESET_FULL_RECT)
    intro_card.process_mode = Node.PROCESS_MODE_ALWAYS
    intro_card.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(intro_card)

    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.02, 0.04, 0.08, 0.82)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_card.add_child(bg)

    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_card.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(width, 0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.09, 0.15, 0.97)
    style.set_border_width_all(3)
    style.border_color = color
    style.set_corner_radius_all(12)
    style.shadow_color = color * Color(1, 1, 1, 0.25)
    style.shadow_size = 20
    style.set_content_margin_all(36)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    panel.add_child(vbox)
    return vbox

func _add_rows(parent: Container, rows: Array):
    var grid = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 28)
    grid.add_theme_constant_override("v_separation", 10)
    parent.add_child(grid)
    for r in rows:
        var key = _card_label(r[0], 22, Color(0.2, 1.0, 0.75))
        key.autowrap_mode = TextServer.AUTOWRAP_OFF
        grid.add_child(key)
        var val = _card_label(r[1], 22, Color.WHITE)
        val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_child(val)

func _close_card(vbox: VBoxContainer, verb: String):
    var hint = _card_label(("Tap anywhere to " if TouchControls.should_show() else "Press any key or click to ") + verb, 20, Color(1.0, 0.85, 0.3))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(hint)
    var tw = hint.create_tween().set_loops()
    tw.tween_property(hint, "modulate:a", 0.45, 0.7)
    tw.tween_property(hint, "modulate:a", 1.0, 0.7)

    # Ignore the tap or click that opened the card (e.g. on an evolution card)
    intro_ready_time = Time.get_ticks_msec() + 400
    get_tree().paused = true

func _card_label(text: String, size: int, color: Color) -> Label:
    var l = Label.new()
    l.text = text
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l

func is_card_up() -> bool:
    return intro_card != null

func dismiss_card():
    if intro_card == null:
        return
    intro_card.queue_free()
    intro_card = null
    get_tree().paused = false

func _input(event: InputEvent):
    if intro_card == null:
        return
    var pressed = (event is InputEventKey and event.pressed and not event.echo) \
        or (event is InputEventMouseButton and event.pressed) \
        or (event is InputEventScreenTouch and event.pressed) \
        or (event is InputEventJoypadButton and event.pressed)
    if not pressed:
        return
    get_viewport().set_input_as_handled()
    if Time.get_ticks_msec() >= intro_ready_time:
        dismiss_card()
