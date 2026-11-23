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
		"fact": "Phosphate is the backbone of DNA, the energy in ATP, and the mineral of bone. It is scarce: phosphorus limits growth in most of the living world."},
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
	"Spriggina": ["P", "S"], "Kimberella": ["Fe", "S"], "Dickinsonia": ["P", "Fe"], "Fractofusus": ["P"], "Charnia": ["P", "S"],
	"Opabinia": ["Cu", "S"], "Olenoides": ["Ca", "Cu"], "Wiwaxia": ["S", "Fe"], "Marrella": ["Cu", "S"],
	"Sacabambaspis": ["P", "Fe"], "Megalograptus": ["Zn", "Cu"], "Orthoceras": ["Ca", "Cu"], "Isotelus": ["Ca"],
	"Meganeura": ["Zn", "Cu"], "Pulmonoscorpius": ["Zn", "Cu"], "Archimylacris": ["S", "Cu"], "Helenodora": ["S", "Cu"],
	"Lystrosaurus": ["P", "Ca"], "Inostrancevia": ["Fe", "P"], "Diictodon": ["Ca", "P"], "Euchambersia": ["S", "P"],
	# Extra era animals (Fauna.EXTRAS)
	"Arkarua": ["Ca", "P"], "Pikaia": ["P", "S"], "Waptia": ["Cu", "S"], "Sanctacaris": ["Zn", "Cu"],
	"Plectronoceras": ["Ca", "Cu"], "Arandaspis": ["P", "Ca"], "Lunataspis": ["Cu", "S"], "Petraster": ["Ca"],
	"Maclurites": ["Ca", "Fe"], "Arthrolycosa": ["Zn", "Cu"], "Euphoberia": ["Ca", "Cu"], "Latzelia": ["Zn", "Cu"],
	"Hylonomus": ["P", "Ca"], "Orthacanthus": ["P", "Fe"], "Captorhinus": ["P", "Ca"], "Cacops": ["P", "Ca"],
	"Permocupes": ["S", "Cu"], "Edaphosaurus": ["P", "Ca"],
}
# A boss is a feast of everything it was made of
const BOSSES = {1: ["P", "S"], 2: ["Cu", "S", "Zn"], 3: ["Ca", "Cu", "Fe"], 4: ["Ca", "Cu", "Zn"], 5: ["P", "Fe", "Ca"]}
# Elements eaten per point of a kill's worth
const YIELD := 0.1
const BOSS_YIELD := 2.5
# Phosphorus is the nutrient that runs short first in most of the living
# world, and bodies hold far less of it than calcium or sulfur, so a kill
# leaves only a little (kuro, 2026-11-23: still too much P). Applied in
# Player.add_element, so kills, seeps and every reward share it.
const SCARCE := {"P": 0.45}
static func yield_of(el: String) -> float:
	return SCARCE.get(el, 1.0)

