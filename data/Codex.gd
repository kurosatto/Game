# Codex.gd
# Remembers every lineage the player has evolved into, across runs.
# Saved to user://codex.cfg so discoveries survive restarts.
extends RefCounted

const SAVE_PATH = "user://codex.cfg"

static func load_discovered() -> Array:
    var config = ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return []
    return config.get_value("codex", "discovered", [])

static func discover(id: String):
    var discovered = load_discovered()
    if discovered.has(id):
        return
    discovered.append(id)
    var config = ConfigFile.new()
    config.load(SAVE_PATH) # keep the fossil record saved beside it
    config.set_value("codex", "discovered", discovered)
    config.save(SAVE_PATH)

static func is_discovered(id: String) -> bool:
    return load_discovered().has(id)

# ---- Fossil record ----
# Every era animal and boss the player has eaten, across runs (the main
# menu's FOSSILS page). Kept in memory once loaded, so a kill only touches
# the disk the first time a species is eaten.
static var _eaten: Array = []
static var _eaten_loaded: bool = false

static func load_eaten() -> Array:
    if not _eaten_loaded:
        var config = ConfigFile.new()
        if config.load(SAVE_PATH) == OK:
            _eaten = config.get_value("fossils", "eaten", [])
        _eaten_loaded = true
    return _eaten

# True the first time this species is eaten
static func note_eaten(species: String) -> bool:
    if species == "" or load_eaten().has(species):
        return false
    # tools/*.gd runs shouldn't fill the real save
    var tree = Engine.get_main_loop()
    if tree and tree.get_script() != null:
        return false
    _eaten.append(species)
    var config = ConfigFile.new()
    config.load(SAVE_PATH)
    config.set_value("fossils", "eaten", _eaten)
    config.save(SAVE_PATH)
    return true

# ---- Field sketches ----
# Every kind of animal sketched from life (rooms/FieldSketch.gd), across runs
static var _sketches: Array = []
static var _sketches_loaded: bool = false

static func load_sketches() -> Array:
    if not _sketches_loaded:
        var config = ConfigFile.new()
        if config.load(SAVE_PATH) == OK:
            _sketches = config.get_value("fossils", "sketches", [])
        _sketches_loaded = true
    return _sketches

static func note_sketch(species: String) -> bool:
    if species == "" or load_sketches().has(species):
        return false
    _sketches.append(species)
    var tree = Engine.get_main_loop()
    if tree and tree.get_script() != null:
        return true # tools/*.gd runs: remember for this run only
    var config = ConfigFile.new()
    config.load(SAVE_PATH)
    config.set_value("fossils", "sketches", _sketches)
    config.save(SAVE_PATH)
    return true

# ---- Trace fossils ----
# Every kind of trace (data/Traces.gd) the player has seen made, across runs
static var _traces: Array = []
static var _traces_loaded: bool = false

static func load_traces() -> Array:
    if not _traces_loaded:
        var config = ConfigFile.new()
        if config.load(SAVE_PATH) == OK:
            _traces = config.get_value("fossils", "traces", [])
        _traces_loaded = true
    return _traces

# True the first time this kind of trace is seen
static func note_trace(id: String) -> bool:
    if load_traces().has(id):
        return false
    _traces.append(id)
    var tree = Engine.get_main_loop()
    if tree and tree.get_script() != null:
        return true # tools/*.gd runs: remember for this run only
    var config = ConfigFile.new()
    config.load(SAVE_PATH)
    config.set_value("fossils", "traces", _traces)
    config.save(SAVE_PATH)
    return true

# ---- Food web ----
# Every hunt the player has watched ("Pred>Prey", data/FoodWeb.gd), across
# runs. The fossil record lists them under each animal.
static var _hunts: Array = []
static var _hunts_loaded: bool = false

static func load_hunts() -> Array:
    if not _hunts_loaded:
        var config = ConfigFile.new()
        if config.load(SAVE_PATH) == OK:
            _hunts = config.get_value("fossils", "hunts", [])
        _hunts_loaded = true
    return _hunts

# True the first time this hunter is seen eating this prey
static func note_hunt(link: String) -> bool:
    if load_hunts().has(link):
        return false
    _hunts.append(link)
    var tree = Engine.get_main_loop()
    if tree and tree.get_script() != null:
        return true # tools/*.gd runs: remember for this run only
    var config = ConfigFile.new()
    config.load(SAVE_PATH)
    config.set_value("fossils", "hunts", _hunts)
    config.save(SAVE_PATH)
    return true
