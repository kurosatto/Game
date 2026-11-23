# SettingsManager.gd
extends Node

signal brightness_changed(value: float)
signal sfx_volume_changed(value: float)
signal art_style_changed(id: String)
signal fullscreen_changed(on: bool)

var brightness: float = 1.2 # Default bright & vibrant
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var window_mode_index: int = 1 # Default 1920x1080 (Full HD)
var aim_assist: bool = true # touch shots bend onto a nearby animal (Player.aim_assist)
var screen_shake: bool = true
# The whole world's look (data/ArtStyles.gd), chosen on the main menu
var art_style: String = "sepia"
# Main menu SENSE TEST: every fight room is pitch dark (LevelGenerator.gd)
var dark_rooms_all: bool = false

var config_path: String = "user://settings.cfg"

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_symbol_fallbacks()
    load_settings()
    apply_all_settings()

# Web browsers give Godot no system fonts, so the menu symbols and emoji
# (▶ ⚙ 🏆 📖 ...) would show as boxes. Small subsets of DejaVu Sans and Noto
# Color Emoji in assets/ui fill in for whatever Fredoka lacks.
func add_symbol_fallbacks():
    var extra = [load("res://assets/ui/SymbolsFallback.ttf"), load("res://assets/ui/EmojiFallback.ttf")]
    for path in ["res://assets/ui/Fredoka-Medium.ttf", "res://assets/ui/Fredoka-SemiBold.ttf"]:
        var font: FontFile = load(path)
        font.fallbacks = extra

func load_settings():
    var config = ConfigFile.new()
    var err = config.load(config_path)
    if err != OK:
        window_mode_index = default_window_mode()
    if err == OK:
        brightness = config.get_value("graphics", "brightness", 1.2)
        sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
        music_volume = config.get_value("audio", "music_volume", 0.8)
        # "window_mode_v2": older saves kept a 1920x1080 window from before
        # fullscreen became the default, so they start fullscreen once
        window_mode_index = config.get_value("display", "window_mode_v2", default_window_mode())
        aim_assist = config.get_value("controls", "aim_assist", true)
        screen_shake = config.get_value("graphics", "screen_shake", true)
        art_style = config.get_value("graphics", "art_style", "sepia")
        dark_rooms_all = config.get_value("gameplay", "dark_rooms_all", false)
        if not preload("res://data/ArtStyles.gd").ids().has(art_style):
            art_style = "sepia"

# PCs (and the Legion Go) start fullscreen
func default_window_mode() -> int:
    if OS.has_feature("mobile") or OS.has_feature("web") or DisplayServer.get_name() == "headless":
        return 1
    return 3

func is_fullscreen() -> bool:
    return window_mode_index == 3

# Main menu button, F11 and Alt+Enter: fullscreen, or the biggest window
# that fits the screen
func toggle_fullscreen():
    if is_fullscreen():
        var screen = DisplayServer.screen_get_size()
        set_window_mode(1 if screen.x > 1920 and screen.y > 1080 else 0)
    else:
        set_window_mode(3)
    save_settings()
    fullscreen_changed.emit(is_fullscreen())

func _unhandled_input(event: InputEvent):
    if OS.has_feature("mobile") or OS.has_feature("web"):
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
            toggle_fullscreen()
            get_viewport().set_input_as_handled()

func save_settings():
    var config = ConfigFile.new()
    config.set_value("graphics", "brightness", brightness)
    config.set_value("audio", "sfx_volume", sfx_volume)
    config.set_value("audio", "music_volume", music_volume)
    config.set_value("display", "window_mode_v2", window_mode_index)
    config.set_value("controls", "aim_assist", aim_assist)
    config.set_value("graphics", "screen_shake", screen_shake)
    config.set_value("graphics", "art_style", art_style)
    config.set_value("gameplay", "dark_rooms_all", dark_rooms_all)
    config.save(config_path)

func apply_all_settings():
    preload("res://data/UIStyle.gd").apply(art_style)
    set_brightness(brightness)
    set_sfx_volume(sfx_volume)
    set_music_volume(music_volume)
    set_window_mode(window_mode_index)

func set_brightness(val: float):
    brightness = clamp(val, 0.5, 2.0)
    brightness_changed.emit(brightness)
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("update_ambient_lighting"):
        main.update_ambient_lighting()
    elif main and main.has_node("CanvasModulate"):
        var cm = main.get_node("CanvasModulate")
        cm.color = Color(brightness, brightness, brightness, 1.0)

func set_art_style(id: String):
    if id == art_style:
        return
    art_style = id
    save_settings()
    preload("res://data/UIStyle.gd").apply(id)
    art_style_changed.emit(id)

func set_sfx_volume(val: float):
    sfx_volume = clamp(val, 0.0, 1.5)
    sfx_volume_changed.emit(sfx_volume)
    
    _set_bus_volume("SFX", sfx_volume)

func set_music_volume(val: float):
    music_volume = clamp(val, 0.0, 1.5)
    _set_bus_volume("Music", music_volume)

# The SFX and Music buses are created by SoundManager, which loads first
func _set_bus_volume(bus_name: String, val: float):
    var bus_idx = AudioServer.get_bus_index(bus_name)
    if bus_idx == -1:
        return
    AudioServer.set_bus_mute(bus_idx, val <= 0.01)
    if val > 0.01:
        AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))

func set_window_mode(index: int):
    window_mode_index = index
    # Phones always run fullscreen; the desktop window sizes don't apply
    # (and a browser tab can't be resized by the game)
    if OS.has_feature("mobile") or OS.has_feature("web"):
        return
    match index:
        0: # 1280x720
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_size(Vector2i(1280, 720))
        1: # 1920x1080
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_size(Vector2i(1920, 1080))
        2: # 2560x1440
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_size(Vector2i(2560, 1440))
        3: # Fullscreen
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
