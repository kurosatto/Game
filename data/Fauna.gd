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
		# Charnia: the swaying fronds of the Ediacaran sea floor are animals
		# you can fight (Room.spawn_fronds), never rolled as a random spawn
		"frond": {"name": "Charnia", "fact": "A feathery rangeomorph frond up to about 60 cm tall, anchored by a disc-shaped holdfast. Found by schoolchildren in Charnwood Forest, England, in the 1950s, it was one of the first fossils accepted as older than the Cambrian. It had no mouth, gut or stinging cells and fed straight from the water.", "tip": "Rooted. Swim too close and the current snaps its tough frond into you.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.4, "speed": 1.0},
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
	# The sea worlds of the last two eras (data/Worlds.gd): floor 4 or 5
	# played as a sea animal. Drawn with the playable forms' drawings
	# ("form"), or a trilobite sheet ("sheet") for the last trilobites.
	6: { # Carboniferous seas: the Bear Gulch bay of Montana, crinoid meadows
		"fly": {"name": "Falcatus", "form": "early_shark", "temper": "territorial", "idle": "patrol", "fact": "A small shark of the Bear Gulch bay, about 30 cm long. Males carried a long spine bent forward over the head, and one fossil pair seems to have died mid-courtship.", "tint": Color(0.92, 0.95, 1.0), "scale": 0.85, "speed": 1.15, "behavior": "weave"},
		"pacer": {"name": "Tyrannophontes", "form": "mantis_shrimp_line", "temper": "predator", "idle": "ambush", "fact": "An early relative of mantis shrimps from the Carboniferous. It already had folding, spiked claws for snatching prey, like its living kin.", "tint": Color(1.0, 0.9, 0.82), "scale": 1.05, "speed": 1.0, "behavior": "lunge", "shoot_delay": 1.6},
		"charger": {"name": "Goniatites", "form": "nautilus", "temper": "territorial", "idle": "drift", "fact": "A Carboniferous ammonoid with a tightly coiled shell and zig-zag seams between its chambers. It changed so fast through time that geologists date Carboniferous rocks by it.", "tip": "It jets at you in a straight line and is dazed when it hits a wall.", "tint": Color(1.0, 0.9, 0.75), "scale": 0.9, "speed": 1.0},
		"enroll": {"name": "Phillipsia", "sheet": "isotelus", "temper": "docile", "idle": "graze", "fact": "One of the last trilobites. By the Carboniferous only one order of them, the proetids, was left, and it lasted until the end-Permian extinction.", "tip": "Hit it and it rolls up, untouchable for a moment; strike again once it uncurls.", "tint": Color(0.95, 0.85, 0.7), "scale": 0.7, "speed": 1.0},
		"tank": {"name": "Hibbertopterus", "form": "chelicerate", "temper": "docile", "idle": "rest", "fact": "A sea scorpion about 1.8 m long that raked the mud with bristly limbs to sieve out small prey. A fossil trackway in Scotland shows that one also crawled out over land.", "tip": "Slow and huge, it barely flinches.", "tint": Color(0.88, 0.8, 0.7), "scale": 1.5, "speed": 1.0},
		"skittish": {"name": "Belantsea", "form": "chimaera", "fact": "A deep-bodied petalodont of the Bear Gulch bay, a cousin of living chimaeras. It nibbled sponges with comb-like teeth and fluttered over the reef like a butterflyfish.", "tip": "Harmless and quick. It flees, but one caught is a big meal.", "tint": Color(1.0, 0.92, 0.8), "scale": 0.95, "speed": 1.0},
	},
	7: { # Permian seas: sponge reefs, ammonoids and the last trilobites
		"fly": {"name": "Palaeoniscum", "form": "ray_finned_fish", "temper": "timid", "idle": "school", "fact": "A ray-finned fish of the Late Permian Zechstein Sea, often found whole in the Kupferschiefer, a copper-rich black shale of Germany and England.", "tint": Color(0.95, 0.95, 1.0), "scale": 0.9, "speed": 1.05, "behavior": "weave"},
		"pacer": {"name": "Campylocephalus", "form": "chelicerate", "temper": "wary", "idle": "graze", "fact": "One of the very last sea scorpions, from the Permian of Russia. Sea scorpions had lived for 200 million years, and died out in the end-Permian extinction.", "tint": Color(0.85, 0.78, 0.7), "scale": 1.2, "speed": 0.9, "shoot_delay": 1.5},
		"charger": {"name": "Waagenoceras", "form": "palau_nautilus", "temper": "territorial", "idle": "drift", "fact": "A Permian ammonoid of the reefs of Texas, the seams between its chambers folded into fine, fern-like frills.", "tip": "It jets at you in a straight line and is dazed when it hits a wall.", "tint": Color(1.0, 0.88, 0.78), "scale": 0.9, "speed": 1.05},
		"enroll": {"name": "Ditomopyge", "sheet": "isotelus", "temper": "docile", "idle": "graze", "fact": "One of the very last trilobites. After 270 million years in the sea, trilobites died out with it in the end-Permian extinction.", "tip": "Hit it and it rolls up, untouchable for a moment; strike again once it uncurls.", "tint": Color(0.85, 0.8, 0.72), "scale": 0.6, "speed": 1.0},
		"skittish": {"name": "Janassa", "form": "chimaera", "fact": "A flat, ray-like petalodont of the Zechstein Sea that crushed shellfish on the sea floor with a pavement of teeth.", "tip": "Harmless and quick. It flees, but one caught is a big meal.", "tint": Color(0.85, 0.82, 0.75), "scale": 1.0, "speed": 1.0},
	},
}

