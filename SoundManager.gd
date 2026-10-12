# SoundManager.gd
extends Node

var sound_streams: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 16  # Larger pool for fast-fire without stealing

# Per-sound default volume offsets in dB (tuned for balance)
# Negative = quieter. Positive = louder (use sparingly).
const SOUND_VOLUMES: Dictionary = {
    "shoot":        -4.0,   # Player shot — prominent but not harsh
    "hit":          -3.0,   # Enemy hit — punchy but short
    "enemy_die":    -2.0,   # Enemy pop — satisfying
    "dna_pickup":   -5.0,   # Pickup jingle — bright, not intrusive
    "heart_pickup": -4.0,   # Heart chime — warm
    "door_open":    -8.0,   # Door whoosh — subtle background
    "player_hurt":  -2.0,   # Player ouch — clear, not ear-piercing
    "explosion":    -1.0,   # Bomb boom — impactful
    "boss_roar":    -3.0,   # Boss rumble — cinematic
    "level_up":     -3.0,   # Level up fanfare — rewarding
    "dash":         -7.0,   # Water whoosh on dash
    "zap":          -6.0,   # Bio-electric discharge
    "evolve":       -4.0,   # Evolution card chosen
    "boss_intro":   -2.0,   # Boss room entered
    "room_clear":   -6.0,   # Last enemy in a room died
}

# Looping background tracks (generate_music.py), by name
const MUSIC_TRACKS := ["tidepool", "reef", "abyss", "boss"]
const MUSIC_VOLUME_DB := -10.0
const MUSIC_FADE := 1.6

var music_streams: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var music_active: int = 0
var current_track: String = ""

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_bus("SFX")
    _ensure_bus("Music")
    load_sounds()
    for i in range(pool_size):
        var ap = AudioStreamPlayer.new()
        ap.bus = "SFX"
        add_child(ap)
        player_pool.append(ap)
    # Two music players so tracks can crossfade
    for i in 2:
        var mp = AudioStreamPlayer.new()
        mp.bus = "Music"
        mp.volume_db = -80.0
        add_child(mp)
        music_players.append(mp)

func _ensure_bus(bus_name: String):
    if AudioServer.get_bus_index(bus_name) != -1:
        return
    AudioServer.add_bus()
    var idx = AudioServer.bus_count - 1
    AudioServer.set_bus_name(idx, bus_name)
    AudioServer.set_bus_send(idx, "Master")

func load_sounds():
    for s_name in SOUND_VOLUMES.keys():
        var path = "res://assets/sfx/" + s_name + ".wav"
        if FileAccess.file_exists(path):
            sound_streams[s_name] = load(path)
    for track in MUSIC_TRACKS:
        var path = "res://assets/music/" + track + ".wav"
        if ResourceLoader.exists(path):
            music_streams[track] = load(path)

# Crossfade to a looping track; asking for the one already playing does nothing
func play_music(track: String):
    if track == current_track or not music_streams.has(track):
        return
    current_track = track
    var old_player = music_players[music_active]
    music_active = 1 - music_active
    var new_player = music_players[music_active]
    new_player.stream = music_streams[track]
    new_player.volume_db = -40.0
    new_player.play()
    var tw = create_tween().set_parallel(true)
    tw.tween_property(new_player, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE)
    if old_player.playing:
        tw.tween_property(old_player, "volume_db", -60.0, MUSIC_FADE)
        tw.chain().tween_callback(old_player.stop)

# Calm track for each stretch of the run
func music_for_floor(floor_num: int) -> String:
    if floor_num <= 2:
        return "tidepool"
    if floor_num <= 4:
        return "reef"
    return "abyss"

func play_sfx(s_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0):
    if not sound_streams.has(s_name):
        return

    # Start from per-sound base volume, then apply any caller adjustment
    var base_vol = SOUND_VOLUMES.get(s_name, 0.0)
    var final_vol = base_vol + volume_db

    var stream = sound_streams[s_name]

    # Find a free player
    for ap in player_pool:
        if not ap.playing:
            _configure_and_play(ap, stream, pitch_scale, final_vol)
            return

    # All busy: steal the one with the lowest volume (least noticeable)
    var quietest = player_pool[0]
    for ap in player_pool:
        if ap.volume_db < quietest.volume_db:
            quietest = ap
    _configure_and_play(quietest, stream, pitch_scale, final_vol)

func _configure_and_play(ap: AudioStreamPlayer, stream, pitch_scale: float, volume_db: float):
    ap.stream = stream
    # Subtle organic pitch variation (±3%) for natural feel
    ap.pitch_scale = pitch_scale * randf_range(0.97, 1.03)
    ap.volume_db = volume_db
    ap.play()
