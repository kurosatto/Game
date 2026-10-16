# HUD.gd
extends CanvasLayer

signal evolution_selected(floor_num: int, choice_index: int)
signal adaptation_selected(id: String)

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
const UI = preload("res://data/UIStyle.gd")
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
    boss_bar.add_theme_stylebox_override("fill", UI.bar_box(UI.CORAL))
    $MinimapContainer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    
    if minimap_ctrl:
        minimap_ctrl.draw.connect(_on_minimap_draw)
        
    setup_settings_ui()
    if TouchControls.should_show():
        use_touch_texts()
    # No shop, so no coin counter; kills leave elements to grow parts from
    $HUDPanel/MarginContainer/HBoxContainer/Counters/Coins.visible = false
    _setup_element_bar()

func setup_settings_ui():
    settings_btn.pressed.connect(toggle_settings)
    resume_btn.pressed.connect(toggle_settings)
    var menu_btn = Button.new()
    menu_btn.text = "MAIN MENU (ends this run)"
    menu_btn.custom_minimum_size = Vector2(0, 44)
    menu_btn.add_theme_font_size_override("font_size", 16)
    menu_btn.pressed.connect(func():
        SettingsManager.save_settings()
        get_tree().paused = false
        get_tree().change_scene_to_file("res://MainMenu.tscn")
    )
    resume_btn.get_parent().add_child(menu_btn)
    
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
            if is_grow_up():
                hide_grow_screen()
            else:
                toggle_settings()
        elif event.keycode == KEY_G or event.keycode == KEY_TAB:
            if is_grow_up():
                hide_grow_screen()
            else:
                show_grow_screen()

func toggle_settings():
    settings_modal.visible = not settings_modal.visible
    get_tree().paused = settings_modal.visible
    if settings_modal.visible:
        show_pause_info()
    
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

# ---- Elements and the GROW screen (data/Biominerals.gd) ----
# The top bar lists the elements eaten so far, with a GROW button that
# lights up when something can be grown. The GROW screen pauses the game:
# tap a part to read about it, then GROW it; stay to grow more, DONE to go.
const BIOMINERALS = preload("res://data/Biominerals.gd")
var element_label: RichTextLabel = null
var grow_btn: Button = null
var grow_modal: Control = null
var grow_grid: GridContainer = null
var grow_have: RichTextLabel = null
var grow_title: Label = null
var grow_body: Label = null
var grow_go: Button = null
var grow_selected: String = ""
var _have: Dictionary = {}
var _growable: int = 0

func _setup_element_bar():
    var box = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer
    dna_label.visible = false
    dna_bar.visible = false
    box.custom_minimum_size.x = 430
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    box.add_child(row)
    element_label = RichTextLabel.new()
    element_label.bbcode_enabled = true
    element_label.fit_content = true
    element_label.scroll_active = false
    element_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    element_label.custom_minimum_size = Vector2(300, 0)
    element_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    element_label.add_theme_font_size_override("normal_font_size", 17)
    element_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(element_label)
    grow_btn = Button.new()
    grow_btn.text = "🧬 GROW"
    grow_btn.custom_minimum_size = Vector2(110, 34)
    grow_btn.add_theme_font_size_override("font_size", 16)
    grow_btn.focus_mode = Control.FOCUS_NONE
    for state in ["normal", "hover", "pressed", "disabled"]:
        grow_btn.add_theme_stylebox_override(state, UI.button_box(state, UI.LEAF))
    grow_btn.pressed.connect(show_grow_screen)
    row.add_child(grow_btn)
    update_elements({}, 0)

func _element_text(have: Dictionary, size: int = 17) -> String:
    var parts: Array = []
    for el in BIOMINERALS.ORDER:
        var c: Color = BIOMINERALS.ELEMENTS[el].color
        parts.append("[color=#%s]%s[/color] %d" % [c.to_html(false), el, int(have.get(el, 0.0))])
    return "   ".join(parts)

var _grow_hinted: bool = false

