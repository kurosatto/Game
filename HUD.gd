# HUD.gd
extends CanvasLayer

signal evolution_selected(floor_num: int, choice_index: int)
signal adaptation_selected(id: String)

const ERA_NAMES = {
    1: "ERA 1: EDIACARAN SOUP (600 MYA)",
    2: "ERA 2: CAMBRIAN RADIANCE (540 MYA)",
    3: "ERA 3: ORDOVICIAN SEAS (460 MYA)",
    4: "ERA 4: CARBONIFEROUS SWAMPS (350 MYA)",
    5: "ERA 5: APEX EXTINCTION BOUNDARY (250 MYA)",
    # The sea worlds of floors 4 and 5 (data/Worlds.gd)
    6: "ERA 4: CARBONIFEROUS SEAS (330 MYA)",
    7: "ERA 5: PERMIAN REEF SEAS (260 MYA)",
}
const Worlds = preload("res://data/Worlds.gd")
# The end-Permian extinction finale (data/Endgame.gd), in either world
const FINALE_INFO = {
    "label": "THE GREAT DYING (252 MYA)",
    "name": "THE GREAT DYING",
    "dates": "251.9 million years ago, the end of the Permian",
    "fact_land": "The Siberian Traps are erupting. Gas vents burst, the air is thick with ash, and the last gorgonopsians hunt a dying world.",
    "fact_sea": "The sea is losing its oxygen. Dead, sulfide water wells up from the deep, and the last sea scorpion rakes the mud.",
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
    6: {"name": "CARBONIFEROUS SEAS", "dates": "359 to 299 million years ago",
        "fact": "Warm shallow seas full of crinoid meadows and the strangest sharks that ever lived, with spines, brushes and tooth-shears."},
    7: {"name": "PERMIAN SEAS", "dates": "299 to 252 million years ago",
        "fact": "Sponge reefs, ammonoids and the last trilobites and sea scorpions, until the Great Dying kills nearly all sea life."},
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
@onready var settings_back_btn = $SettingsModal/Panel/Margin/VBox/ResumeBtn
var resume_btn: Button # RESUME on the pause page

@onready var game_over_screen = $GameOverScreen
@onready var victory_screen = $VictoryScreen

var heart_full_tex = preload("res://assets/pickup_heart.png")
var heart_half_tex = preload("res://assets/pickup_heart_half.png")
var heart_empty_tex = preload("res://assets/pickup_heart_empty.png")

# Minimap data
var dungeon_rooms: Dictionary = {}
var current_room_pos: Vector2i = Vector2i(4, 4)

# HUD.tscn's own panels and bars follow the art style's palette (UIStyle)
func restyle_panels():
    var top = UI.panel(UI.MEMBRANE, 32, 0.84, 0.0)
    top.set_border_width_all(0)
    top.border_width_bottom = UI.RIM
    top.corner_radius_top_left = 0
    top.corner_radius_top_right = 0
    $HUDPanel.add_theme_stylebox_override("panel", top)
    $SettingsModal/Panel.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 28, 0.96, 0.0))
    var dna = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaBar
    dna.add_theme_stylebox_override("fill", UI.bar_box(UI.LEAF))
    var ability = $HUDPanel/MarginContainer/HBoxContainer/AbilityContainer/AbilityBar
    ability.add_theme_stylebox_override("fill", UI.bar_box(UI.AQUA))
    ability.add_theme_stylebox_override("background", UI.bar_box(UI.INK.darkened(0.5), 0.7))
    $SettingsModal.color = Color(UI.BACKDROP, $SettingsModal.color.a)
    UI.restyle_tree(self)

func _ready():
    boss_container.visible = false
    _make_banner_card()
    item_banner.visible = false
    game_over_screen.visible = false
    victory_screen.visible = false
    settings_modal.visible = false
    clear_hearts()
    boss_bar.add_theme_stylebox_override("fill", UI.bar_box(UI.CORAL))
    $MinimapContainer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    # Big floors would draw rooms past the map's frame
    minimap_ctrl.clip_contents = true
    # Long era and form names used to push the hearts and buttons off the
    # sides of the top bar; the name gives way instead (ends in "…")
    $HUDPanel/MarginContainer/HBoxContainer/Spacer.visible = false
    floor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    floor_label.clip_text = true
    floor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    
    if minimap_ctrl:
        minimap_ctrl.draw.connect(_on_minimap_draw)
        
    setup_settings_ui()
    restyle_panels()
    if TouchControls.should_show():
        use_touch_texts()
    # No shop, so no coin counter; kills leave elements to grow parts from
    $HUDPanel/MarginContainer/HBoxContainer/Counters/Coins.visible = false
    _setup_element_bar()


func setup_settings_ui():
    settings_btn.pressed.connect(toggle_settings)
    settings_btn.text = " ⏸ PAUSE " # it opens the pause page; settings are on it
    # Settings are their own page, opened from the pause page; BACK returns
    settings_back_btn.text = "BACK"
    settings_back_btn.pressed.connect(show_settings_page.bind(false))
    # On the pad, Start pauses; the top bar's button is for mouse and touch
    settings_btn.focus_mode = Control.FOCUS_NONE
    settings_back_btn.set_meta("pad_default", true)
    _create_pause_info()
    
    # Initialize display options (1080p Standard)
    display_option.clear()
    display_option.add_item("Windowed (1280 x 720 - HD)", 0)
    display_option.add_item("Windowed (1920 x 1080 - 1080p Full HD)", 1)
    display_option.add_item("Windowed (2560 x 1440 - 2K QHD)", 2)
    display_option.add_item("Fullscreen (default)", 3)
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
    var shake = _add_toggle("Screen shake", SettingsManager.screen_shake,
        func(on): SettingsManager.screen_shake = on, music_section)
    if TouchControls.should_show() or Input.get_connected_joypads().size() > 0:
        _add_toggle("Aim assist (shots bend onto nearby animals)", SettingsManager.aim_assist,
            func(on): SettingsManager.aim_assist = on, shake)

var music_label: Label

# On/off rows under the volume sliders
func _add_toggle(text: String, on: bool, set_value: Callable, after: Control) -> CheckButton:
    var t = CheckButton.new()
    t.text = text
    t.button_pressed = on
    t.add_theme_font_size_override("font_size", 16)
    t.toggled.connect(set_value)
    var vbox = $SettingsModal/Panel/Margin/VBox
    vbox.add_child(t)
    vbox.move_child(t, after.get_index() + 1)
    return t

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
    music_label.text = "Music Volume: %d%%" % int(val * 100)

func _unhandled_input(event: InputEvent):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if game_over_screen.visible or victory_screen.visible:
                back_pressed()
            elif is_grow_up():
                hide_grow_screen()
            else:
                toggle_settings()
        elif event.keycode == KEY_G or event.keycode == KEY_TAB:
            pad_grow()

# Gamepad Start / View (PadInput.gd): like Esc, but on an end screen it
# plays again
func pad_pause():
    if game_over_screen.visible or victory_screen.visible:
        if end_screen_ready():
            get_tree().paused = false
            get_tree().reload_current_scene()
    elif is_grow_up():
        hide_grow_screen()
    elif not is_card_up():
        toggle_settings()

# Gamepad Y, or G / Tab: open or close the grow screen
func pad_grow():
    if is_grow_up():
        hide_grow_screen()
    else:
        show_grow_screen()

func toggle_settings():
    # Over an evolution card, a how-to-play card or an end screen the pause
    # screen would unpause the game behind that card when it closes
    if not settings_modal.visible and other_screen_up():
        return
    # On the settings page, Esc / back goes back to the pause page first
    if settings_modal.visible and settings_page_up():
        show_settings_page(false)
        return
    settings_modal.visible = not settings_modal.visible
    get_tree().paused = settings_modal.visible
    if settings_modal.visible:
        display_option.select(SettingsManager.window_mode_index) # F11 may have changed it
        show_settings_page(false)
        show_pause_info()
        UI.reveal(settings_modal, pause_box, 0.16)
    
    if not settings_modal.visible:
        SettingsManager.save_settings()

func settings_page_up() -> bool:
    return $SettingsModal/Panel.visible

# Swap the pause page for the settings page, or back
func show_settings_page(on: bool):
    $SettingsModal/Panel.visible = on
    if pause_box:
        pause_box.visible = not on
    if on:
        UI.reveal(settings_modal, $SettingsModal/Panel, 0.12)
    else:
        SettingsManager.save_settings()

func _on_brightness_changed(val: float):
    SettingsManager.set_brightness(val)
    update_brightness_label(val)

func update_brightness_label(val: float):
    brightness_label.text = "Brightness: %d%%" % int(val * 100)

func _on_display_mode_selected(index: int):
    SettingsManager.set_window_mode(index)

func _on_volume_changed(val: float):
    SettingsManager.set_sfx_volume(val)
    update_volume_label(val)

func update_volume_label(val: float):
    volume_label.text = "SFX Volume: %d%%" % int(val * 100)

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
var grow_eggs: Button = null
const CLUTCH_SEL := "__clutch"
const REPRO = preload("res://data/Reproduction.gd")
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
    # Counts only on the BODY screen (kuro 2026-11-27): in a run they only
    # pay for healing and the clutch, the rest is banked for the lineage
    element_label.visible = false
    box.custom_minimum_size.x = 0
    grow_btn = Button.new()
    grow_btn.text = "BODY"
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
    if growable > 0 and not _grow_hinted and not in_combat():
        _grow_hinted = true
        # No banner over the room: the GROW button itself bounces a few times
        _pulse_grow_btn.call_deferred()
    if element_label:
        element_label.text = _element_text(have)
    _refresh_grow_btn()
    if grow_modal and grow_modal.visible:
        _fill_grow_screen()

