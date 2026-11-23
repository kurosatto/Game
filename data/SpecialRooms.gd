# SpecialRooms.gd
# Ten kinds of side room, beside the fights, the treasure room and the
# mineral seep. LevelGenerator.gd deals a few per floor from the kinds that
# fit the era (a room keeps RoomType.NORMAL and gets room_data.special), and
# rooms/SpecialRoom.gd runs them. Everything here is plausible for its era:
# the animals are the era's own (data/Fauna.gd), the events are real ones.
# Only the GROW screen gives upgrades: these rooms pay out in elements,
# hearts and help, never in random traits.
extends RefCounted

const FAUNA = preload("res://data/Fauna.gd")
const BIOMINERALS = preload("res://data/Biominerals.gd")
const INK = Color(0.24, 0.15, 0.08)
const PAPER = Color(0.95, 0.9, 0.78)

const KINDS = ["vent", "tar", "dig", "frenzy", "extinction", "nest", "tide", "symbiont", "ambush", "glow", "dark"]

# Which eras each kind can turn up in. No brood care, hunters lying in wait
# or animal sidekicks before the Cambrian; no glowing animals known on land
# before the Mesozoic, so the glow cave is a sea cave.
const ERAS = {
	"vent": [1, 2, 3, 4, 5], "tar": [1, 2, 3, 4, 5], "dig": [1, 2, 3, 4, 5],
	"frenzy": [1, 2, 3, 4, 5], "extinction": [1, 2, 3, 4, 5], "tide": [1, 2, 3, 4, 5],
	"nest": [2, 3, 4, 5], "symbiont": [2, 3, 4, 5], "ambush": [2, 3, 4, 5], "glow": [2, 3],
	"dark": [1, 2, 3, 4, 5],
}

# Rooms with nothing to fight when you walk in: open doors, open ground
const PEACEFUL = ["vent", "dig", "extinction", "nest", "symbiont", "ambush"]

static func kinds_for(f: int) -> Array:
	return KINDS.filter(func(k): return f in ERAS[k])

# One pitch-dark room on every floor, on top of these (LevelGenerator.gd),
# so the senses always get a room where they are the only way to hunt
static func count_for(f: int) -> int:
	return 2 if f <= 2 else 3

# Rooms with no light at all: the senses (SenseHints.gd) find the animals
static func is_dark(kind: String) -> bool:
	return kind == "dark"

static func is_land(f: int) -> bool:
	return f >= 4

# ---- Names and facts, per era where it matters ----
static func title(kind: String, f: int) -> String:
	match kind:
		"vent": return "HOT SPRING" if is_land(f) else "HYDROTHERMAL VENT"
		"tar": return ["SOFT SILT", "MUD FLOW", "SOFT MUD", "SWAMP MUD", "TAR SEEP"][clampi(f - 1, 0, 4)]
		"dig": return "FOSSIL BED"
		"frenzy": return "FEEDING FRENZY"
		"extinction": return EXTINCTIONS[clampi(f, 1, 5)].title
		"nest": return NESTS[clampi(f, 2, 5)].title
		"tide": return "TIDAL CHANNEL"
		"symbiont": return "A FOLLOWER"
		"ambush": return "QUIET ROOM"
		"glow": return "GLOWING CAVE"
		"dark": return "NIGHT" if is_land(f) else "THE DEEP"
	return kind.to_upper()

