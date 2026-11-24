# Endgame.gd
# What opens up once you have won (kuro, 2026-11-24: "add extra bosses and
# more content to the end game, unlockable new bosses"). Each entry is shown
# on the main menu ENDGAME page, locked with its goal until reached.
#
#   great_dying  THE GREAT DYING: after the Permian boss a second way down
#                leads into the end-Permian extinction itself, 251.9 million
#                years ago. Every fight room has the killing gas or dead
#                water, the light is ash-red, and at the bottom wait the last
#                giants of their kind: Inostrancevia on land, the sweep-
#                feeding sea scorpion Campylocephalus at sea. Both lineages
#                ended in this extinction.
#
#   gauntlet     FOSSIL GAUNTLET (beat the Great Dying): a boss rush. Each
#                era is only a start room and its boss room; you evolve after
#                each boss as usual and are healed for the next, ending with
#                the Great Dying's last boss. Runs here don't count as wins.
#   deep_time    DEEP TIME (beat the Fossil Gauntlet): a switch for harder
#                runs. Tougher animals and bosses, an extra animal per room,
#                bosses rest even less. Wins count, and are marked.
#
# Counts come from Progress (runs/wins, lineage/stats "finale_won").
# ENDGAME=1 in the environment opens everything, for tests and screenshots.
extends RefCounted

const PROGRESS = preload("res://data/Progress.gd")

const ENTRIES = [
	{"id": "great_dying", "name": "THE GREAT DYING",
		"goal": "Win a run", "type": "wins", "need": 1,
		"what": "After the Permian boss, a second way down leads into the end-Permian extinction: ash-red skies, killing gas on land, dead water at sea, and the last giants waiting at the bottom.",
		"fact": "252 million years ago the Siberian Traps erupted for thousands of years. About 80% of sea species and 70% of land vertebrate species died out: the worst extinction in Earth's history.",
		"bosses": ["inostrancevia", "campylocephalus"]},
	{"id": "gauntlet", "name": "FOSSIL GAUNTLET",
		"goal": "Survive the Great Dying", "type": "stat", "key": "finale_won", "need": 1,
		"what": "A boss rush. Start as the ancestral cell and face every boss of the eras back to back, evolving after each one, all the way to the last giant of the Great Dying. Healed between fights.",
		"fact": "Most of what we know of these animals comes from a few lucky fossil beds, like the Burgess Shale and Mazon Creek, where soft bodies were buried fast in fine mud.",
		"play": true},
	{"id": "deep_time", "name": "DEEP TIME",
		"goal": "Beat the Fossil Gauntlet", "type": "stat", "key": "gauntlet_won", "need": 1,
		"what": "A switch for harder runs: animals +30% health, bosses +30% health and less rest, one more animal in every fight room. Wins are marked on the past runs page.",
		"fact": "Deep time is the geologists' name for the vast age of the Earth, 4.5 billion years. Squeezed into one day, the first animals would turn up at about 9 pm.",
		"toggle": true},
	{"id": "lairs", "name": "SECRET LAIRS",
		"goal": "Win 3 runs", "type": "wins", "need": 3,
		"what": "On the Carboniferous floor a giant hides in a dead-end room: the giant shark Saivodus at sea, and on land Megarachne, the 'giant spider' that wasn't. Each leaves an item behind.",
		"fact": "Fossils get misread: Megarachne was drawn as a spider for 25 years, until a second specimen showed it was a sea scorpion.",
		"bosses": ["megarachne", "saivodus"]},
]

# Secret lair giants: floor 4, one per world
const LAIR_FLOOR := 4
const LAIRS = {
	"megarachne": {"name": "Megarachne", "world": "land", "script": "res://bosses/Megarachne.gd",
		"fact": "Described in 1980 as the biggest spider ever, a third of a metre long. A second fossil, studied in 2005, showed it was a sea scorpion, close kin to Campylocephalus."},
	"saivodus": {"name": "Saivodus", "world": "sea", "script": "res://bosses/Saivodus.gd",
		"fact": "A ctenacanth shark 6 to 9 m long, the size of a great white, 330 million years ago. Its teeth are found in the walls of Mammoth Cave, Kentucky."},
}

static func boss_info(id: String) -> Dictionary:
	return BOSSES.get(id, LAIRS.get(id, {}))

static func lair_for(sea: bool) -> String:
	return "saivodus" if sea else "megarachne"

# The mode of the run being started (set by the main menu, read by Main):
# "" a normal run, "gauntlet" the boss rush
static var mode: String = ""

static func gauntlet() -> bool:
	return mode == "gauntlet"

# DEEP TIME: saved with the other progress, only on while unlocked
static var _deep_cache: int = -1

static func deep_time() -> bool:
	if OS.get_environment("DEEP_TIME") == "1":
		return true
	if _deep_cache < 0:
		var config = ConfigFile.new()
		config.load(PROGRESS.SAVE_PATH)
		_deep_cache = 1 if bool(config.get_value("endgame", "deep_time", false)) and is_unlocked("deep_time") else 0
	return _deep_cache == 1

static func set_deep_time(on: bool):
	var config = ConfigFile.new()
	config.load(PROGRESS.SAVE_PATH)
	config.set_value("endgame", "deep_time", on)
	config.save(PROGRESS.SAVE_PATH)
	_deep_cache = -1

# DEEP TIME knobs (data/Difficulty.gd reads them)
const DEEP_ENEMY_HEALTH := 1.3
const DEEP_BOSS_HEALTH := 1.3
const DEEP_EXTRA_ANIMALS := 1
const DEEP_BOSS_REST := 1.25

# The finale bosses, for the menu pictures and the fossil record
const BOSSES = {
	"inostrancevia": {"name": "Inostrancevia", "world": "land", "script": "res://bosses/Inostrancevia.gd",
		"fact": "The biggest gorgonopsian, about 3.5 m, with sabre canines over 12 cm long. It reached South Africa just before the Great Dying, then vanished with it."},
	"campylocephalus": {"name": "Campylocephalus", "world": "sea", "script": "res://bosses/Campylocephalus.gd",
		"fact": "A hibbertopterid sea scorpion that raked the mud with spined legs. It is the last eurypterid known: the whole group, 200 million years old, ended in the Great Dying."},
}

static func forced() -> bool:
	return OS.get_environment("ENDGAME") == "1"

static func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if e.id == id:
			return e
	return {}

# [have, need]
static func progress_of(id: String) -> Array:
	var e = entry(id)
	if e.is_empty():
		return [0, 1]
	var need = int(e.get("need", 1))
	match e.type:
		"wins":
			return [mini(need, PROGRESS.run_stats().wins), need]
		"stat":
			return [mini(need, int(PROGRESS.stats().get(e.key, 0))), need]
	return [0, need]

static func is_unlocked(id: String) -> bool:
	if forced():
		return true
	var p = progress_of(id)
	return p[0] >= p[1]

static func unlocked_count() -> int:
	var n := 0
	for e in ENTRIES:
		if is_unlocked(e.id):
			n += 1
	return n