func _pulse_grow_btn():
    if not grow_btn:
        return
    grow_btn.pivot_offset = grow_btn.size / 2.0
    var tw = grow_btn.create_tween()
    for i in 3:
        tw.tween_property(grow_btn, "scale", Vector2.ONE * 1.25, 0.16).set_trans(Tween.TRANS_SINE)
        tw.parallel().tween_property(grow_btn, "self_modulate", Color(1.6, 1.5, 1.1), 0.16)
        tw.tween_property(grow_btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.parallel().tween_property(grow_btn, "self_modulate", Color.WHITE, 0.3)
        tw.tween_interval(0.25)

# No growing mid-fight (kuro, 2026-11-23): the GROW screen pauses the game,
# so it was a free time-out with animals all around. It opens again once the
# room is clear; until then the button is greyed and says so.
func in_combat() -> bool:
    var main = get_tree().get_first_node_in_group("main") if is_inside_tree() else null
    return main != null and main.has_method("in_combat") and main.in_combat()

var _grow_fight: bool = false
var _grow_watch: float = 0.0

func _refresh_grow_btn():
    if not grow_btn:
        return
    _grow_fight = in_combat()
    if _grow_fight:
        grow_btn.text = "FIGHTING"
        grow_btn.modulate = Color(0.6, 0.6, 0.6, 0.8)
    else:
        grow_btn.text = ("BODY %d" % _growable) if _growable > 0 else "BODY"
        grow_btn.modulate = Color(1.25, 1.25, 1.05) if _growable > 0 else Color(0.75, 0.75, 0.75)

# Rooms clear and fights start without the elements changing
func _watch_grow_fight(delta: float):
    _grow_watch -= delta
    if _grow_watch > 0.0:
        return
    _grow_watch = 0.25
    if in_combat() != _grow_fight:
        _refresh_grow_btn()
        if not _grow_fight and _growable > 0 and not _grow_hinted:
            update_elements(_have, _growable)

func deny_grow():
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_method("popup_text"):
        player.popup_text(player.global_position + Vector2(0, -80), "CLEAR THE ROOM FIRST", Color(1.0, 0.75, 0.45))
    SoundManager.play_sfx("parry", 0.6, -8.0)
    if grow_btn:
        var tw = grow_btn.create_tween()
        for i in 3:
            tw.tween_property(grow_btn, "position:x", grow_btn.position.x + 6.0, 0.04)
            tw.tween_property(grow_btn, "position:x", grow_btn.position.x - 6.0, 0.04)
        tw.tween_property(grow_btn, "position:x", grow_btn.position.x, 0.04)

func show_grow_screen():
    if other_screen_up() or settings_modal.visible:
        return
    if in_combat():
        deny_grow()
        return
    if grow_modal == null:
        _create_grow_screen()
    grow_selected = ""
    _just_grown = ""
    _fill_grow_screen()
    grow_modal.visible = true
    UI.reveal(grow_modal)
    get_tree().paused = true
    # Start the pad on the first part you can grow
    if PadInput.using_pad:
        for r in BIOMINERALS.run_recipes():
            if _can_grow(r):
                grow_tiles[r.id].tile.grab_focus.call_deferred()
                break

func hide_grow_screen():
    if grow_modal:
        grow_modal.visible = false
    get_tree().paused = false

func is_grow_up() -> bool:
    return grow_modal != null and grow_modal.visible

# A thin bar along the bottom of a part's tile: how close you are to it
class GrowMeter extends Control:
    var frac: float = 0.0
    var col: Color = Color.WHITE
    func _draw():
        var r = Rect2(Vector2.ZERO, size)
        draw_rect(r, Color(0, 0, 0, 0.35))
        if frac > 0.0:
            draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)

# A crystal of an element flying from your stores into the creature
class GrowMote extends Control:
    var col: Color = Color.WHITE
    func _draw():
        var c = size / 2.0
        var pts = PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)])
        draw_colored_polygon(pts, col)
        draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.18, 0.11, 0.06), 1.5, true)

# Holds the portrait's drawing and scales it to fill the frame, whatever the
# form's size (from the outline PlayerBody worked out last frame)
class PortraitFit extends Node2D:
    var body: Node2D = null
    var room: float = 150.0
    func _process(delta: float):
        if body == null or body._hull.size() < 3:
            return
        var r := 1.0
        for q in body._hull:
            r = max(r, q.length())
        var want = clampf(room / (r + 14.0), 1.0, 4.0)
        scale = Vector2.ONE * (want if scale.x < 0.01 or absf(scale.x - want) > 0.6 else lerpf(scale.x, want, 1.0 - exp(-delta * 6.0)))

const GROW_VISIBLE = ["calcite_spines", "keratin_horn", "keratin_claws", "magnetite_teeth",
    "photoreceptors", "calcite_lenses", "zinc_jaws"]
var grow_tiles: Dictionary = {} # recipe id -> {tile, name, cost, effect, icon, meter}
var grow_chips: Dictionary = {} # element -> Label
var grow_change: RichTextLabel = null
var grow_caption: Label = null
var grow_portrait: Control = null
var grow_vp: SubViewport = null
var grow_body_art: Node2D = null
var grow_sheet: TextureRect = null
var _just_grown: String = ""

func _can_grow(r: Dictionary) -> bool:
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_method("can_grow_part"):
        return player.can_grow_part(r)
    return BIOMINERALS.can_grow(r, _have, {})

func _styled_button(text: String, tint: Color, w: float = 240, h: float = 60) -> Button:
    var b = Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, h)
    b.add_theme_font_size_override("font_size", 22)
    for state in ["normal", "hover", "pressed", "disabled"]:
        b.add_theme_stylebox_override(state, UI.button_box(state, tint))
    return b

func _create_grow_screen():
    grow_modal = Control.new()
    grow_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    grow_modal.process_mode = Node.PROCESS_MODE_ALWAYS
    grow_modal.visible = false
    add_child(grow_modal)
    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(UI.BACKDROP, 0.99)
    grow_modal.add_child(bg)
    var col = VBoxContainer.new()
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
    col.add_theme_constant_override("separation", 14)
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    grow_modal.add_child(col)
    var header = Label.new()
    header.text = "WHAT YOU HAVE EATEN"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 32)
    header.add_theme_color_override("font_color", UI.SUN)
    col.add_child(header)
    # Your stores, one chip per element, so each can pulse as it is spent
    var have_row = HBoxContainer.new()
    have_row.alignment = BoxContainer.ALIGNMENT_CENTER
    have_row.add_theme_constant_override("separation", 26)
    col.add_child(have_row)
    var have_l = Label.new()
    have_l.text = "You have:"
    have_l.add_theme_font_size_override("font_size", 24)
    have_l.add_theme_color_override("font_color", UI.CREAM)
    have_row.add_child(have_l)
    for el in BIOMINERALS.ORDER:
        var chip = Label.new()
        chip.add_theme_font_size_override("font_size", 26)
        chip.add_theme_color_override("font_color", BIOMINERALS.ELEMENTS[el].color)
        chip.tooltip_text = BIOMINERALS.ELEMENTS[el].name
        have_row.add_child(chip)
        grow_chips[el] = chip
    grow_grid = GridContainer.new()
    grow_grid.columns = 2
    grow_grid.add_theme_constant_override("h_separation", 12)
    grow_grid.add_theme_constant_override("v_separation", 10)
    grow_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    col.add_child(grow_grid)
    for r in BIOMINERALS.run_recipes():
        _make_grow_tile(r)
    # Lasting parts are grown into the lineage on the main menu now
    var bank_note = Label.new()
    bank_note.text = "Everything you eat is banked for your lineage too: grow lasting parts on the main menu GROW page. Healing or laying here banks less."
    bank_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bank_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    bank_note.add_theme_font_size_override("font_size", 19)
    bank_note.add_theme_color_override("font_color", UI.MUTED)
    col.add_child(bank_note)

    # The info panel: your creature (with the part, if it shows on the body),
    # what the part is, what it changes, and the buttons
    var info = PanelContainer.new()
    info.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 22, 0.9, 14.0))
    info.custom_minimum_size = Vector2(0, 236)
    col.add_child(info)
    var irow = HBoxContainer.new()
    irow.add_theme_constant_override("separation", 20)
    info.add_child(irow)
    var pcol = VBoxContainer.new()
    pcol.add_theme_constant_override("separation", 0)
    irow.add_child(pcol)
    grow_portrait = Control.new()
    grow_portrait.custom_minimum_size = Vector2(300, 260)
    grow_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pcol.add_child(grow_portrait)
    grow_vp = SubViewport.new()
    grow_vp.size = Vector2i(400, 360)
    grow_vp.transparent_bg = true
    grow_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    grow_modal.add_child(grow_vp)
    var holder = PortraitFit.new()
    holder.position = Vector2(200, 180)
    holder.rotation = -PI / 2 # head up, like the codex pictures
    holder.scale = Vector2.ONE * 2.0
    grow_vp.add_child(holder)
    grow_body_art = preload("res://PlayerBody.gd").new()
    holder.body = grow_body_art
    grow_body_art.preview = true
    grow_body_art.preview_live = true
    grow_body_art.move = 0.35
    holder.add_child(grow_body_art)
    var tr = TextureRect.new()
    tr.texture = grow_vp.get_texture()
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tr.set_anchors_preset(Control.PRESET_FULL_RECT)
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tr.material = UI.sepia_material()
    grow_portrait.add_child(tr)
    # Forms without a drawing show their sheet instead (no grown parts)
    grow_sheet = TextureRect.new()
    grow_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    grow_sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    grow_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
    grow_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grow_sheet.material = UI.sepia_material()
    grow_portrait.add_child(grow_sheet)
    grow_caption = Label.new()
    grow_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    grow_caption.add_theme_font_size_override("font_size", 16)
    grow_caption.add_theme_color_override("font_color", UI.MUTED)
    pcol.add_child(grow_caption)

    var itext = VBoxContainer.new()
    itext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    itext.add_theme_constant_override("separation", 4)
    irow.add_child(itext)
    grow_title = Label.new()
    grow_title.add_theme_font_size_override("font_size", 24)
    grow_title.add_theme_color_override("font_color", UI.SUN)
    itext.add_child(grow_title)
    grow_change = RichTextLabel.new()
    grow_change.bbcode_enabled = true
    grow_change.fit_content = true
    grow_change.scroll_active = false
    grow_change.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grow_change.add_theme_font_size_override("normal_font_size", 21)
    grow_change.add_theme_font_size_override("bold_font_size", 21)
    itext.add_child(grow_change)
    grow_body = Label.new()
    grow_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    grow_body.add_theme_font_size_override("font_size", 18)
    grow_body.add_theme_color_override("font_color", UI.CREAM)
    itext.add_child(grow_body)
    var btns = VBoxContainer.new()
    btns.add_theme_constant_override("separation", 10)
    irow.add_child(btns)
    grow_go = _styled_button("HEAL", UI.LEAF)
    grow_go.pressed.connect(_on_grow_pressed)
    btns.add_child(grow_go)
    # Leave young behind (data/Reproduction.gd): first press shows how your
    # lineage does it, the second lays them
    grow_eggs = _styled_button("LAY EGGS", UI.SUN)
    grow_eggs.pressed.connect(_on_eggs_pressed)
    btns.add_child(grow_eggs)
    var done = _styled_button("DONE", UI.MEMBRANE)
    done.pressed.connect(hide_grow_screen)
    btns.add_child(done)

