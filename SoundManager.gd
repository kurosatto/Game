# SoundManager.gd
extends Node

var sound_streams: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 12

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_sounds()
    # Create player pool
    for i in range(pool_size):
        var player = AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        player_pool.append(player)

func load_sounds():
    var sound_names = [
        "shoot", "hit", "enemy_die", "dna_pickup", "heart_pickup", 
        "door_open", "player_hurt", "explosion", "boss_roar", "level_up"
    ]
    for s_name in sound_names:
        var path = "res://assets/sfx/" + s_name + ".wav"
        if FileAccess.file_exists(path):
            sound_streams[s_name] = load(path)

func play_sfx(s_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0):
    if not sound_streams.has(s_name):
        return
    
    var stream = sound_streams[s_name]
    # Find free player in pool
    for player in player_pool:
        if not player.playing:
            player.stream = stream
            player.pitch_scale = pitch_scale * randf_range(0.95, 1.05) # subtle organic variation
            player.volume_db = volume_db
            player.play()
            return
            
    # If all busy, steal the oldest
    var player = player_pool[0]
    player.stream = stream
    player.pitch_scale = pitch_scale * randf_range(0.95, 1.05)
    player.volume_db = volume_db
    player.play()