func update_elements(have: Dictionary, growable: int):
    _have = have
    _growable = growable
    if growable > 0 and not _grow_hinted:
        _grow_hinted = true
        var how = "Tap GROW" if TouchControls.should_show() else "Press G or click GROW"
        show_item_banner("🧬 READY TO GROW", "You have eaten enough elements to grow a new part. %s to choose one." % how)
    if element_label:
        element_label.text = _element_text(have)
    if grow_btn:
        grow_btn.text = ("🧬 GROW %d" % growable) if growable > 0 else "🧬 GROW"
        grow_btn.modulate = Color(1.25, 1.25, 1.05) if growable > 0 else Color(0.75, 0.75, 0.75)
    if grow_modal and grow_modal.visible:
        _fill_grow_screen()

func show_grow_screen():
    if is_card_up() or (evolution_modal and evolution_modal.visible) or settings_modal.visible:
        return
    if grow_modal == null:
        _create_grow_screen()
    grow_selected = ""
    _fill_grow_screen()
    grow_modal.visible = true
    get_tree().paused = true

func hide_grow_screen():
    if grow_modal:
        grow_modal.visible = false
    get_tree().paused = false

func is_grow_up() -> bool:
    return grow_modal != null and grow_modal.visible

func _create_grow_screen():
    grow_modal = Control.new()
    grow_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    grow_modal.process_mode = Node.PROCESS_MODE_ALWAYS
    grow_modal.visible = false
    add_child(grow_modal)
    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.02, 0.05, 0.04, 0.99)
    grow_modal.add_child(bg)
    var col = VBoxContainer.new()
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
    col.add_theme_constant_override("separation", 14)
    grow_modal.add_child(col)
    var header = Label.new()
    header.text = "🧬 GROW FROM WHAT YOU HAVE EATEN"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 34)
    header.add_theme_color_override("font_color", UI.SUN)
    col.add_child(header)
    grow_have = RichTextLabel.new()
    grow_have.bbcode_enabled = true
    grow_have.fit_content = true
    grow_have.scroll_active = false
    grow_have.add_theme_font_size_override("normal_font_size", 24)
    col.add_child(grow_have)
    grow_grid = GridContainer.new()
    grow_grid.columns = 4
    grow_grid.add_theme_constant_override("h_separation", 12)
    grow_grid.add_theme_constant_override("v_separation", 12)
    grow_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    col.add_child(grow_grid)
    var info = PanelContainer.new()
    info.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 22, 0.9, 18.0))
    info.custom_minimum_size = Vector2(0, 230)
    col.add_child(info)
    var irow = HBoxContainer.new()
    irow.add_theme_constant_override("separation", 20)
    info.add_child(irow)
    var itext = VBoxContainer.new()
    itext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    irow.add_child(itext)
    grow_title = Label.new()
    grow_title.add_theme_font_size_override("font_size", 24)
    grow_title.add_theme_color_override("font_color", UI.SUN)
    itext.add_child(grow_title)
    grow_body = Label.new()
    grow_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    grow_body.add_theme_font_size_override("font_size", 19)
    grow_body.add_theme_color_override("font_color", UI.CREAM)
    itext.add_child(grow_body)
    var btns = VBoxContainer.new()
    btns.add_theme_constant_override("separation", 10)
    irow.add_child(btns)
    grow_go = Button.new()
    grow_go.text = "🧬 GROW IT"
    grow_go.custom_minimum_size = Vector2(240, 60)
    grow_go.add_theme_font_size_override("font_size", 22)
    for state in ["normal", "hover", "pressed", "disabled"]:
        grow_go.add_theme_stylebox_override(state, UI.button_box(state, UI.LEAF))
    grow_go.pressed.connect(_on_grow_pressed)
    btns.add_child(grow_go)
    var done = Button.new()
    done.text = "DONE"
    done.custom_minimum_size = Vector2(240, 60)
    done.add_theme_font_size_override("font_size", 22)
    for state in ["normal", "hover", "pressed", "disabled"]:
        done.add_theme_stylebox_override(state, UI.button_box(state, UI.MEMBRANE))
    done.pressed.connect(hide_grow_screen)
    btns.add_child(done)

