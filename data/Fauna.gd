# Fauna.gd
# Era-accurate names for each floor's regular enemies. The two AI behaviours
# stay the same ("fly" chases, "pacer" wanders and shoots); each floor dresses
# them as animals that really lived in that era. Extinct animals are fine here.
# Each era also has a third animal with its own behaviour, keyed by type:
# "tank" (slow, huge, shrugs off knockback), "armoured" (shielded front, hit
# it from the side), "charger" (jets in a straight line, dazed by walls),
# "swarm" (a pack of small fast insects that scatter when hit), "burrower"
# (digs under, can't be hit, bursts up beside you).
# And a fourth: "colony" (rooted, harmless, sprouts new fronds until
# cleared), "skittish" (harmless, flees, a big meal if caught), "enroll"
# (rolls into an untouchable ball when hit), "snarer" (squirts slime that
# slows you), "orbiter" (circles, then darts in for a venomous bite).
# Optional "behavior": "weave" (S-curve swimmer/flier), "burst" (sprint and
# pause), "lunge" (ambush predator: winds up, then dashes). "shoot_delay"
# scales the time between shots.
# Personality: "temper" says when an animal stops minding its own business
# and fights (see TEMPERS), "idle" what it does until then (Enemy.process_idle):
# "graze" (crawl, stop and feed), "rest" (lies still, breathing), "drift"
# (slow wandering swim), "patrol" (loops around its patch), "school" (keeps
# with its kind), "forage" (skitters about in short runs), "ambush" (lies
# low and still), "dig" (scrapes at the ground), "stalk" (creeps after you).
extends RefCounted