# More animals of each era, drawn and animated in code with the same
# drawings as the playable forms (PlayerBody.gd, "form"), so they walk, swim
# and strike like the player does. Each borrows the behaviour of an existing
# type ("type") and is named after a real fossil animal of that era that the
# drawing fits. Room.roll_enemy_type picks one of them about a third of the
# time. "tint" shades the drawing so it reads apart from the player.
const EXTRAS = {
	1: [
		{"type": "pacer", "form": "early_echinoderm", "name": "Arkarua", "temper": "docile", "idle": "graze", "fact": "A small Ediacaran disc with a five-part star on top. If it was an echinoderm it is the oldest one known, though that is still argued.", "tip": "Slow and shy; it puffs grit at you if bothered.", "tint": Color(1.0, 0.92, 0.82), "scale": 0.8, "speed": 0.7, "shoot_delay": 1.6},
	],
	2: [
		{"type": "fly", "form": "pikaia_chordate", "name": "Pikaia", "temper": "timid", "idle": "school", "fact": "A small Burgess Shale swimmer with a stiff rod along its back. It is one of the oldest known relatives of all backboned animals, us included.", "tip": "Quick and wriggly; it weaves as it swims.", "tint": Color(1.0, 0.95, 0.85), "scale": 0.95, "speed": 1.05, "behavior": "weave"},
		{"type": "fly", "form": "early_arthropod", "name": "Waptia", "temper": "wary", "idle": "school", "fact": "A shrimp-like Burgess Shale arthropod with a two-part shell and a forked tail. Some fossils carry clutches of eggs under the shell.", "tip": "Darts in short bursts.", "tint": Color(0.95, 0.9, 0.8), "scale": 0.9, "speed": 1.0, "behavior": "burst"},
		{"type": "pacer", "form": "chelicerate", "name": "Sanctacaris", "temper": "predator", "idle": "ambush", "fact": "A Burgess Shale hunter whose name means Santa's claws, after its five pairs of spiny head limbs. It may be an early relative of spiders and horseshoe crabs.", "tip": "Lies in wait, then pounces.", "tint": Color(0.95, 0.85, 0.75), "scale": 1.0, "speed": 1.0, "behavior": "lunge", "shoot_delay": 1.5},
		{"type": "charger", "form": "cephalopod", "name": "Plectronoceras", "temper": "territorial", "idle": "drift", "fact": "The oldest known cephalopod, from the very end of the Cambrian: a tiny curved shell divided into gas-filled chambers.", "tip": "It jets at you in a straight line and is dazed when it hits a wall.", "tint": Color(1.0, 0.92, 0.8), "scale": 0.85, "speed": 1.0},
	],
	3: [
		{"type": "fly", "form": "jawless_fish", "name": "Arandaspis", "temper": "timid", "idle": "school", "fact": "One of the oldest fish known well: a jawless Ordovician swimmer with a head armoured in bony plates and no fins but its tail.", "tip": "Schools and weaves.", "tint": Color(0.9, 0.95, 1.0), "scale": 1.0, "speed": 1.0, "behavior": "weave"},
		{"type": "armoured", "form": "horseshoe_crab", "name": "Lunataspis", "temper": "docile", "idle": "graze", "fact": "The oldest horseshoe crab, about 445 million years old. Its living relatives have barely changed shape since.", "tip": "Its shield faces you: hit it from the side or behind.", "tint": Color(1.0, 0.95, 0.85), "scale": 0.9, "speed": 1.0},
		{"type": "tank", "form": "sea_star", "name": "Petraster", "temper": "docile", "idle": "rest", "fact": "One of the first sea stars, from the Ordovician. Sea stars creep on hundreds of tiny water-filled tube feet.", "tip": "Slow and tough, it barely flinches.", "tint": Color(1.0, 0.88, 0.8), "scale": 0.8, "speed": 1.0},
		{"type": "enroll", "form": "sea_snail", "name": "Maclurites", "temper": "docile", "idle": "graze", "fact": "A big Ordovician sea snail. Its thick shell door, the operculum, is a common fossil on its own.", "tip": "Hit it and it pulls in and shuts its door; strike again once it comes out.", "tint": Color(0.95, 0.9, 0.82), "scale": 0.95, "speed": 1.0},
	],
	4: [
		{"type": "orbiter", "form": "spider", "name": "Arthrolycosa", "temper": "predator", "idle": "stalk", "fact": "A Carboniferous spider with a segmented belly, like the living trapdoor-like Mesothelae. Spiders of its age had venom but spun no webs to catch prey.", "tip": "It circles you, then darts in to bite. The venom slows you.", "tint": Color(1.0, 0.9, 0.85), "scale": 0.95, "speed": 1.0},
		{"type": "enroll", "form": "millipede", "name": "Euphoberia", "temper": "docile", "idle": "forage", "fact": "A spiny Carboniferous millipede from the coal swamps. Millipedes curl up to guard their soft underside.", "tip": "Hit it and it coils up, untouchable for a moment.", "tint": Color(1.0, 0.92, 0.85), "scale": 1.0, "speed": 1.0},
		{"type": "fly", "form": "centipede", "name": "Latzelia", "temper": "predator", "idle": "stalk", "fact": "A Carboniferous centipede from Mazon Creek. Its first pair of legs were already venom fangs, as in every centipede today.", "tip": "Sprints in bursts.", "tint": Color(1.0, 0.92, 0.85), "scale": 0.95, "speed": 1.05, "behavior": "burst"},
		{"type": "skittish", "form": "sauropsid", "name": "Hylonomus", "fact": "The oldest known reptile, about 312 million years old. Its bones were found inside the stumps of fossil trees, where it hunted insects.", "tip": "Harmless and quick. It flees, but one caught is a big meal.", "tint": Color(1.0, 0.95, 0.85), "scale": 0.85, "speed": 1.0},
	],
	5: [
		{"type": "fly", "form": "sauropsid", "name": "Captorhinus", "temper": "wary", "idle": "forage", "fact": "A small Early Permian reptile with several rows of teeth, good for crushing tough food.", "tip": "Sprints in bursts.", "tint": Color(0.95, 0.85, 0.75), "scale": 1.0, "speed": 1.0, "behavior": "burst"},
		{"type": "pacer", "form": "lissamphibian", "name": "Cacops", "temper": "predator", "idle": "ambush", "fact": "A stocky Early Permian amphibian with a row of bony plates down its back and a big eardrum notch, probably for hearing prey at night.", "tip": "Lies in wait, then lunges.", "tint": Color(0.9, 0.82, 0.7), "scale": 1.1, "speed": 0.9, "behavior": "lunge", "shoot_delay": 1.8},
		{"type": "swarm", "form": "beetle", "name": "Permocupes", "temper": "timid", "idle": "forage", "fact": "A Late Permian beetle, one of the earliest. Its living relatives, the reticulated beetles, still bore into rotting wood.", "tip": "They come in packs and scatter when one is hit.", "tint": Color(0.9, 0.85, 0.75), "scale": 0.55, "speed": 1.0},
		{"type": "tank", "form": "synapsid", "name": "Edaphosaurus", "temper": "docile", "idle": "graze", "fact": "A 3 m sail-backed plant-eater of the Early Permian, living beside Dimetrodon. Its sail spines carried little knobby crossbars.", "tip": "Slow and massive, it barely flinches.", "tint": Color(0.88, 0.85, 0.72), "scale": 1.5, "speed": 1.0},
	],
	6: [
		{"type": "fly", "form": "early_shark", "name": "Stethacanthus", "temper": "territorial", "idle": "patrol", "fact": "A Carboniferous shark whose males wore an anvil-shaped fin on the back, its flat top covered in tooth-like scales like a scrubbing brush.", "tip": "Darts in short bursts.", "tint": Color(0.8, 0.82, 0.9), "scale": 1.0, "speed": 1.0, "behavior": "burst"},
		{"type": "fly", "form": "coleoid", "name": "Syllipsimopodi", "temper": "timid", "idle": "school", "fact": "A 328-million-year-old cephalopod from Bear Gulch with ten sucker-lined arms: the oldest known relative of octopuses and vampire squid.", "tip": "Quick and wriggly; it weaves as it swims.", "tint": Color(1.0, 0.9, 0.85), "scale": 0.85, "speed": 1.05, "behavior": "weave"},
		{"type": "pacer", "form": "chimaera", "name": "Echinochimaera", "temper": "wary", "idle": "graze", "fact": "A chimaera of the Bear Gulch bay. Males wore spiny scales over the head; living chimaeras, the ratfish, still carry a venomous spine before the back fin.", "tip": "Grazes the reef and spits grit if bothered.", "tint": Color(0.9, 0.85, 0.8), "scale": 1.0, "speed": 0.95, "shoot_delay": 1.5},
		{"type": "charger", "form": "early_shark", "name": "Orthacanthus", "temper": "territorial", "idle": "patrol", "fact": "A shark of the Carboniferous rivers and coastal lagoons, up to 3 m long, with a long spine behind its head.", "tip": "It rushes you in a straight line and is dazed when it hits a wall.", "tint": Color(0.92, 0.95, 1.0), "scale": 1.05, "speed": 1.0},
		{"type": "tank", "form": "sea_urchin", "name": "Archaeocidaris", "temper": "docile", "idle": "rest", "fact": "A Carboniferous sea urchin with big club-shaped spines, which are common fossils in limestones of this age.", "tip": "Slow and spiny, it barely flinches.", "tint": Color(0.95, 0.85, 0.8), "scale": 0.9, "speed": 1.0},
	],
	7: [
		{"type": "fly", "form": "lobe_finned_shorewalker", "name": "Coelacanthus", "temper": "wary", "idle": "drift", "fact": "The Permian fish that gave coelacanths their name, which means hollow spine. Coelacanths were thought to have died out with the dinosaurs until a living one was caught off South Africa in 1938.", "tip": "Weaves as it swims.", "tint": Color(0.75, 0.8, 0.95), "scale": 1.05, "speed": 1.0, "behavior": "weave"},
		{"type": "charger", "form": "shark_line", "name": "Xenacanthus", "temper": "territorial", "idle": "patrol", "fact": "A Permian shark of rivers and coastal lagoons with a long spine on the back of its head and an eel-like tail fin.", "tip": "It rushes you in a straight line and is dazed when it hits a wall.", "tint": Color(0.88, 0.85, 0.8), "scale": 1.0, "speed": 1.0},
		{"type": "tank", "form": "sea_urchin", "name": "Miocidaris", "temper": "docile", "idle": "rest", "fact": "A Permian sea urchin. Only a few urchin lines lived through the end-Permian extinction, and every sea urchin alive today descends from them.", "tip": "Slow and spiny, it barely flinches.", "tint": Color(0.85, 0.8, 0.9), "scale": 0.85, "speed": 1.0},
	],
}

