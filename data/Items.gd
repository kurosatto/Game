# Items.gd
# Treasure-room finds: one per floor, never the same one twice in a run.
# Each is a real piece of biology that some lineage picked up, often from
# another organism. They are bigger than adaptations and survive evolution.
# "mods" use the same keys as data/Adaptations.gd (Player.adaptation_mods()
# adds them in), plus these, read by Player.gd and Enemy.gd:
#   stun (share of hits that stun), photo (seconds per half heart healed),
#   ink (seconds hidden when hurt), decompose (kills burst in a cloud that
#   hurts animals nearby), alarm (kills freeze animals nearby for this many
#   seconds), ram (dash hits animals for this x damage), paralyse (spine
#   pricks stun), gift (adaptations granted on pickup).
# Older items (onion, eye, hormones, cells) keep their flat bonuses in
# Player.apply_item_upgrade().
# Icons: assets/ui/icons/item_<id>.png from generate_ui_icons.py.
extends RefCounted

const LIST = [
	{"id": "onion", "name": "Cytoplasmic Streaming",
		"fact": "Inside giant algal cells the cytoplasm flows round in a loop, carrying supplies to every corner far faster than diffusion could.",
		"effect": "Attack faster", "mods": {}},
	{"id": "eye", "name": "Compound Ocelli",
		"fact": "Simple eyes called ocelli sit between an insect's big compound eyes and catch fast changes in light, helping it aim.",
		"effect": "Shots fire in threes, swings sweep wider", "mods": {}},
	{"id": "hormones", "name": "Fight-or-Flight Hormones",
		"fact": "Adrenaline in vertebrates and octopamine in insects and crustaceans flood the body before a fight, priming muscles to strike and run.",
		"effect": "+damage and +move speed", "mods": {}},
	{"id": "cells", "name": "Genome Duplication",
		"fact": "Copying a whole genome gave early vertebrates spare genes that went on to build new tissues and organs.",
		"effect": "+1 heart, healed now", "mods": {}},
	{"id": "plasmid", "name": "Plasmid",
		"fact": "Bacteria pass small rings of DNA called plasmids to one another. It is how antibiotic resistance spreads between species.",
		"effect": "Gain two random adaptations now", "mods": {"gift": 2}},
	{"id": "kleptoplasty", "name": "Stolen Chloroplasts",
		"fact": "The sea slug Elysia chlorotica keeps the chloroplasts of the algae it eats alive in its own cells and lives on sunlight for months.",
		"effect": "Heal half a heart every 20 seconds", "mods": {"photo": 20.0}},
	{"id": "ink_sac", "name": "Ink Sac",
		"fact": "Squid and octopus squirt melanin ink when attacked. Some puffs hold their shape like a decoy body while the animal jets away.",
		"effect": "When hurt, squirt ink and vanish for 2.5 s", "mods": {"ink": 2.5}},
	{"id": "nematocysts", "name": "Stolen Stingers",
		"fact": "Blue sea dragons and other aeolid sea slugs eat jellyfish and siphonophores, then store their unfired stinging cells in their own skin.",
		"effect": "20% of hits stun", "mods": {"stun": 0.2}},
	{"id": "glow_bacteria", "name": "Glowing Bacteria",
		"fact": "The Hawaiian bobtail squid farms Vibrio fischeri in a light organ, using their glow to hide its shadow from hunters below.",
		"effect": "+2 vision", "mods": {"vision": 2}},
	{"id": "tetrodotoxin", "name": "Tetrodotoxin",
		"fact": "Pufferfish do not make their deadly toxin; bacteria in their bodies do. It blocks the sodium channels nerves need to fire.",
		"effect": "Animals touching you are pricked and paralysed", "mods": {"thorns": 1.0, "paralyse": 1}},
	{"id": "decomposers", "name": "Decomposer Bacteria",
		"fact": "Without decomposers, dead bodies would pile up forever. Bacteria and fungi turn them back into nutrients within days.",
		"effect": "Kills burst into a cloud that hurts animals nearby", "mods": {"decompose": 1}},
	{"id": "alarm", "name": "Alarm Pheromone",
		"fact": "When a minnow's skin is torn it leaks Schreckstoff, 'scary stuff', and every minnow that smells it freezes or bolts.",
		"effect": "Each kill freezes animals nearby for 1.2 s", "mods": {"alarm": 1.2}},
	{"id": "headshield", "name": "Bony Head Shield",
		"fact": "Jawless fishes like Cephalaspis wore a solid shield of bone over the head, hundreds of millions of years before jaws.",
		"effect": "Dashing rams animals for 1.5x damage", "mods": {"ram": 1.5}},
	{"id": "lateral_line", "name": "Lateral Line",
		"fact": "A row of hair cells along a fish's flank feels the water move, so it can dodge a strike it never saw.",
		"effect": "Dash or escape recharges 30% faster, +2 sense", "mods": {"dash_cd": 0.3, "sense": 2}},
]

static func get_item(id: String) -> Dictionary:
	for it in LIST:
		if it.id == id:
			return it
	return {}

# A random item not yet found this run (any item once all have been found)
static func roll(found: Array) -> String:
	var pool: Array = []
	for it in LIST:
		if not found.has(it.id):
			pool.append(it.id)
	if pool.is_empty():
		for it in LIST:
			pool.append(it.id)
	return pool.pick_random()