const FLOORS = {
	1: {
		"fly": {"name": "Spriggina", "temper": "wary", "idle": "drift", "fact": "A segmented Ediacaran animal; its head end suggests it could move with purpose.", "tint": Color(1.0, 0.85, 0.75), "scale": 0.9, "speed": 0.9, "behavior": "burst"},
		"pacer": {"name": "Kimberella", "temper": "docile", "idle": "graze", "fact": "An Ediacaran slug-like grazer that left scratch marks as it fed on microbial mats.", "tint": Color(0.85, 0.95, 0.8), "scale": 1.0, "speed": 0.85, "shoot_delay": 1.4},
		"tank": {"name": "Dickinsonia", "temper": "docile", "idle": "rest", "fact": "A flat, quilted Ediacaran animal up to a metre long; cholesterol traces in its fossils prove it was an animal.", "tip": "Slow and huge, it barely flinches.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
		"colony": {"name": "Fractofusus", "fact": "A spindle-shaped rangeomorph of fractal fronds lying on the Ediacaran sea floor. Fossil beds show it spread by runners, like strawberry plants.", "tip": "Rooted and harmless, but it keeps sprouting new fronds until you clear it.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
	},
	2: {
		"fly": {"name": "Opabinia", "temper": "territorial", "idle": "patrol", "fact": "A Cambrian swimmer with five eyes and a grasping nozzle.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0, "behavior": "weave"},
		"pacer": {"name": "Olenoides", "temper": "wary", "idle": "graze", "fact": "A spiny Cambrian trilobite from the Burgess Shale, preserved with its legs and antennae.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
		"armoured": {"name": "Wiwaxia", "temper": "docile", "idle": "graze", "fact": "A Cambrian mollusc relative covered in overlapping scales with two rows of spines.", "tip": "Its armour faces you: hit it from the side or behind.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
		"skittish": {"name": "Marrella", "fact": "The most common animal in the Burgess Shale: a small 'lace crab' arthropod with two pairs of long, swept-back head spines.", "tip": "Harmless and quick. It flees, but one caught is a big meal.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
	},
	3: {
		"fly": {"name": "Sacabambaspis", "temper": "timid", "idle": "school", "fact": "An Ordovician jawless fish with eyes at the very front of its armoured head.", "tint": Color(0.75, 0.9, 1.0), "scale": 1.05, "speed": 1.05, "behavior": "weave"},
		"pacer": {"name": "Megalograptus", "temper": "predator", "idle": "ambush", "fact": "An Ordovician sea scorpion (eurypterid) with spiny grasping limbs.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.15, "speed": 1.0, "behavior": "lunge", "shoot_delay": 1.6},
		"charger": {"name": "Orthoceras", "temper": "territorial", "idle": "drift", "fact": "An Ordovician straight-shelled nautiloid that, like squid today, jetted backwards by squirting water.", "tip": "It charges shell-first in a straight line and is dazed when it hits a wall.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
		"enroll": {"name": "Isotelus", "temper": "docile", "idle": "graze", "fact": "A giant Ordovician trilobite, up to 70 cm long. Like many trilobites it could roll up into an armoured ball.", "tip": "Hit it and it rolls up, untouchable for a moment; strike again once it uncurls.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
	},
	4: {
		"fly": {"name": "Meganeura", "temper": "predator", "idle": "patrol", "fact": "A Carboniferous griffinfly with a wingspan of about 70 cm.", "tint": Color(0.7, 1.0, 0.85), "scale": 1.15, "speed": 1.2, "behavior": "weave"},
		"pacer": {"name": "Pulmonoscorpius", "temper": "territorial", "idle": "ambush", "fact": "A Carboniferous land scorpion about 70 cm long.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.2, "speed": 1.05, "behavior": "lunge", "shoot_delay": 1.6},
		"swarm": {"name": "Archimylacris", "temper": "timid", "idle": "forage", "fact": "A Carboniferous roachoid, one of the cockroach-like insects that crowded the coal-swamp floor.", "tip": "They come in packs and scatter when one is hit.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
		"snarer": {"name": "Helenodora", "temper": "wary", "idle": "ambush", "fact": "A Carboniferous velvet worm from the Mazon Creek fossil beds. Living velvet worms squirt jets of sticky slime to snare their prey.", "tip": "Its slime glues you down for a moment; dash through it or keep moving.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
	},
	5: {
		"fly": {"name": "Lystrosaurus", "temper": "docile", "idle": "graze", "fact": "A tusked synapsid that survived the end-Permian extinction and spread across the Early Triassic world.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.2, "speed": 1.1, "behavior": "burst"},
		"pacer": {"name": "Inostrancevia", "temper": "predator", "idle": "stalk", "fact": "A sabre-toothed gorgonopsian, one of the last top predators before the end-Permian extinction.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.3, "speed": 1.1, "behavior": "lunge", "shoot_delay": 2.0},
		"burrower": {"name": "Diictodon", "temper": "wary", "idle": "dig", "fact": "A small Permian dicynodont that dug corkscrew burrows; some were fossilised curled up inside them.", "tip": "It digs under where it can't be hit, then bursts up beside you. Watch for the dust.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
		"orbiter": {"name": "Euchambersia", "temper": "predator", "idle": "stalk", "fact": "A Late Permian therocephalian with a pit beside each canine that may have held a venom gland, which would make it the oldest venomous relative of mammals.", "tip": "It circles you, then darts in to bite. The venom slows you.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
	},
}

# aggro: how close you can get before it notices you. calm: how far you must
# get before it loses interest (predators never do). Timid animals back off
# when you come near and only fight once hurt; docile ones only when hurt or
# bumped. Every animal alarms its own kind nearby when it is attacked.
const TEMPERS = {
	"docile": {"aggro": 110.0, "calm": 380.0, "notice": 0.5},
	"timid": {"aggro": 260.0, "calm": 420.0, "notice": 0.3},
	"wary": {"aggro": 270.0, "calm": 520.0, "notice": 0.45},
	"territorial": {"aggro": 340.0, "calm": 560.0, "notice": 0.35},
	"predator": {"aggro": 470.0, "calm": -1.0, "notice": 0.25},
}

static func get_fauna(floor_num: int, enemy_type: String) -> Dictionary:
	var f = FLOORS.get(clampi(floor_num, 1, 5), {})
	return f.get(enemy_type, {})

const SPECIAL_TYPES = ["tank", "armoured", "charger", "swarm", "burrower", "colony", "skittish", "enroll", "snarer", "orbiter"]

# The era's third animal type ("tank", "swarm"...), or "" if none
static func special_type(floor_num: int) -> String:
	var all = special_types(floor_num)
	return all[0] if not all.is_empty() else ""

# Every special animal type of the era, third animal first
static func special_types(floor_num: int) -> Array:
	var f = FLOORS.get(clampi(floor_num, 1, 5), {})
	return SPECIAL_TYPES.filter(func(t): return f.has(t))

# short: special animals get only their tip (the floor banner); the pause
# screen shows everything
static func describe_floor(floor_num: int, short: bool = false) -> String:
	var f = FLOORS.get(clampi(floor_num, 1, 5), {})
	if f.is_empty():
		return ""
	var text = "%s: %s\n%s: %s" % [f.fly.name, f.fly.fact, f.pacer.name, f.pacer.fact]
	for t in special_types(floor_num):
		if short:
			text += "\n%s: %s" % [f[t].name, f[t].tip]
		else:
			text += "\n%s: %s %s" % [f[t].name, f[t].fact, f[t].tip]
	return text