const Worlds = preload("res://data/Worlds.gd")

# floor_num is a floor (1-5, in the world being played) or an era (6, 7)
static func extras(floor_num: int) -> Array:
	return EXTRAS.get(Worlds.era(floor_num), [])

# An era animal by name: a regular one or an extra
static func get_species(floor_num: int, species_name: String) -> Dictionary:
	for sp in era_species(floor_num):
		if sp.name == species_name:
			return sp
	return {}

# Picture for the pause screen and fossil record: drawn forms use the sheets
# rendered from their drawings (tools/render_forms.gd)
static func sheet_path(f: Dictionary) -> String:
	if f.has("form"):
		return "res://assets/lineages/%s_sheet.png" % f.form
	if f.has("sheet"):
		return "res://assets/fauna/%s_sheet.png" % f.sheet
	return "res://assets/fauna/%s_sheet.png" % String(f.name).to_lower()

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
	var f = FLOORS.get(Worlds.era(floor_num), {})
	return f.get(enemy_type, {})

# What a blow lands on, for hit and kill sounds and the bits a kill throws:
# "shell" (mineralised shell or a chitin exoskeleton), "flesh" (backboned
# animals with bone and scales) or "soft" (everything without a hard part).
const BODIES = {
	"Marrella": "shell", "Olenoides": "shell", "Isotelus": "shell", "Wiwaxia": "shell",
	"Orthoceras": "shell", "Cameroceras": "shell", "Megalograptus": "shell",
	"Pulmonoscorpius": "shell", "Archimylacris": "shell", "Meganeura": "shell",
	"Arthropleura": "shell", "Anomalocaris": "shell", "Sacabambaspis": "shell",
	"Waptia": "shell", "Sanctacaris": "shell", "Plectronoceras": "shell", "Lunataspis": "shell",
	"Petraster": "shell", "Maclurites": "shell", "Arthrolycosa": "shell", "Euphoberia": "shell",
	"Latzelia": "shell", "Permocupes": "shell", "Arandaspis": "shell", "Pentecopterus": "shell",
	"Sidneyia": "shell", "Salpingoeca": "soft",
	"Hylonomus": "flesh", "Orthacanthus": "flesh", "Captorhinus": "flesh", "Eryops": "flesh", "Cacops": "flesh",
	"Edaphosaurus": "flesh", "Rhizodus": "flesh",
	"Diictodon": "flesh", "Dimetrodon": "flesh", "Inostrancevia": "flesh",
	"Lystrosaurus": "flesh", "Euchambersia": "flesh",
	# Sea worlds (eras 6, 7) and their bosses
	"Tyrannophontes": "shell", "Goniatites": "shell", "Phillipsia": "shell", "Hibbertopterus": "shell",
	"Archaeocidaris": "shell", "Campylocephalus": "shell", "Waagenoceras": "shell", "Ditomopyge": "shell",
	"Miocidaris": "shell",
	"Falcatus": "flesh", "Belantsea": "flesh", "Stethacanthus": "flesh", "Echinochimaera": "flesh",
	"Palaeoniscum": "flesh", "Janassa": "flesh", "Coelacanthus": "flesh", "Xenacanthus": "flesh",
	"Edestus": "flesh", "Helicoprion": "flesh", "Ophiacodon": "flesh", "Mesosaurus": "flesh",
}