func _fill_grow_screen():
    var player = get_tree().get_first_node_in_group("player")
    var taken: Dictionary = player.adaptations_taken if player else {}
    grow_have.text = "[center]You have:   " + _element_text(_have, 24) + "[/center]"
    for c in grow_grid.get_children():
        grow_grid.remove_child(c)
        c.queue_free()
    for r in BIOMINERALS.RECIPES:
        var n = taken.get(r.id, 0)
        var maxed = r.get("once", false) and n > 0
        var ok = BIOMINERALS.can_grow(r, _have, taken)
        var tile = Button.new()
        tile.custom_minimum_size = Vector2(415, 112)
        tile.focus_mode = Control.FOCUS_NONE
        tile.toggle_mode = false
        var tint = UI.LEAF if ok else (UI.SUN if r.id == grow_selected else UI.MEMBRANE)
        for state in ["normal", "hover", "pressed", "disabled"]:
            tile.add_theme_stylebox_override(state, UI.button_box(state, tint))
        if r.id == grow_selected:
            tile.add_theme_stylebox_override("normal", UI.button_box("pressed", tint))
        tile.modulate = Color(1, 1, 1, 1.0 if (ok or r.id == grow_selected) else 0.6)
        tile.pressed.connect(func():
            grow_selected = r.id
            _fill_grow_screen()
        )
        var v = VBoxContainer.new()
        v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        v.add_theme_constant_override("separation", 2)
        tile.add_child(v)
        var t = Label.new()
        t.text = r.name + (" ×%d" % n if n > 0 else "")
        t.add_theme_font_size_override("font_size", 19)
        t.add_theme_color_override("font_color", UI.SUN if ok else UI.CREAM)
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        v.add_child(t)
        var cost = RichTextLabel.new()
        cost.bbcode_enabled = true
        cost.fit_content = true
        cost.scroll_active = false
        cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cost.add_theme_font_size_override("normal_font_size", 17)
        cost.text = "GROWN" if maxed else _cost_bbcode(BIOMINERALS.cost_of(r, n))
        v.add_child(cost)
        var e = Label.new()
        e.text = r.effect
        e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        e.add_theme_font_size_override("font_size", 15)
        e.add_theme_color_override("font_color", UI.LEAF)
        e.mouse_filter = Control.MOUSE_FILTER_IGNORE
        v.add_child(e)
        grow_grid.add_child(tile)
    var sel = BIOMINERALS.get_recipe(grow_selected)
    if sel.is_empty():
        grow_title.text = "Tap a part to see what it is made of"
        grow_body.text = "Prey leaves behind the elements its body was built from. Hunt different animals to gather different elements. Parts lit green can be grown now."
        grow_go.disabled = true
    else:
        grow_title.text = sel.name
        var el_facts: Array = []
        for el in sel.cost:
            el_facts.append(BIOMINERALS.ELEMENTS[el].name + ": " + BIOMINERALS.ELEMENTS[el].fact)
        grow_body.text = sel.fact + "\n" + sel.effect + "\n\n" + "\n".join(el_facts)
        grow_go.disabled = not BIOMINERALS.can_grow(sel, _have, taken)

func _cost_bbcode(cost: Dictionary) -> String:
    var parts: Array = []
    for el in BIOMINERALS.ORDER:
        if cost.has(el):
            var c: Color = BIOMINERALS.ELEMENTS[el].color
            var short = int(_have.get(el, 0.0)) < cost[el]
            parts.append("[color=#%s]%d %s[/color]" % [("ff7766" if short else c.to_html(false)), cost[el], el])
    return "Needs " + "  ".join(parts)

func _on_grow_pressed():
    var player = get_tree().get_first_node_in_group("player")
    if player and player.grow(grow_selected):
        var r = BIOMINERALS.get_recipe(grow_selected)
        last_banner = [r.name, r.effect + "\n" + r.fact]
        _fill_grow_screen()
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("check_challenges"):
            main.check_challenges()

func update_dna(current_dna: int, max_dna: int, level: int):
    dna_label.text = "🧬 BIOMASS %d / %d" % [current_dna, max_dna]
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
        ability_label.add_theme_color_override("font_color", UI.AQUA)
    else:
        var ratio = 1.0 - (current_cd / max(0.001, max_cd))
        ability_bar.value = ratio
        ability_label.text = ("⚡ ZAP RECHARGING (%.1fs)" if TouchControls.should_show() else "⚡ [E] RECHARGING (%.1fs)") % current_cd
        ability_label.add_theme_color_override("font_color", UI.MUTED)

var current_creature_name: String = "PRIMORDIAL PROTOZOA"

func set_current_creature(creature_name: String):
    current_creature_name = creature_name

var current_floor: int = 1