func _make_grow_tile(r: Dictionary):
    var tile = Button.new()
    tile.custom_minimum_size = Vector2(358, 130)
    tile.pressed.connect(_on_grow_tile.bind(r.id))
    tile.focus_entered.connect(func():
        # Moving the pad highlight reads the part, like hovering
        if PadInput.using_pad and grow_selected != r.id:
            grow_selected = r.id
            _fill_grow_screen()
    )
    var row = HBoxContainer.new()
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
    row.offset_bottom = -14
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 12)
    tile.add_child(row)
    var ic = TextureRect.new()
    var icon_path = "res://assets/ui/icons/adapt_%s.png" % r.get("icon", "")
    if ResourceLoader.exists(icon_path):
        ic.texture = load(icon_path)
    ic.custom_minimum_size = Vector2(62, 62)
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ic.material = UI.sepia_material() # inked like the world
    row.add_child(ic)
    var v = VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_theme_constant_override("separation", 0)
    row.add_child(v)
    var t = Label.new()
    t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    t.add_theme_font_size_override("font_size", 18)
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(t)
    var cost = RichTextLabel.new()
    cost.bbcode_enabled = true
    cost.fit_content = true
    cost.scroll_active = false
    cost.autowrap_mode = TextServer.AUTOWRAP_OFF
    cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cost.add_theme_font_size_override("normal_font_size", 17)
    v.add_child(cost)
    var e = Label.new()
    e.text = r.effect
    e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    e.add_theme_font_size_override("font_size", 15)
    e.add_theme_color_override("font_color", UI.LEAF)
    e.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(e)
    var meter = GrowMeter.new()
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    meter.offset_left = 22
    meter.offset_right = -22
    meter.offset_top = -13
    meter.offset_bottom = -8
    tile.add_child(meter)
    grow_grid.add_child(tile)
    grow_tiles[r.id] = {"tile": tile, "name": t, "cost": cost, "effect": e, "icon": ic, "meter": meter}

# Tap a part to read it; tap it again (or A again) to grow it
func _on_grow_tile(id: String):
    if grow_selected == id and _can_grow(BIOMINERALS.get_recipe(id)):
        _on_grow_pressed()
        return
    grow_selected = id
    _just_grown = ""
    _fill_grow_screen()

func _fill_grow_screen():
    var player = get_tree().get_first_node_in_group("player")
    var taken: Dictionary = player.adaptations_taken if player else {}
    var hurt: bool = player != null and player.health < player.max_health
    for el in BIOMINERALS.ORDER:
        grow_chips[el].text = "%s %d" % [el, int(_have.get(el, 0.0))]
    for r in BIOMINERALS.run_recipes():
        var w: Dictionary = grow_tiles[r.id]
        var tile: Button = w.tile
        var n = taken.get(r.id, 0)
        var maxed = r.get("once", false) and n > 0
        var ok = _can_grow(r)
        var sel = r.id == grow_selected
        var tint = UI.LEAF if ok else (UI.SUN if sel else UI.MEMBRANE)
        for state in ["normal", "hover", "pressed", "disabled"]:
            tile.add_theme_stylebox_override(state, UI.button_box(state, tint))
        if sel:
            tile.add_theme_stylebox_override("normal", UI.button_box("pressed", tint))
            tile.add_theme_stylebox_override("hover", UI.button_box("pressed", tint))
        tile.modulate = Color(1, 1, 1, 1.0 if (ok or sel) else 0.62)
        w.icon.modulate = Color(1, 1, 1, 1.0 if ok else 0.55)
        w.name.text = r.name + (" ×%d" % n if n > 0 and not r.has("heal") else "")
        w.name.add_theme_color_override("font_color", UI.SUN if ok else UI.CREAM)
        var frac = BIOMINERALS.progress(r, _have, taken)
        if maxed:
            w.cost.text = "[color=#%s]GROWN[/color]" % UI.LEAF.to_html(false)
            frac = 1.0
        elif r.has("heal") and not hurt and frac >= 1.0:
            w.cost.text = _cost_bbcode(BIOMINERALS.cost_of(r, 0)) + "  [color=#%s](full health)[/color]" % UI.MUTED.to_html(false)
        else:
            w.cost.text = _cost_bbcode(BIOMINERALS.cost_of(r, BIOMINERALS.times_for_cost(r, taken)))
        w.meter.frac = frac
        w.meter.col = UI.LEAF if (ok or maxed) else Color(UI.SUN, 0.85)
        w.meter.queue_redraw()
        if sel and PadInput.using_pad and not tile.has_focus() and grow_modal.visible:
            tile.grab_focus.call_deferred()

    _update_grow_portrait(player, taken)
    var main = get_tree().get_first_node_in_group("main")
    var laid: bool = main != null and main.has_method("has_clutch") and main.has_clutch()
    var mode: Dictionary = REPRO.mode_for(player.current_character_id if player else "")
    grow_eggs.text = "EGGS LAID" if laid else mode.verb
    var eggs_tint = UI.LEAF if (player and player.can_lay_clutch()) else UI.SUN
    for state in ["normal", "hover", "pressed", "disabled"]:
        grow_eggs.add_theme_stylebox_override(state, UI.button_box(state, eggs_tint))
    grow_go.text = "HEAL"
    if grow_selected == CLUTCH_SEL:
        _fill_clutch_info(player, mode, laid)
        return
    var sel_r = BIOMINERALS.get_recipe(grow_selected)
    if sel_r.is_empty():
        grow_title.text = PadInput.prompt("Move to a tile to see what it does", "Tap a tile to see what it does", "Click a tile to see what it does")
        grow_change.text = ""
        grow_body.text = "Prey leaves behind the elements its body was built from. Here you can patch your membrane when hurt, or leave young behind on this floor. The rest goes to your lineage."
        grow_go.disabled = true
        return
    var ok_sel = _can_grow(sel_r)
    grow_title.text = sel_r.name
    if _just_grown == sel_r.id:
        grow_title.text = sel_r.name + "  ·  GROWN!"
    var lines = _grow_changes(sel_r, player)
    var how = ""
    if ok_sel:
        how = "   [color=#%s]%s[/color]" % [UI.MUTED.to_html(false), PadInput.prompt("Press A to grow it", "Tap again to grow it", "Click again to grow it")]
    grow_change.text = "[color=#%s][b]%s[/b][/color]%s" % [UI.LEAF.to_html(false), "   ".join(lines), how]
    var el_facts: Array = []
    for el in sel_r.cost:
        el_facts.append(BIOMINERALS.ELEMENTS[el].name + ": " + BIOMINERALS.ELEMENTS[el].fact)
    grow_body.text = sel_r.fact + "\n" + "\n".join(el_facts)
    grow_go.disabled = not ok_sel

# Your creature, drawn live, with every part grown so far, plus the picked
# part when it is one that shows on the body
func _update_grow_portrait(player, taken: Dictionary):
    var form_id: String = player.current_character_id if player else "ancestral_collar_cell"
    var drawn = preload("res://PlayerBody.gd").has_form(form_id)
    grow_portrait.get_child(0).visible = drawn
    grow_sheet.visible = not drawn
    if drawn:
        if grow_body_art.form_id != form_id or grow_body_art.get_meta("set", false) == false:
            grow_body_art.set_form(form_id)
            grow_body_art.set_meta("set", true)
        var parts = taken.duplicate()
        var showing = grow_selected in GROW_VISIBLE and _just_grown != grow_selected
        if showing:
            parts[grow_selected] = parts.get(grow_selected, 0) + 1
        grow_body_art.preview_parts = parts
        grow_caption.text = ("With " + BIOMINERALS.get_recipe(grow_selected).name.to_lower()) if showing else "You now"
    else:
        var sheet = "res://assets/lineages/%s_sheet.png" % form_id
        if ResourceLoader.exists(sheet):
            var at = AtlasTexture.new()
            at.atlas = load(sheet)
            at.region = Rect2(0, 0, at.atlas.get_width() / 4.0, at.atlas.get_height())
            grow_sheet.texture = at
        grow_caption.text = "You now"

const GROW_STAT_NAMES = {"fire": "Attack rate", "range": "Reach", "crit": "Double-damage hits",
    "dash_cd": "Dash recharge", "zap_power": "Zap power", "stealth": "Stealth"}

# What growing a part would change, as "Sight: Blind → Very poor"
func _grow_changes(r: Dictionary, player) -> Array:
    var out: Array = []
    if player == null:
        return [r.effect]
    if r.has("heal"):
        out.append("Health ♥ %s → %s" % [_hearts(player.health), _hearts(min(player.max_health, player.health + int(r.heal)))])
        return out
    var m: Dictionary = player.adaptation_mods()
    var words = lineages.VISION_WORDS
    for k in r.get("mods", {}):
        var d = r.mods[k]
        match k:
            "vision":
                var v = int(player.vision)
                out.append("Sight %s → %s" % [words[v], words[min(10, v + int(d))]])
            "sense":
                out.append("Other sense +%d" % int(d))
            "hp":
                out.append("Hearts %s → %s" % [_hearts(player.max_health), _hearts(player.max_health + int(d))])
            "damage":
                var cur = m.get("damage", 0.0)
                out.append("Damage %.1f → %.1f" % [player.damage, player.damage * (1.0 + cur + d) / (1.0 + cur)])
            "speed":
                var cur = m.get("speed", 0.0)
                out.append("Speed %d → %d" % [int(player.speed), int(player.speed * (1.0 + cur + d) / (1.0 + cur))])
            "armour":
                out.append("Armour %d → %d" % [int(m.get("armour", 0)), int(m.get("armour", 0) + d)])
            "thorns":
                out.append("Spine pricks %d → %d" % [int(m.get("thorns", 0)), int(m.get("thorns", 0) + d)])
            "regen":
                out.append("Heal per room ½♥ × %d → %d" % [int(m.get("regen", 0)), int(m.get("regen", 0) + d)])
            "knockback":
                out.append("Knockback %d → %d" % [int(m.get("knockback", 0) / 260.0), int((m.get("knockback", 0) + d) / 260.0)])
            "perk":
                out.append("New: " + r.effect)
            _:
                var name = GROW_STAT_NAMES.get(k, k.capitalize())
                out.append("%s +%d%% → +%d%%" % [name, int(round(m.get(k, 0.0) * 100)), int(round((m.get(k, 0.0) + d) * 100))])
    return out

func _hearts(hp: int) -> String:
    var h = hp / 2.0
    return ("%d" % int(h)) if is_equal_approx(h, floor(h)) else ("%.1f" % h)

func _cost_bbcode(cost: Dictionary) -> String:
    var parts: Array = []
    for el in BIOMINERALS.ORDER:
        if cost.has(el):
            var c: Color = BIOMINERALS.ELEMENTS[el].color
            var short = int(_have.get(el, 0.0)) < cost[el]
            parts.append("[color=#%s]%d %s[/color]" % [("ff7766" if short else c.to_html(false)), cost[el], el])
    return "Needs " + "  ".join(parts)

