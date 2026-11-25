# SoundManager.gd
extends Node

var sound_streams: Dictionary = {}
# Extra takes of a sound (name_2.wav, name_3.wav...): each play picks one at
# random so a fight isn't the same knock over and over
var sound_takes: Dictionary = {}
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
    # Senses (generate_sense_sfx.py): a soft cue when the best non-visual
    # sense first picks up an animal hidden in the dark (SenseHints.gd)
    "sense_smell": -10.0, "sense_chemical": -10.0, "sense_electric": -12.0,
    "sense_lateral": -9.0, "sense_vibration": -8.0, "sense_touch": -10.0,
    # Combat (generate_combat_sfx.py, softened by tools/build_combat_sfx.py C): one attack sound per
    # weapon, hits that sound like what they struck, and kills to match. The
    # build already sets their loudness (attacks under hits, kills a touch
    # over, enemy moves quieter), so they all sit at 0 here.
    "atk_vesicle": 0.0, "atk_jet": 0.0, "atk_spit": 0.0, "atk_harpoon": 0.0,
    "atk_slime": 0.0, "atk_silk": 0.0, "atk_spray": 0.0, "atk_engulf": 0.0,
    "atk_clamp": 0.0, "atk_bite": 0.0, "atk_rasp": 0.0, "atk_pincer": 0.0,
    "atk_claw": 0.0, "atk_lash": 0.0, "atk_sting": 0.0, "atk_arms": 0.0,
    "atk_tongue": 0.0, "atk_spines": 0.0, "atk_smash": 0.0,
    "hit_soft": 0.0, "hit_shell": 0.0, "hit_flesh": 0.0, "hit_crit": 0.0,
    "hit_glance": 0.0, "parry": 0.0,
    "kill_soft": 0.0, "kill_shell": 0.0, "kill_flesh": 0.0,
    "enemy_lunge": 0.0, "enemy_spit": 0.0, "hurt_thud": 0.0,
}

# The same sound fired twice within this many seconds plays once: a spray of
# three droplets, or a sweep through a swarm, shouldn't stack into a roar
const REPEAT_GAP := 0.035
var last_played: Dictionary = {}

# Looping soundtrack: OpenGameArt tracks listed in data/MusicCredits.gd, each
# in a pool (menu, explore for floors, boss). While kuro picks favourites, every
# menu visit, floor and boss plays a random track from its pool, working through
# a shuffled bag so every track comes up before any repeats.
const MUSIC = preload("res://data/MusicCredits.gd")
const MUSIC_VOLUME_DB := -10.0 # music sits under the hit and kill sounds
const MUSIC_FADE := 1.6

var music_streams: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var music_active: int = 0
var current_track: String = ""
var track_info: Dictionary = {}   # id -> MusicCredits entry
var music_bags: Dictionary = {}   # pool -> ids not yet played this round
var floor_tracks: Dictionary = {} # "explore_<floor>" / "boss_<floor>" -> id, this run
var now_playing_label: Label
var now_playing_box: PanelContainer
var now_playing_tween: Tween
var music_badge: PanelContainer
var music_badge_label: Label
# Browsers keep audio locked until the player first taps, clicks or presses
# a key, and a track started before then stays silent. On the web the music
# waits for that first input, then starts.
var audio_unlocked: bool = not OS.has_feature("web")
var pending_track: String = ""

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

# SFX and Music come from default_bus_layout.tres. Don't rely on adding them
# here: in the web build AudioServer.add_bus() moves the new bus to the front
# of the browser's copy of the bus list, wiring Master, SFX and Music into a
# loop that never reaches the speakers, so the game is silent.
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
        # ResourceLoader, not FileAccess: exported builds (web, Windows,
        # Android) pack only the imported copy of each .wav, so the source
        # file "doesn't exist" there and every sound was skipped
        if ResourceLoader.exists(path):
            sound_streams[s_name] = load(path)
            var takes: Array = [sound_streams[s_name]]
            for i in range(2, 6):
                var take = "res://assets/sfx/%s_%d.wav" % [s_name, i]
                if not ResourceLoader.exists(take):
                    break
                takes.append(load(take))
            if takes.size() > 1:
                sound_takes[s_name] = takes
        else:
            push_warning("SoundManager: missing sound " + path)
    for t in MUSIC.TRACKS:
        track_info[t.id] = t