static func fact(kind: String, f: int) -> String:
	match kind:
		"vent":
			if is_land(f):
				return "Hot springs bubble up where groundwater meets hot rock; their warm, mineral water is full of life."
			return "Black smokers pour out hot water full of iron and sulfur. Whole communities live on the chemicals, with no sunlight at all."
		"tar":
			return [
				"Ediacaran animals were smothered by sudden falls of silt; that is how their soft bodies were preserved.",
				"The Burgess Shale animals were buried alive by underwater mudflows, which kept even their guts and legs.",
				"Soft seafloor mud could trap a slow animal; trilobites are often found where they sank.",
				"Coal-swamp mud was so airless that whole animals sank in and fossilised, as at Mazon Creek.",
				"Sticky tar seeps, where oil reaches the surface, have trapped animals for millions of years."][clampi(f - 1, 0, 4)]
		"dig":
			return "Rock here is older than the animals around you. Break it open to see what lived before them."
		"frenzy":
			return FRENZY[clampi(f, 1, 5)].fact
		"extinction":
			return EXTINCTIONS[clampi(f, 1, 5)].fact
		"nest":
			return NESTS[clampi(f, 2, 5)].fact
		"tide":
			return "Half a billion years ago the Moon was closer and a day lasted about 21 hours, so the tides ran higher than they do today."
		"symbiont":
			return "Many animals follow a hunter to snatch the prey it flushes out, the way cattle egrets follow grazing cows and pilot fish swim with sharks."
		"ambush":
			return "Ambush hunters lie still and wait. A quiet room is not always an empty one."
		"glow":
			if f <= 2:
				return "Sea pens and other soft corals have glowed for at least 540 million years. They flash when something brushes past."
			return "Comb jellies and sea pens light up the dark when they are disturbed. Use their glow to see."
		"dark":
			return [
				"The oldest Ediacaran animals, at Mistaken Point, lived on the deep seafloor where no sunlight reached.",
				"Cambrian arthropods already had antennae and sensory hairs to feel their way through dark, muddy water.",
				"Below about 200 m the sea is black. Fish feel moving water with their lateral line and find prey unseen.",
				"Spiders and scorpions hunt at night by feeling footsteps through the ground, as they did in the coal swamps.",
				"Many animals hunt at night by smell, touch and sound, when the day's hunters can't see them."][clampi(f - 1, 0, 4)]
	return ""

# What to do, in one short line
static func how(kind: String, f: int) -> String:
	match kind:
		"vent": return "Rest in the warm ring to heal. Too close and it scalds."
		"tar": return "The mud slows everything. Stand by the trapped animal to pull it free."
		"dig": return "Attack the rock to break it open."
		"frenzy": return "A swarm of small prey. Eat them before they scatter!"
		"extinction": return "Grab the elements and get out before the room turns deadly."
		"nest": return "Take the %s for a big meal, then deal with the parent." % NESTS[clampi(f, 2, 5)].label.to_lower()
		"tide": return "The tide comes in and splits the room. Cross at low tide."
		"symbiont": return "Touch it and it hunts beside you for the rest of this era."
		"ambush": return ""
		"glow": return "It's dark. Glowing animals light the way."
		"dark": return "Pitch dark. Hunt with your senses."
	return ""

# ---- Per-kind details ----
# The trapped animal in the mud: a slow, harmless grazer of the era
const TRAPPED = {1: "Kimberella", 2: "Olenoides", 3: "Isotelus", 4: "Euphoberia", 5: "Lystrosaurus"}

# Small prey that comes in a crowd
const FRENZY = {
	1: {"species": "Spriggina", "count": 12, "fact": "Ediacaran seafloors could be crowded with small animals grazing the microbial mat."},
	2: {"species": "Marrella", "count": 14, "fact": "Marrella is the commonest Burgess Shale animal; thousands have been found on single beds."},
	3: {"species": "Arandaspis", "count": 12, "fact": "Early jawless fish swam in schools, like many small fish today, for safety in numbers."},
	4: {"species": "Archimylacris", "count": 14, "fact": "Roachoids swarmed over the coal-swamp floor, eating rotting plants."},
	5: {"species": "Permocupes", "count": 16, "fact": "Beetles were already boring into Permian wood in their hundreds."},
}

const EXTINCTIONS = {
	1: {"title": "OXYGEN CRASH", "tint": Color(0.18, 0.14, 0.12), "fact": "At the end of the Ediacaran much of the seafloor lost its oxygen, and most Ediacaran animals vanished."},
	2: {"title": "DEAD WATER", "tint": Color(0.2, 0.17, 0.12), "fact": "Late in the Cambrian, waves of oxygen-starved water spread over the shelves and wiped out most trilobite families, again and again."},
	3: {"title": "ICE AGE", "tint": Color(0.82, 0.9, 0.97), "fact": "The end-Ordovician ice age chilled and drained the shallow seas and killed about 85% of species, the second worst extinction ever."},
	4: {"title": "FOREST COLLAPSE", "tint": Color(0.62, 0.48, 0.3), "fact": "About 305 million years ago the climate dried and the coal-swamp rainforests broke up into patches, and much of their wildlife died out."},
	5: {"title": "THE GREAT DYING", "tint": Color(0.5, 0.42, 0.18), "fact": "The Siberian Traps eruptions heated, poisoned and acidified the world. About 90% of species died, the worst extinction in Earth's history."},
}
const EXTINCTION_TIME := 16.0