func update_floor(floor_num: int):
    current_floor = floor_num
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
    
    var ci = minimap_ctrl.get_canvas_item()
    UI.panel(UI.MEMBRANE, 18, 0.78, 0.0).draw(ci, Rect2(Vector2.ZERO, minimap_ctrl.size))
    
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
        
        var room_col = Color(0.2, 0.3, 0.25, 0.65)
        if is_visited:
            room_col = Color(0.42, 0.6, 0.42, 0.95)
        var blob = UI.bar_box(room_col)
        blob.set_corner_radius_all(6)
        if is_current:
            blob.bg_color = UI.CREAM
        blob.draw(ci, rect)
        
        if is_visited or is_adjacent:
            if r_data.type == 3: # BOSS
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.5, UI.CORAL)
            elif r_data.type == 2: # TREASURE / MUTATION
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.0, UI.SUN)
            elif r_data.type == 4: # SHOP / SHRINE
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.0, UI.LEAF)
                

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
    item_banner.offset_top = -435.0 if near_top else -80.0
    item_banner.offset_bottom = -215.0 if near_top else 80.0
    item_banner.visible = true
    item_title.text = title
    item_desc.text = desc
    item_banner.modulate.a = 1.0
    last_banner = [title, desc]
    # Long enough to read: about 4 s plus a second per 25 characters, and the
    # pause screen keeps the latest one for later
    if banner_tween and banner_tween.is_valid():
        banner_tween.kill()
    var hold = clamp(4.0 + desc.length() / 25.0, 4.0, 10.0)
    banner_tween = create_tween()
    banner_tween.tween_property(item_banner, "modulate:a", 0.0, 0.6).set_delay(hold)
    banner_tween.tween_callback(func(): item_banner.visible = false)

var banner_tween: Tween = null
var last_banner: Array = []

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
        # Every card is a direct branch of the current form (Lineages.TREE is
        # keyed by the path of picks), so the run stays on one family tree
        subheader.text = "Your %s lineage splits. Pick which branch of it you become:" % form.get("name", "ancestral").to_lower().capitalize()
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
    bg.color = Color(0.02, 0.05, 0.04, 0.96)
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
    header.add_theme_color_override("font_color", UI.SUN)
    center_box.add_child(header)
    
    var subheader = Label.new()
    subheader.name = "SubHeader"
    subheader.text = "Select your taxonomic branch to permanently alter your organism's lineage:"
    subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subheader.add_theme_font_size_override("font_size", 22)
    subheader.add_theme_color_override("font_color", UI.CREAM)
    center_box.add_child(subheader)
    
    var cards_row = HBoxContainer.new()
    cards_row.name = "CardsRow"
    cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
    cards_row.add_theme_constant_override("separation", 50)
    center_box.add_child(cards_row)

func _build_choice_card(parent: HBoxContainer, floor_num: int, choice_idx: int, data: Dictionary, total: int = 2, on_pick: Callable = Callable(), height: float = 560.0, button_text: String = "⚡ MUTATE & ADAPT") -> Button:
    var card = PanelContainer.new()
    # Up to four cards share the row
    var gap = 50 if total <= 2 else 24
    card.custom_minimum_size = Vector2(min(680.0, (1640.0 - gap * (total - 1)) / total), height)
    parent.add_theme_constant_override("separation", gap)
    
    card.add_theme_stylebox_override("panel", UI.panel(data["color"], 32, 0.96, 0.0))
    
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
    clade_lbl.add_theme_color_override("font_color", data["color"].lerp(UI.CREAM, 0.25))
    vbox.add_child(clade_lbl)
    
    var title_lbl = Label.new()
    title_lbl.text = data["title"]
    title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_lbl.add_theme_font_size_override("font_size", 28)
    title_lbl.add_theme_color_override("font_color", UI.SUN)
    vbox.add_child(title_lbl)
    
    var desc_lbl = Label.new()
    desc_lbl.text = data["desc"]
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_lbl.add_theme_font_size_override("font_size", 17)
    desc_lbl.add_theme_color_override("font_color", UI.CREAM)
    vbox.add_child(desc_lbl)
    
    var sep = HSeparator.new()
    vbox.add_child(sep)
    
    var perks_lbl = Label.new()
    perks_lbl.text = data["perks"]
    perks_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    perks_lbl.add_theme_font_size_override("font_size", 19)
    perks_lbl.add_theme_color_override("font_color", UI.LEAF)
    vbox.add_child(perks_lbl)
    
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)
    
    var btn = Button.new()
    btn.text = button_text
    btn.custom_minimum_size = Vector2(0, 56)
    btn.add_theme_font_size_override("font_size", 22)
    for state in ["normal", "hover", "pressed", "disabled"]:
        btn.add_theme_stylebox_override(state, UI.button_box(state, data["color"]))
    if on_pick.is_valid():
        btn.pressed.connect(on_pick)
    else:
        btn.pressed.connect(func():
            _on_evolution_choice_clicked(floor_num, choice_idx)
        )
    vbox.add_child(btn)
    
    parent.add_child(card)
    return btn