static func body_of(species: String) -> String:
	return BODIES.get(species, "soft")

const SPECIAL_TYPES = ["tank", "armoured", "charger", "swarm", "burrower", "frond", "colony", "skittish", "enroll", "snarer", "orbiter"]

# The era's third animal type ("tank", "swarm"...), or "" if none
static func special_type(floor_num: int) -> String:
	var all = special_types(floor_num)
	return all[0] if not all.is_empty() else ""

# Every special animal type of the era, third animal first
static func special_types(floor_num: int) -> Array:
	var f = FLOORS.get(Worlds.era(floor_num), {})
	return SPECIAL_TYPES.filter(func(t): return f.has(t))

# short: special animals get only their tip (the floor banner); the pause
# screen shows everything
static func describe_floor(floor_num: int, short: bool = false) -> String:
	var f = FLOORS.get(Worlds.era(floor_num), {})
	if f.is_empty():
		return ""
	var text = "%s: %s\n%s: %s" % [f.fly.name, f.fly.fact, f.pacer.name, f.pacer.fact]
	for t in special_types(floor_num):
		if short:
			text += "\n%s: %s" % [f[t].name, f[t].tip]
		else:
			text += "\n%s: %s %s" % [f[t].name, f[t].fact, f[t].tip]
	return text

# The era bosses for the fossil record (bosses/*.gd draw and run them)
const BOSSES = {
	1: {"name": "Stentor", "fact": "A trumpet-shaped single cell up to 2 mm long, still common in ponds today. Cut into pieces, each piece can regrow a whole cell."},
	2: {"name": "Anomalocaris", "fact": "A Cambrian radiodont about 40 cm long, one of the first big predators, with spiny grasping limbs and a ring of plates for a mouth."},
	3: {"name": "Cameroceras", "fact": "An Ordovician endocerid nautiloid with a long, straight, chambered shell; the largest may have reached several metres."},
	4: {"name": "Arthropleura", "fact": "A Carboniferous relative of millipedes up to 2.6 m long, the largest land arthropod known."},
	5: {"name": "Dimetrodon", "fact": "A Permian sail-backed synapsid: not a dinosaur but closer kin to mammals, with a skull opening like ours."},
	6: {"name": "Edestus", "fact": "A Carboniferous eugeneodont up to about 6 m long, nearer kin to ratfish than to true sharks. Its teeth grew in curved rows that jutted from both jaws like a pair of shears."},
	7: {"name": "Helicoprion", "fact": "An Early Permian eugeneodont with a spiral whorl of over 100 teeth in its lower jaw. Scans of a fossil from Idaho showed in 2013 that the whorl filled the jaw and sliced prey like a saw as the mouth shut."},
}