# How your lineage leaves young, what it costs and what you hatch with
func _fill_clutch_info(player, mode: Dictionary, laid: bool):
    var ok = player != null and player.can_lay_clutch()
    grow_go.text = "LAY"
    grow_go.disabled = not ok
    grow_title.text = mode.name.to_upper() + ("  ·  LAID!" if _just_grown == CLUTCH_SEL else "")
    var hp = REPRO.hatch_health(player.current_character_id, player.max_health) if player else 2
    var hearts = ("%d" % (hp / 2)) + ("½" if hp % 2 == 1 else "")
    var young = "a daughter cell carries on" if mode.verb == "SPLIT OFF A CELL" else "a young one hatches"
    var line = "If you die on this floor, %s here with %s ♥" % [young, hearts]
    var how = ""
    if laid:
        how = "   [color=#%s]Your clutch is waiting on this floor[/color]" % UI.MUTED.to_html(false)
    elif ok:
        how = "   [color=#%s]%s[/color]" % [UI.MUTED.to_html(false), PadInput.prompt("Press A to lay them", "Tap again to lay them", "Click again to lay them")]
    else:
        var m = get_tree().get_first_node_in_group("main")
        if m and m.current_room_node and m.current_room_node.room_data and not m.current_room_node.room_data.cleared:
            how = "   [color=#%s]Only in a cleared room[/color]" % UI.MUTED.to_html(false)
        else:
            how = "   " + _cost_bbcode(mode.cost)
    grow_change.text = "[color=#%s][b]%s[/b][/color]%s" % [UI.LEAF.to_html(false), line, how]
    grow_body.text = mode.fact + "\n" + _cost_text_plain(mode.cost) + ". One clutch at a time; it stays in this room, and going down to the next era leaves it behind."

func _cost_text_plain(cost: Dictionary) -> String:
    var parts: Array = []
    for el in BIOMINERALS.ORDER:
        if cost.has(el):
            parts.append("%d %s" % [cost[el], BIOMINERALS.ELEMENTS[el].name])
    return "Costs " + ", ".join(parts)

func _on_eggs_pressed():
    var player = get_tree().get_first_node_in_group("player")
    if grow_selected == CLUTCH_SEL and player and player.can_lay_clutch():
        _lay_clutch(player)
        return
    grow_selected = CLUTCH_SEL
    _just_grown = ""
    _fill_grow_screen()

func _lay_clutch(player):
    var cost = player.clutch_cost()
    if player.lay_clutch():
        _just_grown = CLUTCH_SEL
        _fill_grow_screen()
        _grow_feedback({"id": "clutch", "name": "Clutch"}, cost, ["Clutch laid"])

func _on_grow_pressed():
    var player = get_tree().get_first_node_in_group("player")
    if grow_selected == CLUTCH_SEL:
        if player and player.can_lay_clutch():
            _lay_clutch(player)
        return
    var r = BIOMINERALS.get_recipe(grow_selected)
    if r.is_empty() or player == null:
        return
    var before = _grow_changes(r, player)
    var cost = BIOMINERALS.cost_of(r, BIOMINERALS.times_for_cost(r, player.adaptations_taken))
    if player.grow(grow_selected):
        last_banner = [r.name, r.effect + "\n" + r.fact]
        _just_grown = r.id
        _fill_grow_screen()
        _grow_feedback(r, cost, before)
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("check_challenges"):
            main.check_challenges()

