# FoodWeb.gd
# Who eats whom among each era's animals (Enemy.gd "FOOD WEB"). A hunter left
# to itself stalks the prey it knows, and a prey animal that sees one coming
# runs. A caught animal is eaten where it is caught: the hunter stops to feed,
# grows a little, and is too busy to notice you for a few seconds.
#
# The links follow what is known or reasonably inferred from fossils:
# - Ediacaran: no predators at all. No Ediacaran fossil shows a bite, a
#   drill hole or a jaw, the "Garden of Ediacara".
# - Cambrian: Sanctacaris had a basket of spiny grasping limbs for small
#   swimmers and crawlers like Marrella and Waptia; Opabinia caught small
#   prey with its clawed nozzle.
# - Ordovician: eurypterids such as Megalograptus and the nautiloids hunted
#   the first armoured fish and small arthropods.
# - Carboniferous: griffinflies caught other insects on the wing; scorpions,
#   spiders and centipedes hunted roachoids and millipedes on the swamp floor.
# - Permian: gorgonopsians like Inostrancevia were the top hunters of
#   dicynodonts such as Diictodon and Lystrosaurus; Euchambersia went for
#   smaller prey; Cacops and Captorhinus ate insects.
# - Carboniferous and Permian seas: small sharks like Stethacanthus and
#   Falcatus hunted squid kin and small fish; mantis-shrimp relatives
#   snatched small swimmers; Xenacanthus and Coelacanthus ate smaller fish.
extends RefCounted

const EATS = {
	# Cambrian
	"Sanctacaris": ["Marrella", "Waptia", "Pikaia"],
	"Opabinia": ["Marrella", "Pikaia"],
	# Ordovician
	"Megalograptus": ["Sacabambaspis", "Arandaspis", "Lunataspis"],
	"Orthoceras": ["Sacabambaspis", "Arandaspis"],
	# Carboniferous
	"Meganeura": ["Archimylacris"],
	"Pulmonoscorpius": ["Archimylacris", "Euphoberia", "Hylonomus"],
	"Arthrolycosa": ["Archimylacris"],
	"Latzelia": ["Archimylacris", "Euphoberia"],
	# Permian
	"Inostrancevia": ["Lystrosaurus", "Diictodon", "Captorhinus"],
	"Euchambersia": ["Diictodon", "Captorhinus"],
	"Cacops": ["Permocupes"],
	"Captorhinus": ["Permocupes"],
	# Carboniferous seas
	"Stethacanthus": ["Syllipsimopodi", "Belantsea"],
	"Falcatus": ["Syllipsimopodi"],
	"Tyrannophontes": ["Syllipsimopodi", "Phillipsia"],
	"Orthacanthus": ["Belantsea", "Falcatus"],
	# Permian seas
	"Xenacanthus": ["Palaeoniscum", "Janassa"],
	"Coelacanthus": ["Palaeoniscum"],
}

static func eats(hunter: String, prey: String) -> bool:
	return EATS.get(hunter, []).has(prey)

static func is_hunter(species: String) -> bool:
	return EATS.has(species)

# Every hunter of this species
static func eaten_by(prey: String) -> Array:
	var out: Array = []
	for h in EATS:
		if EATS[h].has(prey):
			out.append(h)
	return out

# "Pred>Prey": how a seen hunt is saved in the fossil record (Codex.note_hunt)
static func link(hunter: String, prey: String) -> String:
	return hunter + ">" + prey