# Streams load the first time they play, so 30 tracks don't all sit in memory
func _music_stream(track: String):
    if not music_streams.has(track):
        var path = "res://assets/music/" + track + ".ogg"
        if not ResourceLoader.exists(path):
            return null
        var stream = load(path)
        stream.loop = true
        music_streams[track] = stream
    return music_streams[track]

# Crossfade to a looping track; asking for the one already playing does nothing
func play_music(track: String):
    if not audio_unlocked:
        pending_track = track
        return
    if track == current_track or _music_stream(track) == null:
        return
    current_track = track
    _show_now_playing()
    var old_player = music_players[music_active]
    music_active = 1 - music_active
    var new_player = music_players[music_active]
    new_player.stream = music_streams[track]
    if OS.has_feature("web"):
        # Web audio plays each track as a browser sample, which doesn't
        # reliably follow a volume fade (it can stay near silent): cut instead
        old_player.stop()
        new_player.volume_db = MUSIC_VOLUME_DB
        new_player.play()
        return
    new_player.volume_db = -40.0
    new_player.play()
    var tw = create_tween().set_parallel(true)
    tw.tween_property(new_player, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE)
    if old_player.playing:
        tw.tween_property(old_player, "volume_db", -60.0, MUSIC_FADE)
        tw.chain().tween_callback(old_player.stop)