# Elements fly out of your stores into the creature, which swells as the
# part appears; what changed floats up from it
func _grow_feedback(r: Dictionary, cost: Dictionary, changes: Array):
    PadInput.rumble(0.6, 0.25)
    var target = grow_portrait.get_global_rect().get_center()
    var delay := 0.0
    for el in cost:
        var chip: Label = grow_chips[el]
        var from = chip.get_global_rect().get_center()
        var ctw = chip.create_tween()
        chip.pivot_offset = chip.size / 2.0
        ctw.tween_property(chip, "scale", Vector2.ONE * 1.35, 0.08)
        ctw.tween_property(chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
        for i in min(int(cost[el]), 8):
            var mote = GrowMote.new()
            mote.col = BIOMINERALS.ELEMENTS[el].color
            mote.size = Vector2(16, 16)
            mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grow_modal.add_child(mote)
            mote.global_position = from - mote.size / 2.0 + Vector2(randf_range(-14, 14), randf_range(-6, 6))
            var mid = from.lerp(target, 0.5) + Vector2(randf_range(-160, 160), randf_range(-60, 40))
            var end = target - mote.size / 2.0 + Vector2(randf_range(-20, 20), randf_range(-20, 20))
            var start = mote.global_position
            var mtw = mote.create_tween()
            mtw.tween_interval(delay)
            mtw.tween_method(func(u: float):
                if is_instance_valid(mote):
                    var a = start.lerp(mid, u)
                    var b2 = mid.lerp(end, u)
                    mote.global_position = a.lerp(b2, u)
                    mote.rotation = u * 6.0
            , 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
            mtw.tween_callback(mote.queue_free)
            delay += 0.035
    # The creature swells and flashes as the part grows in
    var arrive = delay + 0.45
    var ptw = grow_portrait.create_tween()
    grow_portrait.pivot_offset = grow_portrait.size / 2.0
    ptw.tween_interval(arrive)
    ptw.tween_property(grow_portrait, "scale", Vector2.ONE * 1.18, 0.1).set_trans(Tween.TRANS_SINE)
    ptw.parallel().tween_property(grow_portrait, "modulate", Color(1.6, 1.5, 1.2), 0.1)
    ptw.tween_property(grow_portrait, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    ptw.parallel().tween_property(grow_portrait, "modulate", Color.WHITE, 0.4)
    # Hold back the new part until the elements arrive
    if r.id in GROW_VISIBLE and grow_body_art.visible:
        var parts: Dictionary = grow_body_art.preview_parts.duplicate()
        var now = parts.duplicate()
        parts[r.id] = max(0, int(parts.get(r.id, 0)) - 1)
        grow_body_art.preview_parts = parts
        var btw = grow_body_art.create_tween()
        btw.tween_interval(arrive)
        btw.tween_callback(func(): grow_body_art.preview_parts = now)
    # The change, floating up
    var pop = Label.new()
    pop.text = "\n".join(changes) if not changes.is_empty() else r.effect
    pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pop.add_theme_font_size_override("font_size", 40)
    pop.add_theme_color_override("font_color", UI.LEAF)
    pop.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
    pop.add_theme_constant_override("outline_size", 8)
    pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pop.modulate.a = 0.0
    grow_modal.add_child(pop)
    pop.reset_size()
    # Big, in the middle above the info panel, rising like a banner
    var top = grow_portrait.get_global_rect().position.y
    pop.global_position = Vector2(grow_modal.size.x / 2.0 - pop.size.x / 2.0, top - 30)
    var ltw = pop.create_tween()
    ltw.tween_interval(arrive)
    ltw.tween_property(pop, "modulate:a", 1.0, 0.12)
    ltw.parallel().tween_property(pop, "global_position:y", top - 170, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    ltw.tween_property(pop, "modulate:a", 0.0, 0.35)
    ltw.tween_callback(pop.queue_free)
    # The tile glows
    if not grow_tiles.has(r.id):
        return
    var tile: Button = grow_tiles[r.id].tile
    var ttw = tile.create_tween()
    ttw.tween_interval(arrive)
    ttw.tween_property(tile, "self_modulate", Color(1.7, 1.6, 1.2), 0.08)
    ttw.tween_property(tile, "self_modulate", Color.WHITE, 0.5)

func update_dna(current_dna: int, max_dna: int, level: int):
    dna_label.text = "BIOMASS %d / %d" % [current_dna, max_dna]
    dna_bar.max_value = max_dna
    dna_bar.value = current_dna

# Phones have no keyboard: name the on-screen buttons instead of keys
func use_touch_texts():
    # The settings menu pauses the game; make it a thumb-sized pause button
    settings_btn.text = " ⏸ PAUSE "
    settings_btn.custom_minimum_size = Vector2(190, 56)
    settings_btn.add_theme_font_size_override("font_size", 24)
    # Window sizes mean nothing on a phone, which is always fullscreen (a
    # touchscreen PC like the Legion Go still has a window)
    if OS.has_feature("mobile") or OS.has_feature("web"):
        $SettingsModal/Panel/Margin/VBox/DisplaySection.visible = false
    $GameOverScreen/Center/SubLabel.text = "Tap to try again"
    $VictoryScreen/Center/RestartLabel.text = "Tap to play again  ·  Back for the main menu"

func update_discharge_cooldown(current_cd: float, max_cd: float):
    if not is_instance_valid(ability_label) or not is_instance_valid(ability_bar):
        return
    if current_cd <= 0.0:
        ability_bar.value = 1.0
        ability_label.text = PadInput.prompt("[LB / LT] ZAP: READY", "ZAP: READY", "[E / MMB] DISCHARGE: READY")
        ability_label.add_theme_color_override("font_color", UI.AQUA)
    else:
        var ratio = 1.0 - (current_cd / max(0.001, max_cd))
        ability_bar.value = ratio
        ability_label.text = PadInput.prompt("ZAP RECHARGING (%.1fs)", "ZAP RECHARGING (%.1fs)", "[E] RECHARGING (%.1fs)") % current_cd
        ability_label.add_theme_color_override("font_color", UI.MUTED)

var current_creature_name: String = "PRIMORDIAL PROTOZOA"

func set_current_creature(creature_name: String):
    current_creature_name = creature_name

var current_floor: int = 1

func update_floor(floor_num: int):
    current_floor = floor_num
    var era_str = ERA_NAMES.get(Worlds.era(floor_num), "ERA %d" % floor_num)
    if Worlds.finale and floor_num >= 5:
        era_str = FINALE_INFO.label
    var E = preload("res://data/Endgame.gd")
    if E.gauntlet():
        era_str = "GAUNTLET · " + era_str
    elif E.deep_time():
        era_str = "DEEP TIME · " + era_str
    floor_label.text = "%s | %s" % [era_str, current_creature_name]

func update_minimap(rooms: Dictionary, current_pos: Vector2i):
    dungeon_rooms = rooms
    current_room_pos = current_pos
    if minimap_ctrl:
        minimap_ctrl.queue_redraw()

# The map in the corner is an explorer's survey chart, not a grid of boxes
# (kuro, 2026-11-26: too much like Isaac). Each explored stretch of sea floor
# is an inked patch, open basins wider than the enclosed rooms, joined by
# dotted routes; places glimpsed but not yet visited are dashed outlines.
const MAP_PAPER := Color(0.93, 0.88, 0.75)
const MAP_INK := Color(0.22, 0.14, 0.08)
const MAP_PATCH := Color(0.84, 0.77, 0.60)
const MAP_CORNER := 10
const MAP_PAD := 9.0

func _map_blob(c: Vector2, a: float, b: float, seed_v: int) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in 18:
        var t = TAU * i / 18.0
        var w = 1.0 + 0.13 * sin(t * 3.0 + seed_v * 1.7) + 0.08 * sin(t * 5.0 + seed_v * 0.9)
        pts.append(c + Vector2(cos(t) * a * w, sin(t) * b * w))
    return pts

func _on_minimap_draw():
    if dungeon_rooms.is_empty():
        return
    var mm = minimap_ctrl
    var size: Vector2 = mm.size
    var step = Vector2(34, 26)
    var ci = mm.get_canvas_item()
    # The chart is a sheet of paper with rounded corners; its inked frame is
    # drawn last, over everything, so nothing pokes past it (kuro, 2026-11-27:
    # the map didn't sit nicely in its box)
    var paper = StyleBoxFlat.new()
    paper.bg_color = MAP_PAPER
    paper.set_corner_radius_all(MAP_CORNER)
    paper.corner_detail = 6
    paper.draw(ci, Rect2(Vector2.ZERO, size))
    for k in range(1, 4):
        var y = size.y * k / 4.0
        mm.draw_line(Vector2(8, y), Vector2(size.x - 8, y), Color(MAP_INK, 0.08), 1.0)
    var Room = preload("res://Room.gd")
    var known := {}
    for pos in dungeon_rooms:
        var r_data = dungeon_rooms[pos]
        if r_data.visited:
            known[pos] = true
            continue
        for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            if dungeon_rooms.has(pos + d) and dungeon_rooms[pos + d].visited:
                known[pos] = false
                break
    var at = func(pos: Vector2i) -> Vector2:
        return Vector2(pos.x * step.x, pos.y * step.y)
    # Fit the whole known chart inside the frame: centre it, and shrink it a
    # little when it is too big. Only a chart too big even then follows you.
    var bounds := Rect2(at.call(current_room_pos), Vector2.ZERO)
    for pos in known:
        bounds = bounds.expand(at.call(pos))
    bounds = bounds.grow_individual(16, 10, 16, 10)
    var inner = size - Vector2(MAP_PAD, MAP_PAD) * 2.0
    var sc = clampf(minf(inner.x / bounds.size.x, inner.y / bounds.size.y), 0.6, 1.0)
    var view = inner / sc
    var me_c: Vector2 = at.call(current_room_pos)
    var centre = bounds.get_center()
    if bounds.size.x > view.x:
        centre.x = clampf(me_c.x, bounds.position.x + view.x * 0.5, bounds.end.x - view.x * 0.5)
    if bounds.size.y > view.y:
        centre.y = clampf(me_c.y, bounds.position.y + view.y * 0.5, bounds.end.y - view.y * 0.5)
    mm.draw_set_transform(size * 0.5 - centre * sc, 0.0, Vector2(sc, sc))
    # Routes: dotted ink between explored places and where they lead
    var drawn := {}
    for pos in known:
        if not known[pos]:
            continue
        for d in dungeon_rooms[pos].connections:
            var q = dungeon_rooms[pos].connections[d]
            if not known.has(q):
                continue
            var key = [min(pos.x, q.x), min(pos.y, q.y), max(pos.x, q.x), max(pos.y, q.y)]
            if drawn.has(key):
                continue
            drawn[key] = true
            var p0: Vector2 = at.call(pos)
            var p1: Vector2 = at.call(q)
            var n = int(p0.distance_to(p1) / 4.0)
            for k in range(1, n):
                mm.draw_circle(p0.lerp(p1, k / float(n)), 1.1, Color(MAP_INK, 0.7))
    # Places: inked patches; open basins are long, enclosed rooms round
    for pos in known:
        var r_data = dungeon_rooms[pos]
        var c: Vector2 = at.call(pos)
        var wide = Room.is_basin(r_data)
        var a = 15.0 if wide else 9.5
        var b = 8.5 if wide else 8.0
        var seed_v = pos.x * 7 + pos.y * 13
        var blob = _map_blob(c, a, b, seed_v)
        var ring = blob.duplicate()
        ring.append(blob[0])
        if known[pos]:
            mm.draw_colored_polygon(blob, MAP_PATCH)
            # two strokes of shading on the lower side
            for k in 2:
                var x = c.x - a * 0.3 + k * a * 0.5
                mm.draw_line(Vector2(x, c.y + b * 0.15), Vector2(x + 4, c.y + b * 0.65), Color(MAP_INK, 0.35), 1.0, true)
            mm.draw_polyline(ring, MAP_INK, 1.6, true)
        else:
            # glimpsed: a dashed outline only
            for k in range(0, ring.size() - 1, 2):
                mm.draw_line(ring[k], ring[k + 1], Color(MAP_INK, 0.55), 1.2, true)
        # What is there, in pen
        if r_data.type == 3: # boss: a coiled shell
            var sp := PackedVector2Array()
            for k in 16:
                var t = k * 0.55
                sp.append(c + Vector2(cos(t), sin(t)) * (1.0 + t * 0.85))
            mm.draw_polyline(sp, UI.CORAL.darkened(0.35), 2.0, true)
        elif r_data.type == 2: # treasure: an X marks the spot
            mm.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), Color(0.72, 0.45, 0.12), 2.2, true)
            mm.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), Color(0.72, 0.45, 0.12), 2.2, true)
        elif r_data.type == 4 or (r_data.type == 5 and not r_data.seep_used): # shop or seep: a sprig
            mm.draw_line(c + Vector2(0, 4), c + Vector2(0, -4), UI.LEAF.darkened(0.45), 1.8, true)
            mm.draw_line(c + Vector2(0, 0), c + Vector2(-3, -3), UI.LEAF.darkened(0.45), 1.6, true)
            mm.draw_line(c + Vector2(0, -1), c + Vector2(3, -4), UI.LEAF.darkened(0.45), 1.6, true)
        elif r_data.special != "" and known[pos]: # a special place: a small ring
            mm.draw_arc(c, 3.5, 0, TAU, 12, Color(0.72, 0.45, 0.12), 1.6, true)
    # You are here: an ink dot in a ring
    var me: Vector2 = at.call(current_room_pos)
    var room_node = get_tree().get_first_node_in_group("main").current_room_node if get_tree().get_first_node_in_group("main") else null
    if room_node and is_instance_valid(room_node) and Room.is_basin(dungeon_rooms.get(current_room_pos)):
        # where in the basin, left to right
        var player = get_tree().get_first_node_in_group("player")
        if player:
            var m: float = room_node.side_margin
            var f = clampf((player.global_position.x + m) / (1920.0 + m * 2.0), 0.0, 1.0)
            me.x += (f - 0.5) * 22.0
    mm.draw_circle(me, 5.5, Color(MAP_PAPER, 0.9))
    mm.draw_arc(me, 5.0, 0, TAU, 14, MAP_INK, 1.4, true)
    mm.draw_circle(me, 2.3, MAP_INK)
    mm.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    # The inked frame: a heavy outer rule and a fine inner one, like a plate
    # in a field notebook
    var rule = StyleBoxFlat.new()
    rule.draw_center = false
    rule.border_color = MAP_INK
    rule.set_border_width_all(3)
    rule.set_corner_radius_all(MAP_CORNER)
    rule.corner_detail = 6
    rule.anti_aliasing = true
    rule.draw(ci, Rect2(Vector2.ZERO, size))
    var fine = StyleBoxFlat.new()
    fine.draw_center = false
    fine.border_color = Color(MAP_INK, 0.55)
    fine.set_border_width_all(1)
    fine.set_corner_radius_all(MAP_CORNER - 4)
    fine.corner_detail = 6
    fine.draw(ci, Rect2(Vector2(5, 5), size - Vector2(10, 10)))

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
# Banners (wildlife, found items, hazards, seeps) used to be bare outlined
# text over the room, hard to read on the pale ground. They sit on a small
# sepia card now, like the rest of the interface, sized to their text.
func _make_banner_card():
    var vb = item_banner
    var card = PanelContainer.new()
    card.name = "ItemBannerCard"
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.anchor_left = 0.5
    card.anchor_right = 0.5
    card.anchor_top = 0.5
    card.anchor_bottom = 0.5
    card.grow_horizontal = Control.GROW_DIRECTION_BOTH
    card.grow_vertical = Control.GROW_DIRECTION_END
    card.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 22, 0.9, 22.0))
    add_child(card)
    move_child(card, vb.get_index())
    vb.get_parent().remove_child(vb)
    card.add_child(vb)
    vb.add_theme_constant_override("separation", 6)
    for l in [item_title, item_desc]:
        l.add_theme_constant_override("outline_size", 0)
    item_title.add_theme_color_override("font_color", UI.SUN)
    item_title.add_theme_font_size_override("font_size", 30)
    item_desc.add_theme_color_override("font_color", UI.CREAM)
    item_banner = card

# Over play only a small tag shows near the top: the name, plus one short
# line when it changes how you play (short). The whole fact goes into the
# run's field journal on the pause screen, to read when you like (kuro:
# no text blocking gameplay).
func show_item_banner(title: String, desc: String, near_top: bool = false, hold_for: float = -1.0, short: String = ""):
    item_banner.offset_left = -320.0
    item_banner.offset_right = 320.0
    item_banner.offset_top = -470.0
    item_banner.offset_bottom = item_banner.offset_top # grows down to fit the text
    item_banner.visible = true
    item_title.text = title
    item_desc.text = short
    item_desc.visible = short != ""
    item_banner.modulate.a = 1.0
    last_banner = [title, desc]
    note_journal(title, desc)
    if banner_tween and banner_tween.is_valid():
        banner_tween.kill()
    var hold = clamp(2.2 + short.length() / 22.0, 2.2, 5.0) if hold_for < 0.0 else hold_for
    banner_tween = create_tween()
    banner_tween.tween_property(item_banner, "modulate:a", 0.0, 0.6).set_delay(hold)
    banner_tween.tween_callback(func(): item_banner.visible = false)

var banner_tween: Tween = null
var last_banner: Array = []
# This run's discoveries, oldest first: [title, text] (pause screen)
var journal: Array = []
const JOURNAL_MAX := 24

func note_journal(title: String, desc: String):
    if desc == "":
        return
    for i in range(journal.size() - 1, -1, -1):
        if journal[i][0] == title:
            journal.remove_at(i)
    journal.append([title, desc])
    if journal.size() > JOURNAL_MAX:
        journal.pop_front()

# Anything besides the pause screen that holds the game: cards, the grow
# screen, the evolution and adaptation picks, and the end screens
func other_screen_up() -> bool:
    return is_card_up() or is_grow_up() or (evolution_modal != null and evolution_modal.visible) \
        or game_over_screen.visible or victory_screen.visible

# The phone went to the background (or the window lost focus): pause the run
func auto_pause():
    if not settings_modal.visible and not other_screen_up():
        toggle_settings()

# Android back button: close what is open, or pause
func back_pressed():
    if is_card_up():
        dismiss_card() # the era page: back just skips it, like a tap
    elif game_over_screen.visible or victory_screen.visible:
        get_tree().paused = false
        get_tree().change_scene_to_file("res://MainMenu.tscn")
    elif is_grow_up():
        hide_grow_screen()
    elif settings_modal.visible or not other_screen_up():
        toggle_settings()

