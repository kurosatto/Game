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
]

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
