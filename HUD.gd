# HUD.gd
extends CanvasLayer

@onready var coins_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Coins/Label
@onready var bombs_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Bombs/Label
@onready var keys_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Keys/Label
@onready var hearts_container = $HUDPanel/MarginContainer/HBoxContainer/Hearts
@onready var floor_label = $HUDPanel/MarginContainer/HBoxContainer/FloorLabel
@onready var dna_label = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaLabel
@onready var dna_bar = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaBar
@onready var settings_btn = $HUDPanel/MarginContainer/HBoxContainer/SettingsBtn

@onready var minimap_ctrl = $MinimapContainer/Minimap

@onready var boss_container = $BossHealthContainer
@onready var boss_bar = $BossHealthContainer/ProgressBar

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

func update_inventory(dna: int, bombs: int, keys: int):
    coins_label.text = "%02d" % dna
    bombs_label.text = "%02d" % bombs
    keys_label.text = "%02d" % keys

func update_dna(current_dna: int, max_dna: int, level: int):
    dna_label.text = "BIOMASS: %d / %d (LVL %d)" % [current_dna, max_dna, level]
    dna_bar.max_value = max_dna
    dna_bar.value = current_dna

func update_floor(floor_num: int):
    floor_label.text = "PRIMORDIAL TIDEPOOL " + str(floor_num)

func update_era(era_name: String, lineage_name: String):
    floor_label.text = era_name.to_upper() + "  |  " + lineage_name.to_upper()

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

func show_boss_health(current: float, max_value: float):
    boss_container.visible = true
    boss_bar.max_value = max_value
    boss_bar.value = current
    if current <= 0:
        boss_container.visible = false

func hide_boss_health():
    boss_container.visible = false

func show_item_banner(title: String, desc: String):
    item_banner.visible = true
    item_title.text = title
    item_desc.text = desc
    item_banner.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(item_banner, "modulate:a", 0.0, 0.4).set_delay(1.8)
    tween.tween_callback(func(): item_banner.visible = false)

func show_game_over():
    game_over_screen.visible = true
    
func show_victory():
    victory_screen.visible = true
