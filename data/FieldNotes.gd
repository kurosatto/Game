# FieldNotes.gd
# Two small goals per era, the same every run, written like a naturalist's
# to-do list for the trip: catch the era's odd animal, find its seep, eat an
# elder... Each one done pays out a handful of the era's elements for the
# GROW screen and a heart. Main.gd counts progress (field_event); the floor
# banner and the pause screen list them.
#   event: what Main.field_event() is called with
#     "eat:<species>"  an animal of that species eaten (Enemy.die)
#     "elder"          an elder eaten
#     "nohit"          a fight room cleared without being hurt (Room.clear_room)
#     "seep"           the era's seep or lick used (MineralSeep.use)
#     "wave"           a room's second wave beaten (Room.clear_room)
#     "fumarole"       an animal caught by a fumarole's burst (Hazard.burst)
extends RefCounted

const NOTES = {
	1: [
		{"event": "eat:Fractofusus", "need": 4, "text": "Graze 4 Fractofusus fronds",
			"fact": "Rangeomorphs like Fractofusus had no mouth or gut; they probably soaked food straight from the water."},
		{"event": "nohit", "need": 1, "text": "Clear a room without being hurt",
			"fact": "The Ediacaran was quiet: few animals had yet evolved to hunt others."},
	],
	2: [
		{"event": "eat:Marrella", "need": 1, "text": "Catch a Marrella",
			"fact": "Over 25,000 Marrella have been found in the Burgess Shale, more than any other animal there."},
		{"event": "elder", "need": 1, "text": "Eat an elder (an animal circled in ink)",
			"fact": "Cambrian animals grew all their lives, so the oldest were the biggest."},
	],
	3: [
		{"event": "eat:Isotelus", "need": 2, "text": "Eat 2 Isotelus",
			"fact": "Isotelus rex, the biggest trilobite ever found, was over 70 cm long."},
		{"event": "seep", "need": 1, "text": "Find the cold seep",
			"fact": "Fossil seep communities from the Ordovician already held brachiopods and snails living off the leaking fluid."},
	],
	4: [
		{"event": "eat:Archimylacris", "need": 6, "text": "Eat 6 Archimylacris",
			"fact": "Roachoids were so common in coal-swamp rocks that the Carboniferous is sometimes called the Age of Cockroaches."},
		{"event": "wave", "need": 1, "text": "Hold out against a second wave",
			"fact": "Carboniferous air held about 35% oxygen, which let arthropods grow huge."},
	],
	5: [
		{"event": "eat:Diictodon", "need": 2, "text": "Dig out 2 Diictodon",
			"fact": "Diictodon burrows are corkscrews up to half a metre deep; whole families are found inside."},
		{"event": "fumarole", "need": 1, "text": "Lure an animal onto a fumarole",
			"fact": "Gas from the Siberian Traps warmed the world and acidified the seas, killing most species alive."},
	],
}

const REWARD_UNITS := 4.0 # GROW units handed out, split over two elements
const REWARD_ORBS := 6
const REWARD_HEAL := 1

static func for_floor(f: int) -> Array:
	return NOTES.get(clampi(f, 1, 5), [])

# One line per note: "✓ Catch a Marrella", "– Eat 2 Isotelus (1/2)"
static func describe(f: int, progress: Dictionary, sep: String = "\n") -> String:
	var lines: Array = []
	for i in for_floor(f).size():
		var n = for_floor(f)[i]
		var got = int(progress.get(i, 0))
		if got >= n.need:
			lines.append("✓ " + n.text)
		elif n.need > 1:
			lines.append("– %s (%d/%d)" % [n.text, got, n.need])
		else:
			lines.append("– " + n.text)
	return sep.join(lines)
