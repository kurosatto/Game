# SettingsManager.gd
extends Node

signal brightness_changed(value: float)
signal sfx_volume_changed(value: float)

var brightness: float = 1.2 # Default bright & vibrant
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var window_mode_index: int = 1 # Default 1920x1080 (Full HD)

var config_path: String = "user://settings.cfg"

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_settings()
    apply_all_settings()

func load_settings():
    var config = ConfigFile.new()
    var err = config.load(config_path)
    if err == OK:
        brightness = config.get_value("graphics", "brightness", 1.2)
        sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
        music_volume = config.get_value("audio", "music_volume", 0.8)
        window_mode_index = config.get_value("display", "window_mode", 1)

func save_settings():
    var config = ConfigFile.new()
    config.set_value("graphics", "brightness", brightness)
    config.set_value("audio", "sfx_volume", sfx_volume)
    config.set_value("audio", "music_volume", music_volume)
    config.set_value("display", "window_mode", window_mode_index)
    config.save(config_path)

func apply_all_settings():
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
    if OS.has_feature("mobile"):
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