func _on_evolution_choice_clicked(floor_num: int, choice_idx: int):
    if evolution_modal:
        evolution_modal.visible = false
    get_tree().paused = false
    SoundManager.play_sfx("evolve")
    evolution_selected.emit(floor_num, choice_idx)

# ---- Pause screen info ----
# Left of the settings: pictures of what you are, the era's animals and your
# adaptations. Tapping (or hovering) one shows its details in the box at the
# bottom, so the screen reads at a glance and the facts wait until asked for.
const PauseTile = preload("res://PauseTile.gd")
var pause_box: PanelContainer = null
var pause_era: Label
var pause_dates: Label
var pause_you: HBoxContainer
var pause_wildlife: HBoxContainer
var pause_adapt: HFlowContainer
var pause_info_title: Label
var pause_info_body: Label
var pause_tiles: Array = []
var pause_default: Array = ["", ""]

func _create_pause_info():
    var panel = settings_modal.get_node("Panel")
    panel.offset_left = 40.0
    panel.offset_right = 600.0
    panel.offset_top = min(panel.offset_top, -270.0)
    panel.offset_bottom = max(panel.offset_bottom, 270.0)
    pause_box = PanelContainer.new()
    pause_box.set_anchors_preset(Control.PRESET_CENTER)
    pause_box.offset_left = -900.0
    pause_box.offset_right = 0.0
    pause_box.offset_top = -440.0
    pause_box.offset_bottom = 440.0
    pause_box.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 28, 0.96, 28.0))
    settings_modal.add_child(pause_box)
    var col = VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    pause_box.add_child(col)

    var era_row = HBoxContainer.new()
    era_row.add_theme_constant_override("separation", 14)
    col.add_child(era_row)
    pause_era = _pause_label(26, UI.SUN, true)
    pause_era.autowrap_mode = TextServer.AUTOWRAP_OFF
    era_row.add_child(pause_era)
    pause_dates = _pause_label(18, UI.MUTED)
    pause_dates.autowrap_mode = TextServer.AUTOWRAP_OFF
    pause_dates.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    era_row.add_child(pause_dates)

    pause_you = HBoxContainer.new()
    pause_you.add_theme_constant_override("separation", 22)
    col.add_child(pause_you)

    col.add_child(_pause_label(17, UI.LEAF, true, "ANIMALS OF THIS ERA"))
    pause_wildlife = HBoxContainer.new()
    pause_wildlife.add_theme_constant_override("separation", 10)
    col.add_child(pause_wildlife)

    col.add_child(_pause_label(17, UI.LEAF, true, "FINDS AND ADAPTATIONS"))
    pause_adapt = HFlowContainer.new()
    pause_adapt.add_theme_constant_override("h_separation", 10)
    pause_adapt.add_theme_constant_override("v_separation", 10)
    col.add_child(pause_adapt)

    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(spacer)

    # The details box: what the last tapped picture is
    var info = PanelContainer.new()
    var sb = UI.panel(UI.SUN, 20, 0.9, 18.0)
    sb.set_border_width_all(2)
    sb.shadow_size = 0
    info.add_theme_stylebox_override("panel", sb)
    info.custom_minimum_size = Vector2(0, 150)
    col.add_child(info)
    var info_col = VBoxContainer.new()
    info_col.add_theme_constant_override("separation", 4)
    info.add_child(info_col)
    pause_info_title = _pause_label(21, UI.SUN, true)
    info_col.add_child(pause_info_title)
    pause_info_body = _pause_label(18, UI.CREAM)
    info_col.add_child(pause_info_body)

func _pause_label(px: int, colour: Color, bold: bool = false, text: String = "") -> Label:
    var l = Label.new()
    l.text = text
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", px)
    l.add_theme_color_override("font_color", colour)
    if bold:
        l.add_theme_font_override("font", load(UI.FONT_BOLD))
    return l

