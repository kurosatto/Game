# Fauna.gd
# Era-accurate names for each floor's regular enemies. The two AI behaviours
# stay the same ("fly" chases, "pacer" wanders and shoots); each floor dresses
# them as animals that really lived in that era. Extinct animals are fine here.
# Optional "behavior": "weave" (S-curve swimmer/flier), "burst" (sprint and
# pause), "lunge" (ambush predator: winds up, then dashes). "shoot_delay"
# scales the time between shots.
extends RefCounted

const FLOORS = {
	1: {
		"fly": {"name": "Spriggina", "fact": "A segmented Ediacaran animal; its head end suggests it could move with purpose.", "tint": Color(1.0, 0.85, 0.75), "scale": 0.9, "speed": 0.9, "behavior": "burst"},
		"pacer": {"name": "Kimberella", "fact": "An Ediacaran slug-like grazer that left scratch marks as it fed on microbial mats.", "tint": Color(0.85, 0.95, 0.8), "scale": 1.0, "speed": 0.85, "shoot_delay": 1.4},
	},
	2: {
		"fly": {"name": "Opabinia", "fact": "A Cambrian swimmer with five eyes and a grasping nozzle.", "tint": Color(1.0, 0.75, 0.65), "scale": 1.0, "speed": 1.0, "behavior": "weave"},
		"pacer": {"name": "Olenoides", "fact": "A spiny Cambrian trilobite from the Burgess Shale, preserved with its legs and antennae.", "tint": Color(1.0, 1.0, 1.0), "scale": 1.0, "speed": 1.0},
	},
	3: {
		"fly": {"name": "Sacabambaspis", "fact": "An Ordovician jawless fish with eyes at the very front of its armoured head.", "tint": Color(0.75, 0.9, 1.0), "scale": 1.05, "speed": 1.05, "behavior": "weave"},
		"pacer": {"name": "Megalograptus", "fact": "An Ordovician sea scorpion (eurypterid) with spiny grasping limbs.", "tint": Color(1.0, 0.7, 0.55), "scale": 1.15, "speed": 1.0, "behavior": "lunge", "shoot_delay": 1.6},
	},
	4: {
		"fly": {"name": "Meganeura", "fact": "A Carboniferous griffinfly with a wingspan of about 70 cm.", "tint": Color(0.7, 1.0, 0.85), "scale": 1.15, "speed": 1.2, "behavior": "weave"},
		"pacer": {"name": "Pulmonoscorpius", "fact": "A Carboniferous land scorpion about 70 cm long.", "tint": Color(0.9, 0.75, 0.5), "scale": 1.2, "speed": 1.05, "behavior": "lunge", "shoot_delay": 1.6},
	},
	5: {
		"fly": {"name": "Lystrosaurus", "fact": "A tusked synapsid that survived the end-Permian extinction and spread across the Early Triassic world.", "tint": Color(1.0, 0.85, 0.6), "scale": 1.2, "speed": 1.1, "behavior": "burst"},
		"pacer": {"name": "Inostrancevia", "fact": "A sabre-toothed gorgonopsian, one of the last top predators before the end-Permian extinction.", "tint": Color(1.0, 0.6, 0.6), "scale": 1.3, "speed": 1.1, "behavior": "lunge", "shoot_delay": 2.0},
	},
}

static func get_fauna(floor_num: int, enemy_type: String) -> Dictionary:
	var f = FLOORS.get(clampi(floor_num, 1, 5), {})
	return f.get(enemy_type, {})

static func describe_floor(floor_num: int) -> String:
	var f = FLOORS.get(clampi(floor_num, 1, 5), {})
	if f.is_empty():
		return ""
	return "%s: %s\n%s: %s" % [f.fly.name, f.fly.fact, f.pacer.name, f.pacer.fact]
