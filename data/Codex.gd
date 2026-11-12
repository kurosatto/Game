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
