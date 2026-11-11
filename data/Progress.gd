# Progress.gd
# Challenges and what they unlock, kept across runs in user://progress.cfg.
# Each challenge unlocks a starting trait: an adaptation from
# data/Adaptations.gd the player can choose on the main menu to begin a run
# with. Main.gd and Player.gd report events; complete() saves and returns
# true the first time so the game can announce it.
extends RefCounted

const SAVE_PATH = "user://progress.cfg"

const CHALLENGES = [
	{"id": "ediacaran", "name": "Out of the Garden", "goal": "Defeat the Ediacaran boss", "unlock": "muscle"},
	{"id": "arthropod", "name": "Jointed Legs", "goal": "Evolve into an arthropod", "unlock": "reach"},
	{"id": "ordovician", "name": "Into the Ordovician", "goal": "Reach the third era", "unlock": "myoglobin"},
	{"id": "untouched", "name": "Untouched", "goal": "Clear a whole era without being hit", "unlock": "body_wall"},
	{"id": "well_fed", "name": "Well Fed", "goal": "Grow 10 parts in one run", "unlock": "mitochondria"},
	{"id": "codex_10", "name": "Taxonomist", "goal": "Discover 10 lineages in the codex", "unlock": "senses"},
	{"id": "codex_25", "name": "Systematist", "goal": "Discover 25 lineages in the codex", "unlock": "gut"},
	{"id": "survivor", "name": "Survive the Great Dying", "goal": "Win a run", "unlock": "armour"},
]

static func _load() -> ConfigFile:
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	return config

static func completed() -> Array:
	return _load().get_value("progress", "completed", [])

static func is_complete(id: String) -> bool:
	return completed().has(id)

static func get_challenge(id: String) -> Dictionary:
	for c in CHALLENGES:
		if c.id == id:
			return c
	return {}

# True only the first time, so the caller can show a banner
static func complete(id: String) -> bool:
	var config = _load()
	var done: Array = config.get_value("progress", "completed", [])
	if done.has(id) or get_challenge(id).is_empty():
		return false
	done.append(id)
	config.set_value("progress", "completed", done)
	config.save(SAVE_PATH)
	return true

# Adaptation ids the player has unlocked as starting traits
static func unlocked_traits() -> Array:
	var traits: Array = []
	for c in CHALLENGES:
		if is_complete(c.id):
			traits.append(c.unlock)
	return traits

static func start_trait() -> String:
	var t: String = _load().get_value("progress", "start_trait", "")
	return t if unlocked_traits().has(t) else ""

static func set_start_trait(id: String):
	var config = _load()
	config.set_value("progress", "start_trait", id)
	config.save(SAVE_PATH)

# Each finished run (death or victory): counts runs and wins and keeps the
# furthest era reached with the form that got there, for the main menu.
# Returns true when this run went further than any before.
static func record_run(era: int, form_name: String, won: bool) -> bool:
	var config = _load()
	config.set_value("runs", "count", int(config.get_value("runs", "count", 0)) + 1)
	if won:
		config.set_value("runs", "wins", int(config.get_value("runs", "wins", 0)) + 1)
	var best = int(config.get_value("runs", "best_era", 0))
	var record = era > best
	if record:
		config.set_value("runs", "best_era", era)
		config.set_value("runs", "best_form", form_name)
	config.save(SAVE_PATH)
	return record

static func run_stats() -> Dictionary:
	var config = _load()
	return {
		"count": int(config.get_value("runs", "count", 0)),
		"wins": int(config.get_value("runs", "wins", 0)),
		"best_era": int(config.get_value("runs", "best_era", 0)),
		"best_form": str(config.get_value("runs", "best_form", "")),
	}
