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
    config.set_value("codex", "discovered", discovered)
    config.save(SAVE_PATH)

static func is_discovered(id: String) -> bool:
    return load_discovered().has(id)
