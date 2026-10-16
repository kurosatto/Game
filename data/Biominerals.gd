# Biominerals.gd
# What you grow instead of picking random traits. Prey is made of the
# elements it built itself from, so eating it leaves those elements behind
# (BiomassOrb.gd); you spend them to grow hard parts and body chemistry the
# way real animals do: calcium carbonate into shells and spines, calcium
# phosphate into bone, iron into magnetite teeth, zinc into hardened jaws,
# sulfur into keratin horn and claws, copper into blue blood and pigment.
# What you hunt decides what you can build, and you choose when and what.
# Each recipe is an adaptation too: Player.grant_adaptation(id) applies its
# "mods" (see data/Adaptations.gd for the keys) and it shows on the pause
# screen. "icon" names an assets/ui/icons/adapt_<icon>.png.
extends RefCounted

const ELEMENTS = {
	"Ca": {"name": "Calcium", "color": Color(0.93, 0.9, 0.78),
		"fact": "Shells, spines, coral and trilobite eyes are calcium carbonate; bone and teeth are calcium phosphate."},
	"P": {"name": "Phosphorus", "color": Color(1.0, 0.62, 0.35),
		"fact": "Phosphate is the backbone of DNA, the energy in ATP, and the mineral of bone."},
	"Fe": {"name": "Iron", "color": Color(0.9, 0.36, 0.3),
		"fact": "Iron carries oxygen in haemoglobin and moves electrons in every mitochondrion."},
	"Zn": {"name": "Zinc", "color": Color(0.62, 0.78, 0.95),
		"fact": "Zinc hardens the jaws of ragworms and the stings, fangs and mandibles of many arthropods."},
	"Cu": {"name": "Copper", "color": Color(0.35, 0.85, 0.78),
		"fact": "Copper carries oxygen in the blue blood of molluscs and arthropods."},
	"S": {"name": "Sulfur", "color": Color(1.0, 0.9, 0.35),
		"fact": "Sulfur bridges lock keratin and venom proteins into tough, stable shapes."},
}
const ORDER = ["Ca", "P", "Fe", "Zn", "Cu", "S"]

# What each animal leaves behind, by what its body was built from
const FAUNA = {
	"Spriggina": ["P", "S"], "Kimberella": ["Fe", "S"], "Dickinsonia": ["P", "Fe"], "Fractofusus": ["P"],
	"Opabinia": ["Cu", "S"], "Olenoides": ["Ca", "Cu"], "Wiwaxia": ["S", "Fe"], "Marrella": ["Cu", "S"],
	"Sacabambaspis": ["P", "Fe"], "Megalograptus": ["Zn", "Cu"], "Orthoceras": ["Ca", "Cu"], "Isotelus": ["Ca"],
	"Meganeura": ["Zn", "Cu"], "Pulmonoscorpius": ["Zn", "Cu"], "Archimylacris": ["S", "Cu"], "Helenodora": ["S", "Cu"],
	"Lystrosaurus": ["P", "Ca"], "Inostrancevia": ["Fe", "P"], "Diictodon": ["Ca", "P"], "Euchambersia": ["S", "P"],
}
# A boss is a feast of everything it was made of
const BOSSES = {1: ["P", "S"], 2: ["Cu", "S", "Zn"], 3: ["Ca", "Cu", "Fe"], 4: ["Ca", "Cu", "Zn"], 5: ["P", "Fe", "Ca"]}
# Elements eaten per point of a kill's worth
const YIELD := 0.1
const BOSS_YIELD := 2.5