func _input(event: InputEvent):
    if audio_unlocked:
        return
    var pressed = (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed()
    if pressed:
        audio_unlocked = true
        if pending_track != "":
            play_music(pending_track)

# A random track from a pool, drawn from a shuffled bag so every track in the
# pool plays once before any comes round again
func random_track(pool: String) -> String:
    var bag: Array = music_bags.get(pool, [])
    if bag.is_empty():
        for t in MUSIC.TRACKS:
            if t.pool == pool:
                bag.append(t.id)
        bag.shuffle()
        # don't start the new round with the track that just played
        if bag.size() > 1 and bag[-1] == current_track:
            bag.push_front(bag.pop_back())
    var pick = bag.pop_back()
    music_bags[pool] = bag
    return pick

func play_menu_music():
    floor_tracks.clear()
    play_music(random_track("menu"))

# A new run picks new floor and boss tracks
func new_run():
    floor_tracks.clear()

# Each floor keeps its random track for the run, so the floor music comes back
# after its boss
func music_for_floor(floor_num: int) -> String:
    var key = "explore_%d" % floor_num
    if not floor_tracks.has(key):
        floor_tracks[key] = random_track("explore")
    return floor_tracks[key]

func boss_music_for_floor(floor_num: int) -> String:
    var key = "boss_%d" % floor_num
    if not floor_tracks.has(key):
        floor_tracks[key] = random_track("boss")
    return floor_tracks[key]

# "#12 Title · Artist" of the track playing now (pause screen), or ""
func now_playing() -> String:
    var t = track_info.get(current_track, {})
    if t.is_empty():
        return ""
    return "#%d %s · %s" % [t.get("num", 0), t.title, t.artist]

# The track name fades in at the bottom of the screen for a few seconds when it starts,
# so kuro can tell which tracks they like
func _show_now_playing():
    var text = now_playing()
    if text == "":
        return
    if now_playing_label == null:
        var layer = CanvasLayer.new()
        layer.layer = 90
        add_child(layer)
        now_playing_box = PanelContainer.new()
        var bg = StyleBoxFlat.new()
        bg.bg_color = Color(0.16, 0.11, 0.07, 0.8)
        bg.set_corner_radius_all(12)
        bg.set_content_margin_all(12)
        bg.content_margin_left = 18
        bg.content_margin_right = 18
        now_playing_box.add_theme_stylebox_override("panel", bg)
        now_playing_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        now_playing_box.modulate.a = 0.0
        layer.add_child(now_playing_box)
        now_playing_label = Label.new()
        now_playing_label.add_theme_font_size_override("font_size", 22)
        now_playing_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
        now_playing_box.add_child(now_playing_label)
        # The track's number stays in the top-left corner the whole time it
        # plays, just under the hearts, so a favourite is easy to note
        music_badge = PanelContainer.new()
        var bb = bg.duplicate()
        bb.set_content_margin_all(6)
        bb.content_margin_left = 12
        bb.content_margin_right = 12
        music_badge.add_theme_stylebox_override("panel", bb)
        music_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        music_badge.position = Vector2(16, 84)
        layer.add_child(music_badge)
        music_badge_label = Label.new()
        music_badge_label.add_theme_font_size_override("font_size", 20)
        music_badge_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
        music_badge.add_child(music_badge_label)
    music_badge_label.text = "MUSIC #%d" % track_info[current_track].get("num", 0)
    music_badge.reset_size()
    now_playing_label.text = "Music " + text
    # bottom middle (clear of the touch sticks in the corners), sized to the text
    now_playing_box.reset_size()
    var vp = now_playing_box.get_viewport_rect().size
    var box = now_playing_box.get_combined_minimum_size()
    now_playing_box.position = Vector2((vp.x - box.x) / 2.0, vp.y - box.y - 24)
    if now_playing_tween:
        now_playing_tween.kill()
    now_playing_box.modulate.a = 0.0
    now_playing_tween = now_playing_box.create_tween()
    now_playing_tween.tween_property(now_playing_box, "modulate:a", 1.0, 0.6)
    now_playing_tween.tween_interval(4.0)
    now_playing_tween.tween_property(now_playing_box, "modulate:a", 0.0, 1.2)

# The attack sound of a form's weapon (Lineages.WEAPONS key)
func play_attack(weapon: String, pitch_scale: float = 1.0):
    if sound_streams.has("atk_" + weapon):
        play_sfx("atk_" + weapon, pitch_scale)
    else:
        play_sfx("shoot", pitch_scale)

# A blow landing on an animal: soft bodies squelch, shells clack, bony
# backs thud (Fauna.body_of). A signature move adds a crunch on top.
func play_hit(body: String, crit: bool = false, volume_db: float = 0.0):
    var s_name = "hit_" + body
    play_sfx(s_name if sound_streams.has(s_name) else "hit", randf_range(0.92, 1.1), volume_db)
    if crit:
        play_sfx("hit_crit", randf_range(0.95, 1.05))

func play_kill(body: String, boss: bool = false):
    var s_name = "kill_" + body
    if sound_streams.has(s_name):
        play_sfx(s_name, 0.75 if boss else randf_range(0.92, 1.08), 2.0 if boss else 0.0)
    if boss or not sound_streams.has(s_name):
        play_sfx("enemy_die", 0.6 if boss else 1.0, -4.0 if sound_streams.has(s_name) else 0.0)

func play_sfx(s_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0):
    if not sound_streams.has(s_name):
        return
    var now = Time.get_ticks_msec() / 1000.0
    if now - last_played.get(s_name, -1.0) < REPEAT_GAP:
        return
    last_played[s_name] = now

    # Start from per-sound base volume, then apply any caller adjustment
    var base_vol = SOUND_VOLUMES.get(s_name, 0.0)
    var final_vol = base_vol + volume_db

    var stream = sound_streams[s_name]
    if sound_takes.has(s_name):
        stream = sound_takes[s_name].pick_random()

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
