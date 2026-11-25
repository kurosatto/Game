# SceneryTheme.gd
# One quiet colour theme per floor for the room scenery (rocks, sponges,
# fronds, glowing things, fossils and the pebble banks between them).
# kuro (2026-11-25): the obstacles were too distracting, every piece its own
# loud colour. Now every piece on a floor is repainted in that floor's two
# tones (ink-dark to pale), a little softer than the animals, so the eye
# goes to the animals and the player. Floors still differ from each other.
extends RefCounted

# era art folder -> [dark tone, pale tone, glow tint]
const THEMES = {
	# Grey-green microbial sea floor
	"ediacaran": [Color(0.29, 0.33, 0.29), Color(0.72, 0.75, 0.66), Color(0.80, 0.90, 0.82)],
	# Warm sand and ochre reef
	"cambrian": [Color(0.38, 0.30, 0.22), Color(0.82, 0.73, 0.58), Color(0.95, 0.86, 0.68)],
	# Cold slate-blue shelf
	"ordovician": [Color(0.26, 0.30, 0.36), Color(0.69, 0.73, 0.78), Color(0.78, 0.85, 0.95)],
	# Mossy olive swamp
	"carboniferous": [Color(0.28, 0.31, 0.20), Color(0.68, 0.70, 0.52), Color(0.82, 0.90, 0.62)],
	# Rust and red clay desert
	"permian": [Color(0.40, 0.24, 0.18), Color(0.83, 0.67, 0.55), Color(1.00, 0.70, 0.45)],
	# Teal-grey open sea
	"carboniferous_sea": [Color(0.21, 0.31, 0.32), Color(0.63, 0.73, 0.71), Color(0.74, 0.90, 0.88)],
	# Dusty lilac-grey deep sea
	"permian_sea": [Color(0.31, 0.27, 0.34), Color(0.73, 0.68, 0.73), Color(0.88, 0.82, 0.92)],
}
const DEFAULT = [Color(0.33, 0.30, 0.26), Color(0.76, 0.72, 0.64), Color(0.90, 0.88, 0.80)]

static func get_theme(era_name: String) -> Array:
	return THEMES.get(era_name, DEFAULT)

static func dark(era_name: String) -> Color:
	return get_theme(era_name)[0]

static func pale(era_name: String) -> Color:
	return get_theme(era_name)[1]

static func glow(era_name: String) -> Color:
	return get_theme(era_name)[2]

# A tone between the two, t = 0 dark to 1 pale
static func tone(era_name: String, t: float) -> Color:
	return dark(era_name).lerp(pale(era_name), t)