# When the end screen came up; a tap restarts only after a moment, so a
# thumb still stabbing at the attack stick doesn't skip it
var end_shown_at: int = 0

func end_screen_ready() -> bool:
    return Time.get_ticks_msec() - end_shown_at > 1200

func show_game_over(run: Dictionary = {}):
    if settings_modal.visible:
        toggle_settings()
    item_banner.visible = false # it would show through the dimmed screen
    end_shown_at = Time.get_ticks_msec()
    game_over_screen.visible = true
    UI.reveal(game_over_screen, null, 0.6)
    var how = PadInput.prompt("A to try again  ·  B for the main menu",
        "Tap to try again  ·  Back for the main menu", "R or tap to try again  ·  Esc for the main menu")
    var sub = $GameOverScreen/Center/SubLabel
    if run.is_empty():
        sub.text = how
        return
    add_lineage_strip($GameOverScreen/Center)
    # Two short lines: what ended it, and how far you got
    var era: Dictionary = ERA_INFO.get(int(run.get("era", clampi(run.get("floor", 1), 1, 5))), {})
    var era_name = str(era.get("name", "")).replace(" PERIOD", "").to_lower().capitalize()
    var lines = ("Killed by %s" % run.killed_by) if str(run.get("killed_by", "")) != "" else "Died out"
    lines += " in the %s" % era_name
    lines += "\n%d eaten · era %d of 5" % [run.get("kills", 0), run.get("floor", 1)]
    if run.get("record", false) and run.get("floor", 1) > 1:
        lines += " · best run yet!"
    sub.text = lines + "\n\n" + how
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    $GameOverScreen/Center.offset_left = -560.0
    $GameOverScreen/Center.offset_right = 560.0
    $GameOverScreen/Center.offset_top = -250.0
    $GameOverScreen/Center.offset_bottom = 250.0
    
# The run's family line as pictures: every form from the first cell to
# where the run ended, left to right. Shown on the game over and victory
# screens, replacing the one from an earlier death on a restart.
func add_lineage_strip(box: VBoxContainer):
    var old = box.get_node_or_null("LineageStrip")
    if old:
        old.queue_free()
    var player = get_tree().get_first_node_in_group("player")
    if player == null or not "evolution_choices" in player:
        return
    var forms: Array = []
    var choices: Array = player.evolution_choices
    for n in range(choices.size() + 1):
        var key = lineages.path_key(choices.slice(0, n))
        if lineages.has_form(key):
            var f = lineages.get_form(key)
            if forms.is_empty() or forms[-1].id != f.id:
                forms.append(f)
    if forms.is_empty():
        return
    var strip = HBoxContainer.new()
    strip.name = "LineageStrip"
    strip.alignment = BoxContainer.ALIGNMENT_CENTER
    strip.add_theme_constant_override("separation", 10)
    for i in forms.size():
        var f = forms[i]
        if i > 0:
            var arrow = _pause_label(30, UI.MUTED, true, "›")
            arrow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
            arrow.custom_minimum_size = Vector2(0, 92)
            arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            strip.add_child(arrow)
        var sheet = "res://assets/lineages/%s_sheet.png" % f.id
        var tile = PauseTile.new().setup(load(sheet) if ResourceLoader.exists(sheet) else null, 4, 92.0, f.name.capitalize())
        tile.tint = UI.ink_tint(f.color)
        tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
        strip.add_child(tile)
    box.add_child(strip)
    box.move_child(strip, 1)

func show_victory(summary: Dictionary = {}):
    end_shown_at = Time.get_ticks_msec()
    victory_screen.visible = true
    UI.reveal(victory_screen, null, 0.6)
    item_banner.visible = false
    if PadInput.using_pad:
        $VictoryScreen/Center/RestartLabel.text = "A to play again  ·  B for the main menu"
    elif not TouchControls.should_show():
        $VictoryScreen/Center/RestartLabel.text = "R or tap to play again  ·  Esc for the main menu"
    var label = $VictoryScreen/Center/Label
    var sublabel = $VictoryScreen/Center/SubLabel
    if summary.is_empty():
        label.text = "600 MILLION YEARS OF EVOLUTION COMPLETE!"
        sublabel.text = "Your lineage dominated Earth through all 5 eras!"
    else:
        label.text = "YOU LIVED THROUGH THE GREAT DYING!" if Worlds.finale else "APEX EVOLUTION: VICTORY!"
        add_lineage_strip($VictoryScreen/Center)
        var text = summary.get("title", "Apex Organism")
        text += "\nCodex: %d of %d lineages" % [codex.load_discovered().size(), lineages.TREE.size()]
        sublabel.text = text

func show_evolution_modal(floor_num: int, current_path: Array = []):
    var path_key = lineages.path_key(current_path)
    var form = lineages.get_form(path_key)
    var child_paths = lineages.get_child_paths(path_key)

    _create_evolution_modal()

    var header = evolution_modal.get_node("CenterBox/Header") as Label
    var subheader = evolution_modal.get_node("CenterBox/SubHeader") as Label
    header.text = "" + ERA_NAMES.get(Worlds.era(floor_num), "ERA %d" % floor_num) + " COMPLETE"

    var cards_row = evolution_modal.get_node("CenterBox/CardsRow") as HBoxContainer
    for c in cards_row.get_children():
        c.queue_free()

    if child_paths.is_empty():
        # No real split known for this lineage here: offer an in-clade upgrade
        var name_text = form.get("name", "YOUR LINEAGE") if not form.is_empty() else "YOUR LINEAGE"
        subheader.text = "No real split is known for your lineage in this era, so it adapts instead:"
        _build_choice_card(cards_row, floor_num, 0, {
            "title": "REFINE: " + name_text,
            "clade": form.get("clade", "in-clade adaptation").get_slice(" — ", 0),
            "desc": "Evolution does not always branch. Your lineage stays itself and gets better at what it does.",
            "perks": "+1.5 damage, +20 speed, faster fire\n+2 max health (heals 2)",
            "color": form.get("color", Color(0.0, 1.0, 0.85)),
            "sheet": "res://assets/lineages/%s_sheet.png" % form.get("id", ""),
            "stats": _card_stat_rows(form, form, 2, true) if not form.is_empty() else [],
            "attack": "Attack: " + form.get("weapon_name", "") if not form.is_empty() else "",
        }, 1)
    else:
        # Every card is a direct branch of the current form (Lineages.TREE is
        # keyed by the path of picks), so the run stays on one family tree
        subheader.text = "Your %s lineage splits. Pick which branch of it you become:" % form.get("name", "ancestral").to_lower().capitalize()
        for i in range(child_paths.size()):
            var child = lineages.get_form(child_paths[i])
            var desc = child.fact + "\n\nLiving today: " + child.living_example + "\n" + child.clade_path
            var is_new = not codex.is_discovered(child.id)
            var card_btn = _build_choice_card(cards_row, floor_num, i, {
                "title": child.name,
                "clade": ("NEW · " if is_new else "") + child.clade.get_slice(" — ", 0),
                "desc": desc,
                "perks": lineages.describe_perks(child),
                "color": child.color,
                "sheet": "res://assets/lineages/%s_sheet.png" % child.id,
                "stats": _card_stat_rows(child, form, child.get("max_health_add", 0)),
                "attack": "Attack: " + child.get("weapon_name", "Engulf (phagocytosis)"),
            }, child_paths.size())
            if i == 0:
                card_btn.set_meta("pad_default", true)

    evolution_modal.visible = true
    UI.reveal(evolution_modal)
    UI.deal(cards_row.get_children())
    get_tree().paused = true

# Stat bar rows for an evolution card: the offered form against the form you
# are now (the tick on each bar). A refine is your form with its bonuses.
func _card_stat_rows(offer: Dictionary, now: Dictionary, health_add: int, refine: bool = false) -> Array:
    var a = lineages.card_stats(offer)
    var b = lineages.card_stats(now) if not now.is_empty() else {}
    if refine:
        a.speed += 20.0
        a.power += 1.5
        a.rate = 1.0 / max(0.05, 1.0 / a.rate - 0.02)
    var player = get_tree().get_first_node_in_group("player")
    var hp_now: int = player.max_health if player else 6
    var hp_top: float = max(16.0, hp_now + health_add + 2.0)
    var rows: Array = []
    var same = b.is_empty()
    for k in [["speed", "stat_speed", "Speed", UI.AQUA], ["power", "stat_damage", "Damage", UI.SUN],
            ["rate", "stat_attack", "Attack rate", UI.SUN]]:
        rows.append([_icon(k[1]), k[2], lineages.card_fill(k[0], a[k[0]]),
            -1.0 if same else lineages.card_fill(k[0], b[k[0]]), k[3], true])
    rows.append([heart_full_tex, "Health", (hp_now + health_add) / hp_top, hp_now / hp_top, UI.CORAL, false])
    rows.append([_icon("stat_sight"), "Sight", lineages.card_fill("sight", a.sight),
        -1.0 if same else lineages.card_fill("sight", b.sight), UI.CREAM, true])
    rows.append([_icon("stat_sense"), a.sense_name, lineages.card_fill("sense", a.sense),
        -1.0 if same else lineages.card_fill("sense", b.sense), UI.LEAF, true])
    return rows

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
    bg.color = Color(UI.BACKDROP, 0.96)
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
    header.text = "EPOCH TRANSCENDED: GEOLOGICAL EVOLUTION"
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