func _pause_tile(parent: Control, tex: Texture2D, frames: int, disc: float, name_text: String, title: String, body: String) -> Control:
    var t = PauseTile.new().setup(tex, frames, disc, name_text)
    t.info_title = title
    t.info_body = body
    t.picked.connect(_on_pause_tile_picked)
    parent.add_child(t)
    pause_tiles.append(t)
    return t

func _on_pause_tile_picked(tile: Control):
    for t in pause_tiles:
        if is_instance_valid(t):
            t.selected = t == tile
    pause_info_title.text = tile.info_title
    pause_info_body.text = tile.info_body

# An icon and a short value, for the stats beside your portrait
func _pause_chip(parent: Control, tex: Texture2D, text: String, colour: Color = UI.CREAM):
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    var icon = TextureRect.new()
    icon.texture = tex
    icon.custom_minimum_size = Vector2(34, 34)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(icon)
    var l = _pause_label(19, colour, false, text)
    l.autowrap_mode = TextServer.AUTOWRAP_OFF
    l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(l)
    parent.add_child(row)

func _icon(name: String) -> Texture2D:
    var p = "res://assets/ui/icons/%s.png" % name
    return load(p) if ResourceLoader.exists(p) else null

func show_pause_info():
    if pause_box == null:
        _create_pause_info()
    for t in pause_tiles:
        if is_instance_valid(t):
            t.queue_free()
    pause_tiles.clear()
    for c in pause_you.get_children() + pause_wildlife.get_children() + pause_adapt.get_children():
        c.queue_free()

    var main = get_tree().get_first_node_in_group("main")
    var player = get_tree().get_first_node_in_group("player")
    var era = ERA_INFO.get(current_floor, {})
    pause_era.text = era.get("name", "ERA %d" % current_floor)
    pause_dates.text = era.get("dates", "")

    # You: your animated sprite (whatever art the player is drawn with) and
    # your numbers as icons
    if main and player and main.has_method("current_form"):
        var form = main.current_form()
        if not form.is_empty():
            var spr: Sprite2D = player.get_node("Sprite2D")
            var w = lineages.weapon_stats(player.current_weapon)
            var body = form.fact
            if w.get("special", "") != "":
                body += "\nAttack: %s. %s" % [player.current_weapon_name, w.special]
            # Forms drawn in code (PlayerBody.gd) have no sprite texture; their
            # sheet in assets/lineages is rendered from the same drawing
            var tex: Texture2D = spr.texture
            var frames: int = spr.hframes
            var spin: float = -PI / 2 + player.heading_offset
            var sheet = "res://assets/lineages/%s_sheet.png" % player.current_character_id
            if tex == null and ResourceLoader.exists(sheet):
                tex = load(sheet)
                frames = 4
                spin = 0.0
            var me = _pause_tile(pause_you, tex, frames, 190.0, "",
                form.name, body)
            me.tint = form.color.clamp()
            me.spin = spin
            var side = VBoxContainer.new()
            side.add_theme_constant_override("separation", 6)
            side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            pause_you.add_child(side)
            side.add_child(_pause_label(30, UI.SUN, true, form.name))
            side.add_child(_pause_label(17, UI.MUTED, false, form.get("clade", "")))
            if form.get("living_example", "") != "":
                side.add_child(_pause_label(17, UI.CREAM, false, "Living today: " + form.living_example))
            var chips = HFlowContainer.new()
            chips.add_theme_constant_override("h_separation", 18)
            chips.add_theme_constant_override("v_separation", 6)
            side.add_child(chips)
            _pause_chip(chips, heart_full_tex, "%d/%d" % [player.health, player.max_health], UI.CORAL)
            _pause_chip(chips, _icon("stat_damage"), "%.1f" % player.damage)
            _pause_chip(chips, _icon("stat_speed"), "%d" % int(player.speed), UI.AQUA)
            var senses = lineages.sense_words(form)
            _pause_chip(chips, _icon("stat_sight"), senses[0])
            _pause_chip(chips, _icon("stat_sense"), senses[2], UI.LEAF)
            _pause_chip(chips, _icon("stat_attack"), player.current_weapon_name, UI.SUN)

    # The era's animals, drawn with their own sprite sheets
    var fauna = preload("res://data/Fauna.gd")
    var f = fauna.FLOORS.get(clampi(current_floor, 1, 5), {})
    for key in ["fly", "pacer"] + fauna.special_types(current_floor):
        var a: Dictionary = f[key]
        var p = "res://assets/fauna/%s_sheet.png" % a.name.to_lower()
        var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
        var frames = int(round(tex.get_width() / float(tex.get_height()))) if tex else 1
        var body = a.fact + ("\n" + a.tip if a.has("tip") else "")
        _pause_tile(pause_wildlife, tex, frames, 128.0, a.name, a.name, body)

    # Treasure finds first (on a sunny disc), then adaptations as icons,
    # stacked ones with a count
    if player:
        for id in player.items_found:
            var it = player.items.get_item(id)
            if it.is_empty():
                continue
            var ti = _pause_tile(pause_adapt, _icon("item_" + id), 1, 92.0, "",
                it.name, it.effect + "\n" + it.fact)
            ti.tint = UI.SUN
            ti.animate = false
    if player and not player.adaptations_taken.is_empty():
        for id in player.adaptations_taken:
            var ad = player.adaptations.get_adaptation(id)
            var n = player.adaptations_taken[id]
            var t = _pause_tile(pause_adapt, _icon("adapt_" + ad.get("icon", id)), 1, 92.0, "",
                ad.name + (" ×%d" % n if n > 1 else ""), ad.effect + "\n" + ad.fact)
            t.badge = n
            t.tint = UI.LEAF
            t.animate = false
    elif player and player.items_found.is_empty():
        var none = _pause_label(18, UI.MUTED, false, "None yet. Eat prey, then GROW parts from its elements.")
        none.autowrap_mode = TextServer.AUTOWRAP_OFF
        pause_adapt.add_child(none)

    # Until something is tapped, the box keeps the last thing that popped up
    var touch = TouchControls.should_show()
    pause_info_title.text = "Tap a picture to learn about it" if touch else "Point at a picture to learn about it"
    pause_info_body.text = ""
    if not last_banner.is_empty() and last_banner[0] != "WILDLIFE OF THIS ERA":
        pause_info_title.text = "Last discovery: " + last_banner[0]
        pause_info_body.text = last_banner[1]