const NESTS = {
	2: {"title": "BROOD", "label": "EGGS", "parent": "Waptia", "type": "fly",
		"fact": "Some Waptia fossils carry a clutch of eggs under the shell: the oldest known parental care."},
	3: {"title": "SPAWNING GROUND", "label": "EGGS", "parent": "Megalograptus", "type": "pacer",
		"fact": "Sea scorpions gathered in shallow water to moult and mate, like their horseshoe crab relatives, which still spawn on beaches."},
	4: {"title": "SCORPION BROOD", "label": "BROOD", "parent": "Pulmonoscorpius", "type": "pacer",
		"fact": "Every scorpion mother carries her newborn brood on her back until their first moult, and defends them fiercely."},
	5: {"title": "BURROW", "label": "YOUNG", "parent": "Diictodon", "type": "burrower",
		"fact": "Diictodon dug corkscrew burrows; some fossil burrows hold adults, and some a huddle of young."},
}

const SYMBIONTS = {
	2: {"species": "Waptia", "type": "fly"},
	3: {"species": "Arandaspis", "type": "fly"},
	4: {"species": "Meganeura", "type": "fly"},
	5: {"species": "Captorhinus", "type": "fly"},
}

const AMBUSHERS = {
	2: {"species": "Sanctacaris", "type": "pacer"},
	3: {"species": "Megalograptus", "type": "pacer"},
	4: {"species": "Pulmonoscorpius", "type": "pacer"},
	5: {"species": "Inostrancevia", "type": "pacer"},
}

# What the fossil bed holds: always something older than the era you're in
const FOSSILS = {
	1: {"name": "Grypania", "shape": "coil", "fact": "Grypania, a coiled ribbon about 1.9 billion years old, may be the oldest fossil big enough to see: probably a giant alga."},
	2: {"name": "Dickinsonia", "shape": "quilt", "fact": "Dickinsonia, an Ediacaran animal that lived before you. Fat molecules kept in its fossils show it was an animal."},
	3: {"name": "Olenoides", "shape": "trilobite", "fact": "A Cambrian trilobite. Trilobites were already around 100 million years by now and lasted another 200 million."},
	4: {"name": "Graptolite", "shape": "graptolite", "fact": "Graptolites were colonies of tiny animals in a saw-toothed tube. They change so fast through time that geologists use them to date rocks."},
	5: {"name": "Lepidodendron", "shape": "bark", "fact": "Bark of Lepidodendron, a 30 m club-moss tree of the coal swamps. Its diamond leaf scars are among the commonest Carboniferous fossils."},
}

# ---- Helpers ----
static func era_elements(f: int) -> Array:
	return preload("res://MineralSeep.gd").era_elements(f)

# Something the era's animals can't give you
static func rare_element(f: int) -> String:
	var have = era_elements(f)
	for el in ["Zn", "Cu", "Fe", "S", "Ca"]:
		if not el in have:
			return el
	return "Zn"

# A burst of element orbs that fly to the player (BiomassOrb.gd)
static func spill(parent: Node, pos: Vector2, els: Array, units: float, orbs: int = 6):
	if els.is_empty():
		els = ["Ca"]
	for i in orbs:
		var orb = preload("res://BiomassOrb.gd").new()
		orb.value = units / orbs
		orb.element = els[i % els.size()]
		orb.position = pos + Vector2(randf_range(-24, 24), randf_range(-18, 18))
		parent.add_child(orb)

# A field-notebook label: ink capitals on a pale slip, big enough for a phone
static func draw_label(ci: CanvasItem, pos: Vector2, text: String, size: int = 26, alpha: float = 1.0):
	var font: Font = ThemeDB.fallback_font
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r = Rect2(pos - Vector2(w / 2.0 + 10.0, size * 0.85), Vector2(w + 20.0, size * 1.2))
	ci.draw_rect(r, Color(PAPER, 0.82 * alpha))
	ci.draw_rect(r, Color(INK, 0.7 * alpha), false, 2.0)
	ci.draw_string(font, Vector2(pos.x - w / 2.0, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, alpha))

static func species(f: int, name: String) -> Dictionary:
	return FAUNA.get_species(f, name)
