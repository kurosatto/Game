# Progress.gd
# Challenges and the lineages they open, kept across runs in user://progress.cfg.
# A run always starts as the ancestral cell and only the arthropod branch is
# open at first; each challenge opens one more branch of the tree of life
# (a path in data/Lineages.gd) on the evolution cards. Every split keeps at
# least one branch open. Main.gd and Player.gd report events; complete()
# saves and returns true the first time so the game can announce it.
extends RefCounted

const SAVE_PATH = "user://progress.cfg"
# Tool scripts keep every lineage open unless they set this
static var test_locks := false

const CHALLENGES = [
	{"id": "arthropod", "name": "Jointed Legs", "goal": "Evolve into an arthropod", "lineage": "2"},
	{"id": "ediacaran", "name": "Out of the Garden", "goal": "Defeat the Ediacaran boss", "lineage": "1"},
	{"id": "ordovician", "name": "Into the Ordovician", "goal": "Reach the third era", "lineage": "0"},
	{"id": "well_fed", "name": "Well Fed", "goal": "Eat 60 elements in one run", "lineage": "2,2"},
	{"id": "untouched", "name": "Untouched", "goal": "Clear a whole era without being hit", "lineage": "2,0"},
	{"id": "codex_10", "name": "Taxonomist", "goal": "Discover 10 lineages in the codex", "lineage": "1,1"},
	{"id": "codex_25", "name": "Systematist", "goal": "Discover 25 lineages in the codex", "lineage": "0,0"},
	{"id": "survivor", "name": "Survive the Great Dying", "goal": "Win a run", "lineage": "0,0,0"},
]

# The challenge that opens the branch at `path`, or {} if it is always open
static func challenge_for_lineage(path: String) -> Dictionary:
	for c in CHALLENGES:
		if c.lineage == path:
			return c
	return {}

# Whether the evolution cards may offer the branch at `path`
static func lineage_open(path: String) -> bool:
	var c = challenge_for_lineage(path)
	return c.is_empty() or is_complete(c.id)

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

# Each finished run (death or victory): counts runs and wins and keeps the
# furthest era reached with the form that got there, for the main menu.
# Returns true when this run went further than any before.
# extra: what the past-runs page shows (form ids along the lineage, killer...)
const HISTORY_MAX := 40

static func record_run(era: int, form_name: String, won: bool, extra: Dictionary = {}) -> bool:
	var config = _load()
	var history: Array = config.get_value("runs", "history", [])
	var entry = extra.duplicate()
	entry["era"] = era
	entry["form"] = form_name
	entry["won"] = won
	entry["date"] = Time.get_date_string_from_system()
	history.append(entry)
	while history.size() > HISTORY_MAX:
		history.pop_front()
	config.set_value("runs", "history", history)
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

# Past runs, oldest first
static func history() -> Array:
	return _load().get_value("runs", "history", [])

static func run_stats() -> Dictionary:
	var config = _load()
	return {
		"count": int(config.get_value("runs", "count", 0)),
		"wins": int(config.get_value("runs", "wins", 0)),
		"best_era": int(config.get_value("runs", "best_era", 0)),
		"best_form": str(config.get_value("runs", "best_form", "")),
	}

# ---- Banked elements and lineage growth (main menu GROW page) ----
# Elements eaten in runs are banked here (Main.flush_bank) and spent on parts
# grown into the lineage for good (data/Biominerals.gd lineage_*). Main.gd
# grants every rank at the start of each run.
static func bank() -> Dictionary:
	return _load().get_value("lineage", "bank", {})

static func add_to_bank(delta: Dictionary):
	if delta.is_empty():
		return
	var config = _load()
	var b: Dictionary = config.get_value("lineage", "bank", {})
	for el in delta:
		b[el] = max(0.0, float(b.get(el, 0.0)) + float(delta[el]))
	config.set_value("lineage", "bank", b)
	config.save(SAVE_PATH)

static func lineage_ranks() -> Dictionary:
	return _load().get_value("lineage", "ranks", {})

# Spends the bank on one more rank of a part; false if it can't be afforded
static func grow_lineage(id: String) -> bool:
	var B = preload("res://data/Biominerals.gd")
	var r = B.get_recipe(id)
	if r.is_empty() or r.has("heal"):
		return false
	var config = _load()
	var b: Dictionary = config.get_value("lineage", "bank", {})
	var ranks: Dictionary = config.get_value("lineage", "ranks", {})
	if not B.can_grow_lineage(r, b, ranks):
		return false
	if not preload("res://data/Unlocks.gd").is_unlocked(id, stats(), ranks):
		return false
	var c = B.lineage_cost(r, int(ranks.get(id, 0)))
	for el in c:
		b[el] = max(0.0, float(b.get(el, 0.0)) - c[el])
	ranks[id] = int(ranks.get(id, 0)) + 1
	config.set_value("lineage", "bank", b)
	config.set_value("lineage", "ranks", ranks)
	config.save(SAVE_PATH)
	return true

# Lifetime counts that open GROW parts (data/Unlocks.gd): "eat:Isotelus",
# "eat_all", "seep", "hatch", "sketch", "boss:2"; "reach:<form id>" keeps the
# furthest floor reached as a descendant of that form
static func stats() -> Dictionary:
	return _load().get_value("lineage", "stats", {})

static func add_stats(delta: Dictionary, maxima: Dictionary = {}):
	if delta.is_empty() and maxima.is_empty():
		return
	var config = _load()
	var st: Dictionary = config.get_value("lineage", "stats", {})
	for k in delta:
		st[k] = int(st.get(k, 0)) + int(delta[k])
	for k in maxima:
		st[k] = max(int(st.get(k, 0)), int(maxima[k]))
	config.set_value("lineage", "stats", st)
	config.save(SAVE_PATH)

# Parts already shown as open on the GROW page, so new ones can say NEW
static func seen_unlocks() -> Array:
	return _load().get_value("lineage", "seen", [])

static func set_seen_unlocks(ids: Array):
	var config = _load()
	config.set_value("lineage", "seen", ids)
	config.save(SAVE_PATH)