const RECIPES = [
	{"id": "calcite_spines", "name": "Calcite Spines", "cost": {"Ca": 4}, "icon": "thorns",
		"fact": "Each sea urchin spine is a single crystal of calcite, grown from calcium carbonate drawn out of seawater.",
		"effect": "Enemies touching you are pricked twice a second", "mods": {"thorns": 1.0}},
	{"id": "shell_plates", "name": "Aragonite Shell Plates", "cost": {"Ca": 6}, "icon": "armour", "once": true,
		"fact": "Molluscs lay down shell as layers of aragonite, a form of calcium carbonate, bound in protein.",
		"effect": "Big hits do 1 less damage", "mods": {"armour": 1}},
	{"id": "calcite_lenses", "name": "Calcite Eye Lenses", "cost": {"Ca": 3, "P": 1}, "icon": "senses",
		"fact": "Trilobites saw through lenses of clear calcite crystal, the only animals known to use rock for eyes.",
		"effect": "+1 vision, +1 to your best other sense", "mods": {"vision": 1, "sense": 1}},
	{"id": "bone", "name": "Bone", "cost": {"P": 4, "Ca": 3}, "icon": "body_wall",
		"fact": "Bone is hydroxyapatite, a calcium phosphate, threaded with collagen; it first armoured jawless fish.",
		"effect": "+1 heart, healed now", "mods": {"hp": 2}},
	{"id": "phosphagen", "name": "Phosphagen Stores", "cost": {"P": 3}, "icon": "fast_twitch",
		"fact": "Phosphocreatine, or phosphoarginine in invertebrates, refills ATP instantly for a burst of speed.",
		"effect": "Dash or escape recharges 20% faster", "mods": {"dash_cd": 0.2}},
	{"id": "regeneration", "name": "Stem-Cell Regrowth", "cost": {"P": 5}, "icon": "regeneration",
		"fact": "Regrowing lost tissue means copying DNA again and again, and every rung of DNA hangs on phosphate.",
		"effect": "Heal half a heart each room you clear", "mods": {"regen": 1}},
	{"id": "electric_organ", "name": "Electric Organ", "cost": {"P": 3, "Cu": 2}, "icon": "electrocytes",
		"fact": "Electrocytes spend ATP pumping ions, then discharge together like a stack of batteries.",
		"effect": "ZAP hits 40% harder and stuns longer", "mods": {"zap_power": 0.4}},
	{"id": "haemoglobin", "name": "Haemoglobin", "cost": {"Fe": 4}, "icon": "myoglobin",
		"fact": "Each haemoglobin carries four iron atoms that each hold an oxygen molecule; it is why blood is red.",
		"effect": "+10% move speed", "mods": {"speed": 0.1}},
	{"id": "iron_sulfur", "name": "Iron-Sulfur Mitochondria", "cost": {"Fe": 2, "S": 2}, "icon": "mitochondria",
		"fact": "Mitochondria pass electrons along clusters of iron and sulfur atoms to make the ATP that powers muscle.",
		"effect": "Attack 12% faster", "mods": {"fire": 0.12}},
	{"id": "magnetite_teeth", "name": "Magnetite-Capped Teeth", "cost": {"Fe": 5}, "icon": "serrated",
		"fact": "Chitons cap their rasping teeth with magnetite, an iron oxide and the hardest mineral any animal makes.",
		"effect": "15% of hits do double damage", "mods": {"crit": 0.15}},
	{"id": "zinc_jaws", "name": "Zinc-Hardened Jaws", "cost": {"Zn": 4}, "icon": "muscle",
		"fact": "Ragworm jaws and spider fangs are laced with zinc, making their tips far harder than plain cuticle.",
		"effect": "+20% damage", "mods": {"damage": 0.2}},
	{"id": "zinc_venom", "name": "Zinc Venom Enzymes", "cost": {"Zn": 2, "S": 3}, "icon": "toxins", "once": true,
		"fact": "Many venoms digest from the inside with zinc-powered enzymes, held in shape by sulfur bridges.",
		"effect": "Attacks poison what they hit", "mods": {"perk": "caustic"}},
	{"id": "hemocyanin", "name": "Hemocyanin Blood", "cost": {"Cu": 4}, "icon": "myoglobin",
		"fact": "Octopuses, crabs and horseshoe crabs carry oxygen on copper instead of iron, so their blood is blue.",
		"effect": "+10% move speed", "mods": {"speed": 0.1}},
	{"id": "melanin", "name": "Melanin Camouflage", "cost": {"Cu": 3}, "icon": "camouflage",
		"fact": "Tyrosinase, the copper enzyme that makes melanin, colours the ink of squid and the mottling of fish.",
		"effect": "Animals notice you 20% closer", "mods": {"stealth": 0.2}},
	{"id": "keratin_claws", "name": "Keratin Claws", "cost": {"S": 3}, "icon": "reach",
		"fact": "Claws and nails are keratin, a protein locked tough by sulfur bridges between its chains.",
		"effect": "+15% attack range", "mods": {"range": 0.15}},
	{"id": "keratin_horn", "name": "Keratin Horn", "cost": {"S": 5}, "icon": "mass",
		"fact": "Horn sheaths are dense keratin; the more sulfur bridges, the harder the horn.",
		"effect": "Hits knock enemies back", "mods": {"knockback": 260.0}},
]

static func get_recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}

static func fauna_elements(fauna_name: String) -> Array:
	return FAUNA.get(fauna_name, ["P"])

# Costs are scaled so a run grows about ten parts; each time you grow the
# same part again it costs 60% more
const COST_SCALE := 1.5
static func cost_of(r: Dictionary, times_taken: int) -> Dictionary:
	var c := {}
	for el in r.cost:
		c[el] = int(ceil(r.cost[el] * COST_SCALE * (1.0 + 0.6 * times_taken)))
	return c

static func can_grow(r: Dictionary, have: Dictionary, taken: Dictionary) -> bool:
	var n = taken.get(r.id, 0)
	if r.get("once", false) and n > 0:
		return false
	var c = cost_of(r, n)
	for el in c:
		if int(have.get(el, 0.0)) < c[el]:
			return false
	return true

static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for el in ORDER:
		if cost.has(el):
			parts.append("%d %s" % [cost[el], el])
	return "  ".join(parts)