# ---- Adaptations ----
# Shown when the biomass bar fills: three traits from data/Adaptations.gd.
# Reuses the evolution modal's look; buttons wake up after a moment so a
# thumb still on the attack stick can't pick one by accident.
var adaptation_options: Array = [] # what the open adaptation modal offers

func show_adaptation_modal(options: Array, taken: Dictionary = {}):
    adaptation_options = options
    _create_evolution_modal()
    var header = evolution_modal.get_node("CenterBox/Header") as Label
    var subheader = evolution_modal.get_node("CenterBox/SubHeader") as Label
    header.text = "🧬 ADAPTATION"
    subheader.text = "Your lineage has fed well. Natural selection favours one new trait:"
    var cards_row = evolution_modal.get_node("CenterBox/CardsRow") as HBoxContainer
    for c in cards_row.get_children():
        cards_row.remove_child(c)
        c.queue_free()
    var buttons: Array = []
    for i in options.size():
        var a: Dictionary = options[i]
        var times = taken.get(a.id, 0)
        var btn = _build_choice_card(cards_row, 0, i, {
            "title": a.name,
            "clade": "Adaptation" + (" (have %d)" % times if times > 0 else ""),
            "desc": a.fact,
            "perks": a.effect,
            "color": UI.LEAF,
        }, options.size(), _on_adaptation_clicked.bind(a.id), 400.0, "🧬 ADAPT")
        btn.disabled = true
        buttons.append(btn)
    evolution_modal.visible = true
    get_tree().paused = true
    SoundManager.play_sfx("level_up", 1.0)
    await get_tree().create_timer(0.45, true).timeout
    for b in buttons:
        if is_instance_valid(b):
            b.disabled = false

func is_adaptation_up() -> bool:
    return not adaptation_options.is_empty() and evolution_modal != null and evolution_modal.visible

func _on_adaptation_clicked(id: String):
    adaptation_options = []
    if evolution_modal:
        evolution_modal.visible = false
    get_tree().paused = false
    SoundManager.play_sfx("evolve", 1.2)
    adaptation_selected.emit(id)