const RECIPES = [
	{"id": "calcite_spines", "name": "Calcite Spines", "cost": {"Ca": 4}, "icon": "grow_calcite_spines",
		"fact": "Each sea urchin spine is a single crystal of calcite, grown from calcium carbonate drawn out of seawater.",
		"effect": "Enemies touching you are pricked twice a second", "mods": {"thorns": 1.0}},
	{"id": "photoreceptors", "name": "Photoreceptor Eyespots", "cost": {"P": 2}, "icon": "grow_photoreceptors",
		"fact": "Light flips an opsin, and a cascade of phosphate-charged messengers (GTP and cGMP) turns it into a nerve signal; every glimpse spends phosphate.",
		"effect": "+1 vision", "mods": {"vision": 1}},
	{"id": "calcite_lenses", "name": "Calcite Eye Lenses", "cost": {"Ca": 2}, "icon": "grow_calcite_lenses",
		"fact": "Trilobites saw through lenses of clear calcite crystal; chitons and brittle stars still see through mineral lenses today.",
		"effect": "+1 vision, +1 to your best other sense", "mods": {"vision": 1, "sense": 1}},
	{"id": "bone", "name": "Bone", "cost": {"P": 4, "Ca": 2}, "icon": "grow_bone",
		"fact": "Bone is hydroxyapatite, a calcium phosphate, threaded with collagen; it first armoured jawless fish.",
		"effect": "+1 heart, healed now", "mods": {"hp": 2}},
	{"id": "membrane_repair", "name": "Membrane Repair", "cost": {"P": 2}, "icon": "grow_membrane_repair", "heal": 2,
		"fact": "Every cell membrane is a double layer of phospholipids, each with a phosphate head; torn membrane is patched by making more.",
		"effect": "Heal 1 heart now (same price every time)"},
	{"id": "phosphagen", "name": "Phosphagen Stores", "cost": {"P": 3}, "icon": "grow_phosphagen",
		"fact": "Phosphocreatine, or phosphoarginine in invertebrates, refills ATP instantly for a burst of speed.",
		"effect": "Dash or escape recharges 20% faster", "mods": {"dash_cd": 0.2}},
	{"id": "regeneration", "name": "Stem-Cell Regrowth", "cost": {"P": 5}, "icon": "grow_regeneration",
		"fact": "Regrowing lost tissue means copying DNA again and again, and every rung of DNA hangs on phosphate.",
		"effect": "Heal half a heart each room you clear", "mods": {"regen": 1}},
	{"id": "electric_organ", "name": "Electric Organ", "cost": {"P": 3, "Cu": 2}, "icon": "grow_electric_organ",
		"fact": "Electrocytes spend ATP pumping ions, then discharge together like a stack of batteries.",
		"effect": "ZAP hits 40% harder and stuns longer", "mods": {"zap_power": 0.4}},
	{"id": "haemoglobin", "name": "Haemoglobin", "cost": {"Fe": 4}, "icon": "grow_haemoglobin",
		"fact": "Each haemoglobin carries four iron atoms that each hold an oxygen molecule; it is why blood is red.",
		"effect": "+10% move speed", "mods": {"speed": 0.1}},
	{"id": "iron_sulfur", "name": "Iron-Sulfur Mitochondria", "cost": {"Fe": 2, "S": 2}, "icon": "grow_iron_sulfur",
		"fact": "Mitochondria pass electrons along clusters of iron and sulfur atoms to make the ATP that powers muscle.",
		"effect": "Attack 12% faster", "mods": {"fire": 0.12}},
	{"id": "magnetite_teeth", "name": "Magnetite-Capped Teeth", "cost": {"Fe": 5}, "icon": "grow_magnetite_teeth",
		"fact": "Chitons cap their rasping teeth with magnetite, an iron oxide and the hardest mineral any animal makes.",
		"effect": "15% of hits do double damage", "mods": {"crit": 0.15}},
	{"id": "zinc_jaws", "name": "Zinc-Hardened Jaws", "cost": {"Zn": 4}, "icon": "grow_zinc_jaws",
		"fact": "Ragworm jaws and spider fangs are laced with zinc, making their tips far harder than plain cuticle.",
		"effect": "+20% damage", "mods": {"damage": 0.2}},
	{"id": "zinc_venom", "name": "Zinc Venom Enzymes", "cost": {"Zn": 2, "S": 3}, "icon": "grow_zinc_venom", "once": true,
		"fact": "Many venoms digest from the inside with zinc-powered enzymes, held in shape by sulfur bridges.",
		"effect": "Attacks poison what they hit", "mods": {"perk": "caustic"}},
	{"id": "hemocyanin", "name": "Hemocyanin Blood", "cost": {"Cu": 4}, "icon": "grow_hemocyanin",
		"fact": "Octopuses, crabs and horseshoe crabs carry oxygen on copper instead of iron, so their blood is blue.",
		"effect": "+10% move speed", "mods": {"speed": 0.1}},
	{"id": "keratin_claws", "name": "Keratin Claws", "cost": {"S": 3}, "icon": "grow_keratin_claws",
		"fact": "Claws and nails are keratin, a protein locked tough by sulfur bridges between its chains.",
		"effect": "+15% attack range", "mods": {"range": 0.15}},
	{"id": "keratin_horn", "name": "Keratin Horn", "cost": {"S": 5}, "icon": "grow_keratin_horn",
		"fact": "Horn sheaths are dense keratin; the more sulfur bridges, the harder the horn.",
		"effect": "Hits knock enemies back", "mods": {"knockback": 260.0}},
	{"id": "calcium_signalling", "name": "Calcium Signalling", "cost": {"Ca": 3}, "icon": "grow_calcium_signalling",
		"fact": "A rush of calcium ions into a cell is the trigger that fires nerves, muscles and electric organs alike.",
		"effect": "ZAP recharges 20% faster, reaches 10% farther", "mods": {"zap_cd": 0.2, "zap_radius": 0.1}},
	{"id": "zinc_enzymes", "name": "Zinc Digestive Enzymes", "cost": {"Zn": 3}, "icon": "grow_zinc_enzymes",
		"fact": "Carboxypeptidase and many other gut enzymes hold a zinc atom that splits protein chains apart.",
		"effect": "+25% elements from prey", "mods": {"biomass": 0.25}},
	{"id": "copper_myelin", "name": "Copper-Built Myelin", "cost": {"Cu": 3}, "icon": "grow_copper_myelin",
		"fact": "Making myelin, the fatty wrap that speeds nerve signals, needs copper enzymes; without copper, nerves lose it.",
		"effect": "Dash or escape keeps you untouchable 0.15 s longer", "mods": {"iframes": 0.15}},
	{"id": "sulfated_slime", "name": "Sulfated Slime", "cost": {"S": 3}, "icon": "grow_sulfated_slime", "once": true,
		"fact": "Slugs, hagfish and worms coat themselves in mucins, sugary proteins studded with sulfate, and slip out of a predator's grip.",
		"effect": "Shed the first hit after each room you clear", "mods": {"autotomy": 1}},
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

# Healing parts ("heal") are used up at once: they never get dearer and are
# not kept as adaptations
static func times_for_cost(r: Dictionary, taken: Dictionary) -> int:
	return 0 if r.has("heal") else int(taken.get(r.id, 0))

static func can_grow(r: Dictionary, have: Dictionary, taken: Dictionary) -> bool:
	var n = taken.get(r.id, 0)
	if r.get("once", false) and n > 0:
		return false
	var c = cost_of(r, times_for_cost(r, taken))
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

# How close you are to affording a part, 0..1 (the slowest element decides)
static func progress(r: Dictionary, have: Dictionary, taken: Dictionary) -> float:
	var c = cost_of(r, times_for_cost(r, taken))
	var f := 1.0
	for el in c:
		f = min(f, float(have.get(el, 0.0)) / max(1.0, c[el]))
	return clampf(f, 0.0, 1.0)
