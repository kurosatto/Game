# Adaptations.gd
# Small stacking upgrades picked when the biomass bar fills (from eating
# prey). Each is a real trait that evolved many times across animal lineages,
# so any form can take it. They stay through evolution; Player.recompute_stats()
# applies them on top of the current form.
# "mods" keys: damage, fire, speed, range, dash_cd, zap_cd, zap_radius,
# biomass (fractions added together), hp (max health), vision, sense,
# regen (half hearts healed on room clear), knockback, armour, perk,
# autotomy (shed the first hit after each cleared room), iframes (seconds
# added to dash/escape), crit (share of hits doing double), symbiont (heal
# half a heart per 12 biomass), thorns (contact damage x your damage),
# zap_power (ZAP damage and stun), stealth (animals must come this share
# closer before they notice you).
# "once": can only be taken one time.
extends RefCounted

const LIST = [
	{"id": "muscle", "name": "Stronger Muscles",
		"fact": "More fibres per muscle bundle put more force behind every bite, sting and shot.",
		"effect": "+20% damage", "mods": {"damage": 0.2}},
	{"id": "mitochondria", "name": "More Mitochondria",
		"fact": "Cells packed with mitochondria make ATP faster, so muscles recover and fire again sooner.",
		"effect": "Attack 12% faster", "mods": {"fire": 0.12}},
	{"id": "myoglobin", "name": "Myoglobin-Rich Muscle",
		"fact": "Myoglobin stores oxygen inside muscle; it is why tuna and whale muscle is so dark.",
		"effect": "+10% move speed", "mods": {"speed": 0.1}},
	{"id": "body_wall", "name": "Tougher Body Wall",
		"fact": "Thicker collagen layers or cuticle make a body much harder to tear open.",
		"effect": "+1 heart, healed now", "mods": {"hp": 2}},
	{"id": "fast_twitch", "name": "Fast-Twitch Fibres",
		"fact": "Fast-twitch muscle contracts quickly for escape bursts, which is how a squid or shrimp snaps away.",
		"effect": "Dash or escape recharges 20% faster", "mods": {"dash_cd": 0.2}},
	{"id": "ion_channels", "name": "Dense Ion Channels",
		"fact": "More sodium and potassium channels let nerves and muscles fire stronger, faster signals.",
		"effect": "ZAP recharges 20% faster, reaches 10% farther", "mods": {"zap_cd": 0.2, "zap_radius": 0.1}},
	{"id": "reach", "name": "Longer Appendages",
		"fact": "Longer limbs, jaws or tentacles reach prey from a safer distance.",
		"effect": "+15% attack range", "mods": {"range": 0.15}},
	{"id": "regeneration", "name": "Regeneration",
		"fact": "Planarians, sea stars and axolotls regrow lost tissue from pools of stem cells.",
		"effect": "Heal half a heart each room you clear", "mods": {"regen": 1}},
	{"id": "gut", "name": "Longer, Folded Gut",
		"fact": "More gut surface absorbs more from every meal, so each kill feeds you more.",
		"effect": "+30% biomass from prey", "mods": {"biomass": 0.3}},
	{"id": "toxins", "name": "Toxin Glands",
		"fact": "Venom evolved independently more than a hundred times, from cone snails to centipedes.",
		"effect": "Attacks poison what they hit", "mods": {"perk": "caustic"}, "once": true},
	{"id": "senses", "name": "Keener Senses",
		"fact": "More sensory cells, whether photoreceptors, hair cells or chemoreceptors, pick up fainter signals.",
		"effect": "+1 vision, +1 to your best other sense", "mods": {"vision": 1, "sense": 1}},
	{"id": "mass", "name": "Heavier Build",
		"fact": "More mass behind a strike transfers more momentum to whatever it hits.",
		"effect": "Hits knock enemies back", "mods": {"knockback": 260.0}},
	{"id": "armour", "name": "Mineralised Armour",
		"fact": "Plates of calcium carbonate or phosphate protected trilobites, early fish and molluscs alike.",
		"effect": "Big hits do 1 less damage", "mods": {"armour": 1}, "once": true},
	{"id": "autotomy", "name": "Autotomy",
		"fact": "Lizards drop their tails, crabs their claws and brittle stars their arms, leaving a predator holding a twitching decoy.",
		"effect": "Shed the first hit after each room you clear", "mods": {"autotomy": 1}, "once": true},
	{"id": "mauthner", "name": "Giant Escape Neurons",
		"fact": "Fish Mauthner cells and the squid giant axon fire an escape in a few thousandths of a second.",
		"effect": "Dash or escape keeps you untouchable 0.15 s longer", "mods": {"iframes": 0.15}},
	{"id": "serrated", "name": "Serrated Edges",
		"fact": "Saw-edged teeth grip and tear as they slice; Dimetrodon is the first land animal known to have had them.",
		"effect": "15% of hits do double damage", "mods": {"crit": 0.15}},
	{"id": "symbionts", "name": "Gut Symbionts",
		"fact": "Gut bacteria digest what their host cannot; termites and cows would starve without theirs.",
		"effect": "Heal half a heart for every 12 biomass you eat", "mods": {"symbiont": 1.0}},
	{"id": "thorns", "name": "Defensive Spines",
		"fact": "Spines evolved again and again, on sea urchins, pufferfish and hedgehogs, to punish anything that bites.",
		"effect": "Enemies touching you are pricked twice a second", "mods": {"thorns": 1.0}},
	{"id": "camouflage", "name": "Cryptic Colouring",
		"fact": "Mottled, disruptive patterns break up an outline; flounders, leaf insects and peppered moths all hide this way.",
		"effect": "Animals notice you 20% closer", "mods": {"stealth": 0.2}},
	{"id": "electrocytes", "name": "Electric Organ",
		"fact": "Stacks of electrocytes, modified muscle cells, evolved at least six separate times in fish.",
		"effect": "ZAP hits 40% harder and stuns longer", "mods": {"zap_power": 0.4}},
]

# Biomass needed for the next adaptation; level counts adaptations taken
static func biomass_needed(level: int) -> int:
	return 5 + level * 3

static func get_adaptation(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}

# Up to count different adaptations, skipping "once" ones already taken
static func roll(taken: Dictionary, count: int = 3) -> Array:
	var pool: Array = []
	for a in LIST:
		if a.get("once", false) and taken.get(a.id, 0) > 0:
			continue
		pool.append(a)
	pool.shuffle()
	return pool.slice(0, count)