# ---- How-to-play cards ----
# A card at the start of each floor: the era and what you are on the left,
# how to play on the right. Pauses until a tap or key.

var intro_card: Control = null
var intro_ready_time: int = 0

# The dash row of the era card; forms that can't dash name their escape
func dash_row(form: Dictionary, touch: bool) -> Array:
    var escape = lineages.get_escape(form)
    if escape[0] == "dart":
        if touch:
            return ["DASH", "Tap DASH to dart away, untouchable for a moment"]
        return ["DASH", "Space / Shift / right-click to dart away, untouchable for a moment"]
    var label = lineages.escape_label(form)
    var how = ("Tap " + label) if touch else "Space / Shift / right-click"
    return [label, "%s: %s, %s" % [how, escape[1].to_lower(), escape[2]]]

# One card per floor: the era on the left, how to play on the right
func show_era_card(floor_num: int, form: Dictionary):
    var touch = TouchControls.should_show()
    var weapon = lineages.weapon_stats(form.get("weapon", "vesicle"))
    var rows: Array
    if touch:
        rows = [
            ["MOVE", "Drag the left side of the screen"],
            ["AIM & FIRE", "Drag the right side; you fire while you hold it"],
            dash_row(form, true),
            ["ZAP", "Tap ZAP for an electric burst around you (recharges)"],
            ["PAUSE", "⏸ PAUSE, top right"],
        ]
    else:
        rows = [
            ["MOVE", "W A S D or the arrow keys"],
            ["AIM & FIRE", "I J K L, or hold the left mouse button"],
            dash_row(form, false),
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
    left.add_child(_card_label("ERA %d OF 5" % floor_num, 18, UI.MUTED))
    left.add_child(_card_label(era.get("name", ""), 36, UI.SUN))
    left.add_child(_card_label(era.get("dates", ""), 22, UI.LEAF))
    left.add_child(_card_label(era.get("fact", ""), 22, UI.CREAM))
    left.add_child(HSeparator.new())
    var who = ("YOU ARE THE " if floor_num == 1 else "YOU ARE NOW ") + form.get("name", current_creature_name)
    left.add_child(_card_label(who, 24, color))
    left.add_child(_card_label("Your attack: %s, %s." % [form.get("weapon_name", "Engulf (phagocytosis)").to_lower(), _weapon_hint(weapon)], 19, UI.MUTED))

    cols.add_child(VSeparator.new())

    var right = VBoxContainer.new()
    right.add_theme_constant_override("separation", 12)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cols.add_child(right)
    right.add_child(_card_label("HOW TO PLAY", 24, UI.LEAF))
    _add_rows(right, rows)
    right.add_child(_card_label("Clear each room, beat the era's boss, then pick what your lineage evolves into.", 19, UI.MUTED))

    _close_card(vbox, "start" if floor_num == 1 else "continue")

func _weapon_hint(weapon: Dictionary) -> String:
    var special = weapon.get("special", "")
    var tail = (". " + special) if special != "" else ""
    if weapon.get("melee", false):
        return "a close-range %s toward where you aim%s" % [weapon.get("label", "strike"), tail]
    return "shot toward where you aim" + tail

func _show_card(title: String, sub: String, rows: Array, footer: String, color: Color, verb: String = "start"):
    var vbox = _open_card(color, 1100)
    var title_lbl = _card_label(title, 36, color)
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_lbl)
    if sub != "":
        var sub_lbl = _card_label(sub, 19, UI.MUTED)
        sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(sub_lbl)
    vbox.add_child(HSeparator.new())
    _add_rows(vbox, rows)
    if footer != "":
        vbox.add_child(HSeparator.new())
        vbox.add_child(_card_label(footer, 19, UI.MUTED))
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
    bg.color = Color(0.02, 0.05, 0.04, 0.8)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_card.add_child(bg)

    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_card.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(width, 0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", UI.panel(color, 34, 0.97, 38.0))
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
        var key = _card_label(r[0], 22, UI.LEAF)
        key.autowrap_mode = TextServer.AUTOWRAP_OFF
        grid.add_child(key)
        var val = _card_label(r[1], 22, UI.CREAM)
        val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_child(val)

func _close_card(vbox: VBoxContainer, verb: String):
    var hint = _card_label(("Tap anywhere to " if TouchControls.should_show() else "Press any key or click to ") + verb, 20, UI.SUN)
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
