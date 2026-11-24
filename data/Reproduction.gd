# Reproduction.gd
# Laying a clutch (GROW screen, "LAY EGGS"): spend the phosphorus and sulfur
# that eggs are built from (DNA, yolk proteins) to leave young in a cleared
# room. If you die later on the same floor, one of them hatches there and the
# run goes on as your lineage, with fewer hearts. The clutch is left behind
# when you go down to the next era.
#
# How a lineage reproduces is real biology, and it is the trade-off: lineages
# that scatter many tiny eggs pay little, but the young hatch weak; lineages
# that brood, guard or shell a few big eggs pay more, but the young are strong.
extends RefCounted

const LINEAGES = preload("res://data/Lineages.gd")

# cost: elements; hatch: share of your max health the young starts with
const MODES = {
	"divide": {"name": "Split in two", "verb": "SPLIT OFF A CELL", "cost": {"P": 2}, "hatch": 0.5,
		"fact": "A single cell reproduces by dividing: copy the DNA, pinch in two. Phosphorus is the backbone of every DNA strand."},
	"broadcast": {"name": "Broadcast spawning", "verb": "SPAWN", "cost": {"P": 2}, "hatch": 0.34,
		"fact": "Sea urchins, sea stars, sea lilies and clams release clouds of eggs and sperm into the water, millions at a time, and leave them to the currents. Almost all are eaten."},
	"spawn": {"name": "Spawning", "verb": "SPAWN", "cost": {"P": 2, "S": 1}, "hatch": 0.4,
		"fact": "Most fish and amphibians shed hundreds or thousands of small eggs into the water or a simple nest. The young hatch tiny and fend for themselves."},
	"egg_mass": {"name": "Egg mass", "verb": "LAY EGGS", "cost": {"P": 2, "S": 2}, "hatch": 0.5,
		"fact": "Snails, squid and many insects glue their eggs together in jelly strings, capsules or pods stuck to rocks and plants."},
	"brood": {"name": "Brooding", "verb": "BROOD EGGS", "cost": {"P": 2, "S": 3}, "hatch": 0.67,
		"fact": "Fossils of the Cambrian arthropod Waptia carry clutches of eggs under the shell: the oldest known brood care. Crabs, lobsters and shrimp still carry their eggs under the tail."},
	"guard": {"name": "Guarding the eggs", "verb": "GUARD EGGS", "cost": {"P": 2, "S": 3}, "hatch": 0.67,
		"fact": "Fewer eggs, watched over: a female centipede curls round her eggs and licks them clean of mould until they hatch."},
	"carry": {"name": "Carrying the young", "verb": "BEAR YOUNG", "cost": {"P": 3, "S": 3}, "hatch": 0.75,
		"fact": "Scorpions give birth to live young, which climb onto their mother's back and ride there until their first molt."},
	"big_eggs": {"name": "A few big eggs", "verb": "LAY EGGS", "cost": {"P": 3, "S": 3}, "hatch": 0.75,
		"fact": "A few large, yolky eggs: the young hatch big and ready, but each one costs the parent a great deal."},
	"amniote": {"name": "Shelled amniotic egg", "verb": "LAY EGGS", "cost": {"P": 3, "Ca": 3}, "hatch": 0.75,
		"fact": "The amniotic egg carries its own pond: membranes and a calcium shell that let the embryo grow on dry land. It let the first reptiles and synapsids leave the water for good."},
}

# Each form takes the mode of the nearest ancestor (or itself) listed here
const BY_FORM = {
	"ancestral_collar_cell": "divide",
	"pikaia_chordate": "spawn",
	"early_echinoderm": "broadcast",
	"early_mollusc": "egg_mass",
	"bivalve": "broadcast",
	"nautilus": "big_eggs",
	"octopus_line": "guard",
	"early_arthropod": "brood",
	"chelicerate": "egg_mass",
	"horseshoe_crab": "spawn",
	"arachnid": "guard",
	"scorpion": "carry",
	"myriapod": "guard",
	"hexapod": "egg_mass",
	"early_shark": "big_eggs",
	"hagfish": "big_eggs",
	"synapsid": "amniote",
	"sauropsid": "amniote",
}

# A line that fits the form better than the mode's own, where there is one
const FACTS = {
	"octopus_line": "A mother octopus hangs her eggs in strings from the roof of a den and guards them without eating until they hatch; then she dies.",
	"nautilus": "A nautilus lays a few big eggs, each a few centimetres long, that take most of a year to hatch.",
	"horseshoe_crab": "Horseshoe crabs crawl up beaches on spring high tides and bury thousands of green eggs in the sand.",
	"spider": "A spider wraps her eggs in a silk sac and guards it; wolf spiders carry the sac and then the spiderlings.",
	"early_shark": "Many sharks lay a few eggs in leathery cases, the mermaid's purses washed up on beaches; others give birth to live young.",
	"hagfish": "Hagfish lay only a few large eggs, each in a tough case with hooks at both ends that tangle the eggs together.",
	"sauropsid": "Hylonomus, the oldest known reptile, laid shelled eggs on land. Turtles, lizards, crocodiles and birds still do.",
	"lissamphibian": "Frogs and salamanders lay soft eggs in water, wrapped in jelly; the young hatch as gilled tadpoles or larvae.",
	"decapod": "A female lobster carries up to 100,000 eggs glued under her tail for about a year: she is 'berried'.",
	"beetle": "Beetles lay eggs where the larvae will feed: in wood, dung, soil or seeds.",
	"dragonfly_line": "Dragonflies drop or cut their eggs into water and water plants; the nymphs hunt underwater for years.",
}

# The chain from the first cell to this form, oldest first
static func ancestry(form_id: String) -> Array:
	for path in LINEAGES.TREE:
		if LINEAGES.TREE[path].id == form_id:
			var out: Array = [LINEAGES.TREE[""].id] if LINEAGES.TREE.has("") else []
			var parts = path.split(",") if path != "" else []
			for i in range(1, parts.size() + 1):
				var key = ",".join(parts.slice(0, i))
				if LINEAGES.TREE.has(key):
					out.append(LINEAGES.TREE[key].id)
			return out
	return [form_id]

static func mode_id(form_id: String) -> String:
	var chain = ancestry(form_id)
	for i in range(chain.size() - 1, -1, -1):
		if BY_FORM.has(chain[i]):
			return BY_FORM[chain[i]]
	return "divide"

static func mode_for(form_id: String) -> Dictionary:
	var m: Dictionary = MODES[mode_id(form_id)].duplicate()
	var chain = ancestry(form_id)
	for i in range(chain.size() - 1, -1, -1):
		if FACTS.has(chain[i]):
			m.fact = FACTS[chain[i]]
			break
	return m

# Health a young one hatches with: at least one heart
static func hatch_health(form_id: String, max_health: int) -> int:
	return clampi(int(round(max_health * mode_for(form_id).hatch)), 2, max_health)