func _build_choice_card(parent: HBoxContainer, floor_num: int, choice_idx: int, data: Dictionary, total: int = 2, on_pick: Callable = Callable(), height: float = 560.0, button_text: String = "MUTATE & ADAPT") -> Button:
    var card = PanelContainer.new()
    # Up to four cards share the row
    var gap = 50 if total <= 2 else 24
    card.custom_minimum_size = Vector2(min(680.0, (1640.0 - gap * (total - 1)) / total), height)
    parent.add_theme_constant_override("separation", gap)
    
    data["color"] = UI.ink_tint(data["color"]) # muted, sketchbook-style rims
    card.add_theme_stylebox_override("panel", UI.panel(data["color"], 32, 0.96, 0.0))
    
    var compact = total >= 3
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 26 if compact else 36)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_right", 26 if compact else 36)
    margin.add_theme_constant_override("margin_bottom", 30)
    card.add_child(margin)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    margin.add_child(vbox)
    
    # Picture of the form beside its name (the same sketch the pause screen
    # uses), so you see what you would become before reading about it
    var head: Container = vbox
    var sheet: String = data.get("sheet", "")
    if sheet != "" and ResourceLoader.exists(sheet):
        var head_row = HBoxContainer.new()
        head_row.add_theme_constant_override("separation", 14)
        vbox.add_child(head_row)
        var pic = PauseTile.new().setup(load(sheet), 4, 118.0 if total <= 2 else 104.0)
        pic.tint = data["color"]
        pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        head_row.add_child(pic)
        head = VBoxContainer.new()
        head.add_theme_constant_override("separation", 6)
        head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.alignment = BoxContainer.ALIGNMENT_CENTER
        head_row.add_child(head)

    var clade_lbl = Label.new()
    clade_lbl.text = data["clade"].to_upper()
    clade_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    clade_lbl.add_theme_font_size_override("font_size", 16)
    clade_lbl.add_theme_color_override("font_color", data["color"].lerp(UI.CREAM, 0.25))
    head.add_child(clade_lbl)
    
    var title_lbl = Label.new()
    title_lbl.text = data["title"]
    title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_lbl.add_theme_font_size_override("font_size", 28)
    title_lbl.add_theme_color_override("font_color", UI.SUN)
    head.add_child(title_lbl)
    
    # The text that used to fill the card: the fact, where the lineage lives
    # today and every perk. With stat bars it waits behind a DETAILS button.
    var details = VBoxContainer.new()
    details.add_theme_constant_override("separation", 12)
    details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var desc_lbl = Label.new()
    desc_lbl.text = data["desc"]
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_lbl.add_theme_font_size_override("font_size", 15 if compact else 17)
    desc_lbl.add_theme_color_override("font_color", UI.CREAM)
    details.add_child(desc_lbl)
    details.add_child(HSeparator.new())
    var perks_lbl = Label.new()
    perks_lbl.text = data["perks"]
    perks_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    perks_lbl.add_theme_font_size_override("font_size", 16 if compact else 19)
    perks_lbl.add_theme_color_override("font_color", UI.LEAF)
    details.add_child(perks_lbl)

    var stats: Array = data.get("stats", [])
    var bars: VBoxContainer = null
    if stats.is_empty():
        vbox.add_child(details)
    else:
        bars = VBoxContainer.new()
        bars.add_theme_constant_override("separation", 8)
        bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vbox.add_child(bars)
        for st in stats:
            var sb = StatBar.new()
            if compact:
                sb.label_w = 124.0
                sb.font_px = 17
            bars.add_child(sb.setup(st[0], st[1], st[2], st[3], st[4], st[5]))
        if data.get("attack", "") != "":
            var atk = Label.new()
            atk.text = data["attack"]
            atk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            atk.add_theme_font_size_override("font_size", 19)
            atk.add_theme_color_override("font_color", UI.SUN)
            bars.add_child(atk)
        var scroll = ScrollContainer.new()
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.visible = false
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(details)
        vbox.add_child(scroll)
        details = scroll

    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL if bars == null else Control.SIZE_SHRINK_BEGIN
    vbox.add_child(spacer)

    var btn_row = HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 14)
    vbox.add_child(btn_row)
    if bars != null:
        var info_btn = Button.new()
        var info_word = "INFO" if compact else "DETAILS"
        info_btn.text = info_word
        info_btn.custom_minimum_size = Vector2(96 if compact else 150, 56)
        info_btn.add_theme_font_size_override("font_size", 20)
        for state in ["normal", "hover", "pressed", "disabled"]:
            info_btn.add_theme_stylebox_override(state, UI.button_box(state, UI.MEMBRANE))
        info_btn.pressed.connect(func():
            var open = not details.visible
            details.visible = open
            bars.visible = not open
            info_btn.text = "STATS" if open else info_word
            SoundManager.play_sfx("dna_pickup", 1.4, -8.0)
        )
        btn_row.add_child(info_btn)

    var btn = Button.new()
    btn.text = "EVOLVE" if compact and bars != null and button_text == "MUTATE & ADAPT" else button_text
    btn.custom_minimum_size = Vector2(0, 56)
    btn.add_theme_font_size_override("font_size", 22)
    for state in ["normal", "hover", "pressed", "disabled"]:
        btn.add_theme_stylebox_override(state, UI.button_box(state, data["color"]))
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if on_pick.is_valid():
        btn.pressed.connect(on_pick)
    else:
        btn.pressed.connect(func():
            _on_evolution_choice_clicked(floor_num, choice_idx)
        )
    btn_row.add_child(btn)
    
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
const StatBar = preload("res://StatBar.gd")
var pause_box: PanelContainer = null
var pause_era: Label
var pause_dates: Label
var pause_you: HBoxContainer
var pause_wildlife: HFlowContainer
var pause_adapt: HFlowContainer
var pause_journal: HFlowContainer
var pause_journal_head: Label
var pause_adapt_head: Label
var pause_info_title: Label
var pause_info_body: Label
var pause_tiles: Array = []
var pause_default: Array = ["", ""]

func _create_pause_info():
    # The settings page: centred, hidden until SETTINGS is pressed
    var panel = settings_modal.get_node("Panel")
    panel.visible = false
    panel.offset_left = -300.0
    panel.offset_right = 300.0
    panel.offset_top = -250.0
    panel.offset_bottom = 250.0
    # The pause page fills the screen's height under the top bar, so it never
    # runs off the bottom on a phone; the middle scrolls if it ever must
    pause_box = PanelContainer.new()
    pause_box.anchor_left = 0.5
    pause_box.anchor_right = 0.5
    pause_box.anchor_top = 0.0
    pause_box.anchor_bottom = 1.0
    pause_box.offset_left = -640.0
    pause_box.offset_right = 640.0
    pause_box.offset_top = 76.0
    pause_box.offset_bottom = -64.0 # clear of the track name at the bottom
    pause_box.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 26, 0.96, 28.0))
    settings_modal.add_child(pause_box)
    var col = VBoxContainer.new()
    col.add_theme_constant_override("separation", 10)
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

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    col.add_child(scroll)
    var body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 8)
    scroll.add_child(body)

    pause_you = HBoxContainer.new()
    pause_you.add_theme_constant_override("separation", 22)
    body.add_child(pause_you)

    body.add_child(_pause_label(17, UI.LEAF, true, "ANIMALS"))
    pause_wildlife = HFlowContainer.new()
    pause_wildlife.add_theme_constant_override("h_separation", 10)
    pause_wildlife.add_theme_constant_override("v_separation", 6)
    body.add_child(pause_wildlife)

    pause_adapt_head = _pause_label(17, UI.LEAF, true, "FINDS")
    body.add_child(pause_adapt_head)
    pause_adapt = HFlowContainer.new()
    pause_adapt.add_theme_constant_override("h_separation", 10)
    pause_adapt.add_theme_constant_override("v_separation", 10)
    body.add_child(pause_adapt)

    pause_journal_head = _pause_label(17, UI.LEAF, true, "JOURNAL")
    body.add_child(pause_journal_head)
    pause_journal = HFlowContainer.new()
    pause_journal.add_theme_constant_override("h_separation", 8)
    pause_journal.add_theme_constant_override("v_separation", 8)
    body.add_child(pause_journal)

    # The details box: what the last tapped picture is
    var info = PanelContainer.new()
    var sb = UI.panel(UI.SUN, 16, 0.9, 18.0)
    sb.set_border_width_all(2)
    sb.shadow_size = 0
    info.add_theme_stylebox_override("panel", sb)
    info.custom_minimum_size = Vector2(0, 96)
    col.add_child(info)
    var info_col = VBoxContainer.new()
    info_col.add_theme_constant_override("separation", 4)
    info.add_child(info_col)
    pause_info_title = _pause_label(20, UI.SUN, true)
    info_col.add_child(pause_info_title)
    pause_info_body = _pause_label(17, UI.CREAM)
    info_col.add_child(pause_info_body)

    # One row of buttons: play on, settings page, or quit the run
    var buttons = HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 18)
    col.add_child(buttons)
    resume_btn = _styled_button("RESUME", UI.LEAF, 260, 58)
    resume_btn.set_meta("pad_default", true)
    resume_btn.pressed.connect(toggle_settings)
    buttons.add_child(resume_btn)
    var settings_open = _styled_button("⚙ SETTINGS", UI.MEMBRANE, 260, 58)
    settings_open.pressed.connect(show_settings_page.bind(true))
    buttons.add_child(settings_open)
    var menu_btn = _styled_button("QUIT RUN", UI.CORAL, 260, 58)
    menu_btn.pressed.connect(func():
        SettingsManager.save_settings()
        get_tree().paused = false
        get_tree().change_scene_to_file("res://MainMenu.tscn")
    )
    buttons.add_child(menu_btn)

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
    if tex != heart_full_tex: # the heart pip is already drawn in ink
        icon.material = UI.sepia_material()
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
    for c in pause_you.get_children() + pause_wildlife.get_children() + pause_adapt.get_children() + pause_journal.get_children():
        c.queue_free()
    # Field journal: every fact that popped up this run, newest first
    pause_journal_head.visible = not journal.is_empty()
    for i in range(journal.size() - 1, -1, -1):
        var entry: Array = journal[i]
        var b = Button.new()
        b.text = entry[0]
        b.add_theme_font_size_override("font_size", 16)
        b.custom_minimum_size = Vector2(0, 44)
        for state in ["normal", "hover", "pressed", "disabled", "focus"]:
            b.add_theme_stylebox_override(state, UI.button_box("pressed" if state == "focus" else state, UI.MEMBRANE))
        b.pressed.connect(func():
            for t in pause_tiles:
                if is_instance_valid(t):
                    t.selected = false
            pause_info_title.text = entry[0]
            pause_info_body.text = entry[1])
        pause_journal.add_child(b)

    var main = get_tree().get_first_node_in_group("main")
    var player = get_tree().get_first_node_in_group("player")
    var era = ERA_INFO.get(Worlds.era(current_floor), {})
    pause_era.text = era.get("name", "ERA %d" % current_floor)
    pause_dates.text = era.get("dates", "")
    # Which music is playing, so favourite tracks can be named
    if SoundManager.now_playing() != "":
        pause_dates.text += "     ♪ " + SoundManager.now_playing().get_slice(" ", 0)

    # You: your animated sprite (whatever art the player is drawn with) and
    # your numbers as icons
    if main and player and main.has_method("current_form"):
        var form = main.current_form()
        if not form.is_empty():
            var spr: Sprite2D = player.get_node("Sprite2D")
            var w = lineages.weapon_stats(player.current_weapon)
            var body = form.fact
            if form.get("living_example", "") != "":
                body += "\nLiving today: " + form.living_example
            if w.get("special", "") != "":
                body += "\nAttack: %s. %s" % [player.current_weapon_name, w.special]
            var twist: Array = lineages.fan_twist(player.current_character_id)
            if not twist.is_empty():
                body += "\n%s: %s." % [twist[1], twist[2]]
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
            me.tint = UI.ink_tint(form.color)
            me.spin = spin
            var side = VBoxContainer.new()
            side.add_theme_constant_override("separation", 6)
            side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            pause_you.add_child(side)
            side.add_child(_pause_label(30, UI.SUN, true, form.name))
            var chips = HFlowContainer.new()
            chips.add_theme_constant_override("h_separation", 18)
            chips.add_theme_constant_override("v_separation", 6)
            side.add_child(chips)
            _pause_chip(chips, heart_full_tex, "%d/%d" % [player.health, player.max_health], UI.CORAL)
            _pause_chip(chips, _icon("stat_damage"), "%.1f" % player.damage)
            _pause_chip(chips, _icon("stat_speed"), "%d" % int(player.speed), UI.AQUA)
            var senses = lineages.sense_words(form)
            _pause_chip(chips, _icon("stat_sight"), senses[0])
            _pause_chip(chips, _icon("stat_attack"), player.current_weapon_name, UI.SUN)
            # Every sense as an icon with strength pips; tap one for what it does
            var sense_row = HBoxContainer.new()
            sense_row.add_theme_constant_override("separation", 8)
            side.add_child(sense_row)
            for k in lineages.SENSE_ORDER:
                var b = preload("res://SenseBadge.gd").new().setup(k, int(player.sense_profile.get(k, 0)), 58.0)
                b.picked.connect(_on_pause_tile_picked)
                sense_row.add_child(b)
                pause_tiles.append(b)

    # The era's animals, drawn with their own sprite sheets
    var fauna = preload("res://data/Fauna.gd")
    var era_animals: Array = fauna.era_species(current_floor)
    var tile_size = 128.0 if era_animals.size() <= 6 else 104.0
    for a in era_animals:
        var p = fauna.sheet_path(a)
        var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
        var frames = int(round(tex.get_width() / float(tex.get_height()))) if tex else 1
        var body = a.fact + ("\n" + a.tip if a.has("tip") else "")
        _pause_tile(pause_wildlife, tex, frames, tile_size, a.name, a.name, body)

    pause_adapt_head.visible = player != null and not (player.items_found.is_empty() and player.adaptations_taken.is_empty())
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

    # Until something is tapped, the box keeps the last thing that popped up
    var touch = TouchControls.should_show()
    pause_info_title.text = "Tap a picture to learn about it" if touch else "Point at a picture to learn about it"
    pause_info_body.text = ""

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
    header.text = "ADAPTATION"
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
        }, options.size(), _on_adaptation_clicked.bind(a.id), 400.0, "ADAPT")
        btn.disabled = true
        buttons.append(btn)
    evolution_modal.visible = true
    UI.reveal(evolution_modal)
    UI.deal(cards_row.get_children())
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
func dash_row(form: Dictionary, touch: bool, pad: bool = false) -> Array:
    var escape = lineages.get_escape(form)
    if escape[0] == "dart":
        if pad:
            return ["DASH", "RT / RB / A to dart away, untouchable for a moment"]
        if touch:
            return ["DASH", "Tap DASH to dart away, untouchable for a moment"]
        return ["DASH", "Space / Shift / right-click to dart away, untouchable for a moment"]
    var label = lineages.escape_label(form)
    var how = "RT / RB / A" if pad else (("Tap " + label) if touch else "Space / Shift / right-click")
    return [label, "%s: %s, %s" % [how, escape[1].to_lower(), escape[2]]]

