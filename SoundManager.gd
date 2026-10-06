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
}

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_sounds()
    for i in range(pool_size):
        var ap = AudioStreamPlayer.new()
        ap.bus = "Master"
        add_child(ap)
        player_pool.append(ap)

func load_sounds():
    for s_name in SOUND_VOLUMES.keys():
        var path = "res://assets/sfx/" + s_name + ".wav"
        if FileAccess.file_exists(path):
            sound_streams[s_name] = load(path)

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
