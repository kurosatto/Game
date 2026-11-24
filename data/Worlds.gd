# Worlds.gd
# Sea and land. The first three eras are all sea: there were no animals on
# land yet. From the Carboniferous (floor 4) on, each floor comes in two
# worlds with their own scenery, animals and bosses:
#   land  the coal-swamp forests and Permian red beds (eras 4 and 5)
#   sea   the Carboniferous seas of the Bear Gulch bay and the Permian reef
#         seas where Helicoprion hunted (eras 6 and 7)
# Which one you get follows the form you are: land animals go to land, sea
# animals to sea. Amphibious forms (lobe-finned shorewalkers and amphibians)
# get two trapdoors after the boss and pick (Room.spawn_trapdoor).
#
# "Era" here is the key every per-era table uses (Fauna, EraLook, the boss
# lists, special rooms...): 1-5 as before, 6 the Carboniferous seas and 7 the
# Permian seas. era() is safe to call on an era that is already converted.
extends RefCounted

const SPLIT_FLOOR := 4
const SEA_ERAS := {4: 6, 5: 7}
# Fossil record and codex order: each land era next to its sea
const ERA_ORDER := [1, 2, 3, 4, 6, 5, 7]

# The world of the floor being played. Main sets it whenever a floor is
# made; the main menu resets it so its lists start from the land eras.
static var sea: bool = false

const LAND_FORMS := ["arachnid", "myriapod", "hexapod", "scorpion", "spider", "centipede",
	"millipede", "dragonfly_line", "beetle", "synapsid", "sauropsid", "land_snail"]
# Breathe air and water both: they choose their world at the trapdoor
const SHORE_FORMS := ["lobe_finned_shorewalker", "lissamphibian"]

static func habitat(form_id: String) -> String:
	if form_id in LAND_FORMS:
		return "land"
	if form_id in SHORE_FORMS:
		return "shore"
	return "sea"

static func splits(floor_num: int) -> bool:
	return floor_num >= SPLIT_FLOOR

static func era(f: int) -> int:
	if f > 5:
		return f
	f = clampi(f, 1, 5)
	return SEA_ERAS[f] if f >= SPLIT_FLOOR and sea else f

# The floor (1-5) an era is played on
static func floor_of(e: int) -> int:
	for f in SEA_ERAS:
		if SEA_ERAS[f] == e:
			return f
	return clampi(e, 1, 5)

static func is_sea_era(e: int) -> bool:
	return e <= 3 or e >= 6

static func is_land(f: int) -> bool:
	return not is_sea_era(era(f))

# Which world a floor will be for this form. A shore form takes the world
# of the trapdoor it chose ("sea" / "land"), or stays in the water.
static func sea_for(floor_num: int, form_id: String, pick: String = "") -> bool:
	if not splits(floor_num):
		return true
	match habitat(form_id):
		"land": return false
		"shore": return pick != "land"
	return true

# Tests and screenshots can force a world: WORLD=sea or WORLD=land
static func forced() -> String:
	return OS.get_environment("WORLD")