# The other boss each era can have instead (bosses/DrawnBoss.gd)
const ALT_BOSSES = {
	1: {"name": "Salpingoeca", "form": "ancestral_collar_cell", "fact": "A living choanoflagellate, the closest single-celled relative of animals. Its collar cells stick together into a spinning rosette."},
	2: {"name": "Sidneyia", "form": "early_arthropod", "fact": "One of the biggest arthropods of the Burgess Shale. Its gut is often found packed with crushed shells, cracked by spiny bases on its legs."},
	3: {"name": "Pentecopterus", "form": "chelicerate", "fact": "The oldest known big sea scorpion, about 1.7 m long, named after a Greek warship. It swept prey up in a basket of spiny limbs."},
	4: {"name": "Ophiacodon", "form": "synapsid", "fact": "A synapsid up to 3 m long of the Late Carboniferous and Early Permian, one of the first big hunters on land, and closer kin to mammals than to any reptile."},
	5: {"name": "Eryops", "form": "lissamphibian", "fact": "A 2 m Permian amphibian with a broad, flat skull that probably gulped its prey, living beside Dimetrodon."},
	6: {"name": "Rhizodus", "form": "lobe_finned_shorewalker", "fact": "A 7 m lobe-finned fish of the Carboniferous rivers and coastal waters, with fangs as long as a hand, the top predator of its world."},
	7: {"name": "Mesosaurus", "form": "sauropsid", "fact": "One of the first reptiles to return to the water, about 1 m long, with needle teeth for straining small crustaceans. Its fossils in both Brazil and southern Africa helped show that the continents were once joined."},
}

# Every species of an era in the order the fossil record lists them
static func era_species(floor_num: int) -> Array:
	var f = FLOORS.get(Worlds.era(floor_num), {})
	var out: Array = [f.fly, f.pacer]
	for t in special_types(floor_num):
		out.append(f[t])
	out.append_array(extras(floor_num))
	return out