# One page per floor: the era's name, you, and the controls, so a player can
# start at once. The era's dates, fact and animals sit behind an ERA INFO
# button. The game is frozen under it and any other tap, key, click or pad
# button closes it.
var era_info_btn: Button = null
var era_info_box: Control = null
var era_info_at: int = 0

# The controls in a few words each: [what, how]
func control_rows(form: Dictionary, touch: bool, pad: bool) -> Array:
    var dash = lineages.escape_label(form)
    if pad:
        return [["MOVE", "Left stick"], ["FIRE", "Right stick"], [dash, "RT"],
            ["ZAP", "LT"], ["GROW", "Y"], ["PAUSE", "Start"]]
    if touch:
        return [["MOVE", "Left thumb"], ["FIRE", "Right thumb"], [dash, "Tap " + dash],
            ["ZAP", "Tap ZAP"], ["GROW", "Tap GROW"], ["PAUSE", "⏸"]]
    return [["MOVE", "WASD"], ["FIRE", "IJKL / mouse"], [dash, "Space"],
        ["ZAP", "E"], ["GROW", "G"], ["PAUSE", "Esc"]]

func show_era_card(floor_num: int, form: Dictionary):
    var touch = TouchControls.should_show()
    var pad = PadInput.using_pad
    var color: Color = form.get("color", Color(0.0, 0.95, 1.0))
    var era: Dictionary = ERA_INFO.get(Worlds.era(floor_num), {})
    var finale = Worlds.finale and floor_num >= 5
    if finale:
        era = {"name": FINALE_INFO.name, "dates": FINALE_INFO.dates,
            "fact": FINALE_INFO.fact_sea if Worlds.sea else FINALE_INFO.fact_land}
    item_banner.visible = false # an old note would sit on top of the page
    var vbox = _open_card(color, 1180, 0.95)
    vbox.add_theme_constant_override("separation", 10)

    for l in [_card_label("BEYOND THE END" if finale else "ERA %d OF 5" % floor_num, 18, UI.MUTED),
            _card_label(era.get("name", ""), 44, UI.SUN)]:
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(l)

    # You, drawn, beside the controls
    var cols = HBoxContainer.new()
    cols.add_theme_constant_override("separation", 34)
    cols.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(cols)
    var me = _era_form_tile(cols, 150.0)
    if me:
        me.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        me.tint = UI.ink_tint(color)
    var right = VBoxContainer.new()
    right.add_theme_constant_override("separation", 12)
    right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    cols.add_child(right)
    right.add_child(_card_label(("YOU ARE THE " if floor_num == 1 else "YOU ARE NOW ") + form.get("name", current_creature_name), 26, color))
    var grid = GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 8)
    right.add_child(grid)
    for r in control_rows(form, touch, pad):
        var key = _card_label(r[0], 21, UI.LEAF)
        key.autowrap_mode = TextServer.AUTOWRAP_OFF
        grid.add_child(key)
        var val = _card_label(r[1], 21, UI.CREAM)
        val.autowrap_mode = TextServer.AUTOWRAP_OFF
        val.custom_minimum_size = Vector2(150, 0)
        grid.add_child(val)

    # The era's dates, fact and animals, hidden until ERA INFO is pressed
    var info = VBoxContainer.new()
    info.add_theme_constant_override("separation", 8)
    info.visible = false
    vbox.add_child(info)
    era_info_box = info
    info.add_child(HSeparator.new())
    for l in [_card_label(era.get("dates", ""), 20, UI.LEAF), _card_label(era.get("fact", ""), 20, UI.CREAM)]:
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        info.add_child(l)
    var flow = HFlowContainer.new()
    flow.alignment = FlowContainer.ALIGNMENT_CENTER
    flow.add_theme_constant_override("h_separation", 14)
    flow.add_theme_constant_override("v_separation", 6)
    info.add_child(flow)
    var fauna = preload("res://data/Fauna.gd")
    var animals: Array = fauna.era_species(floor_num)
    var disc = 104.0 if animals.size() <= 6 else 88.0
    for a in animals:
        var p = fauna.sheet_path(a)
        var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
        var frames = int(round(tex.get_width() / float(tex.get_height()))) if tex else 1
        _quiet_tile(flow, PauseTile.new().setup(tex, frames, disc, a.name))

    var btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(btn_row)
    era_info_btn = _styled_button(PadInput.prompt("ERA INFO (Y)", "ERA INFO", "ERA INFO (H)"), UI.LEAF, 260, 56)
    era_info_btn.focus_mode = Control.FOCUS_NONE
    era_info_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # _input handles it
    btn_row.add_child(era_info_btn)

    _close_card(vbox, "start" if floor_num == 1 else "continue")

func toggle_era_info():
    if era_info_box == null or not is_instance_valid(era_info_box):
        return
    era_info_at = Time.get_ticks_msec()
    era_info_box.visible = not era_info_box.visible
    era_info_btn.text = "HIDE INFO" if era_info_box.visible else PadInput.prompt("ERA INFO (Y)", "ERA INFO", "ERA INFO (H)")

# True when this press is meant for the era page's ERA INFO button
func _is_era_info_press(event: InputEvent) -> bool:
    if era_info_btn == null or not is_instance_valid(era_info_btn) or not era_info_btn.is_visible_in_tree():
        return false
    if event is InputEventKey:
        return event.keycode == KEY_H
    if event is InputEventJoypadButton:
        return event.button_index == JOY_BUTTON_Y
    if event is InputEventMouseButton or event is InputEventScreenTouch:
        return era_info_btn.get_global_rect().grow(10).has_point(event.position)
    return false

# Your form's animated drawing for the era page (the same art the pause
# screen uses); null if the player isn't there
func _era_form_tile(parent: Control, disc: float) -> Control:
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        return null
    var spr: Sprite2D = player.get_node_or_null("Sprite2D")
    var tex: Texture2D = spr.texture if spr else null
    var frames: int = spr.hframes if spr else 1
    var spin: float = -PI / 2 + player.heading_offset
    var sheet = "res://assets/lineages/%s_sheet.png" % player.current_character_id
    if tex == null and ResourceLoader.exists(sheet):
        tex = load(sheet)
        frames = 4
        spin = 0.0
    var t = PauseTile.new().setup(tex, frames, disc, "")
    t.spin = spin
    _quiet_tile(parent, t)
    return t

# A picture only: taps go to the page (which closes it), not the tile
func _quiet_tile(parent: Control, t: Control):
    parent.add_child(t)
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    t.focus_mode = Control.FOCUS_NONE

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
func _open_card(color: Color, width: float, dim: float = 0.8) -> VBoxContainer:
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
    bg.color = Color(UI.BACKDROP, dim)
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
    UI.reveal(intro_card, panel, 0.24)
    return vbox

func _add_rows(parent: Container, rows: Array, columns: int = 2, px: int = 22):
    var grid = GridContainer.new()
    grid.columns = columns
    grid.add_theme_constant_override("h_separation", 28)
    grid.add_theme_constant_override("v_separation", 10)
    parent.add_child(grid)
    for r in rows:
        var key = _card_label(r[0], px, UI.LEAF)
        key.autowrap_mode = TextServer.AUTOWRAP_OFF
        grid.add_child(key)
        var val = _card_label(r[1], px, UI.CREAM)
        val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_child(val)

func _close_card(vbox: VBoxContainer, verb: String):
    var hint = _card_label(PadInput.prompt("Press A to ", "Tap anywhere to ", "Press any key or click to ") + verb, 20, UI.SUN)
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
    if Time.get_ticks_msec() < intro_ready_time:
        return
    if _is_era_info_press(event):
        # A tap arrives twice on phones (touch, then the copied mouse click)
        if Time.get_ticks_msec() - era_info_at > 300:
            toggle_era_info()
        return
    if Time.get_ticks_msec() - era_info_at < 300:
        return
    dismiss_card()

func _process(delta: float):
    _watch_grow_fight(delta)
