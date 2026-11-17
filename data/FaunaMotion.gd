# FaunaMotion.gd
# How each era animal moves its body, read by Enemy.gd's motion layer
# (update_motion + the MOTION shader). The sprite sheets only hold 4 frames;
# these numbers bend, ripple and pace them so each lineage moves the way the
# real animal did (or, for extinct ones, the way its closest living kin do).
#
# style:  "swim"   lateral body wave, strongest at the tail (fish, lobed swimmers)
#         "sprawl" walking with a side-to-side spine flex in time with the
#                  feet (early synapsids walked like big lizards)
#         "skitter" many-legged walk: no spine flex, a quick sliding shimmy
#                  (arthropods; kuro liked this best on the player)
#         "creep"  a muscular foot or body wall: peristaltic bulges travel
#                  down the body (slugs, molluscs, velvet worms)
#         "jet"    rigid shell, the mantle squeezes in pulses (nautiloids)
#         "fly"    wings beat fast whatever the speed, the body bobs
#         "rooted" anchored on the sea floor, sways in the current
# wave:   body-wave amplitude, as a fraction of the frame width
# waves:  how many wavelengths fit along the body
# stride: pixels travelled per full 4-frame cycle (ties the frames to the
#         ground so feet don't slide; swimmers use it for tail beats)
# sway:   whole-body shimmy in radians, in time with the stride
# pulse:  peristaltic / jet squeeze strength
# curve:  how far the tail swings out on a turn
# hz:     beats per second at rest (gills, breathing, hovering wings)
extends RefCounted

const DEFAULT = {"style": "swim", "wave": 0.03, "waves": 1.0, "stride": 70.0, "sway": 0.02, "pulse": 0.0, "curve": 1.0, "hz": 0.6}

const SPECIES = {
	# Ediacaran
	"Spriggina": {"style": "swim", "wave": 0.035, "waves": 1.2, "stride": 60.0, "sway": 0.02, "curve": 1.2, "hz": 0.5},
	"Kimberella": {"style": "creep", "wave": 0.008, "waves": 1.0, "stride": 46.0, "pulse": 0.07, "curve": 0.5, "hz": 0.35},
	"Dickinsonia": {"style": "creep", "wave": 0.012, "waves": 1.5, "stride": 70.0, "pulse": 0.04, "curve": 0.2, "hz": 0.25},
	"Fractofusus": {"style": "rooted", "wave": 0.015, "waves": 0.7, "stride": 999.0, "pulse": 0.0, "curve": 0.0, "hz": 0.35},
	# Cambrian
	"Opabinia": {"style": "swim", "wave": 0.045, "waves": 1.6, "stride": 70.0, "sway": 0.015, "curve": 1.4, "hz": 1.1},
	"Olenoides": {"style": "skitter", "wave": 0.0, "stride": 42.0, "sway": 0.05, "curve": 0.3, "hz": 0.4},
	"Wiwaxia": {"style": "creep", "wave": 0.006, "waves": 1.0, "stride": 56.0, "pulse": 0.035, "curve": 0.3, "hz": 0.3},
	"Marrella": {"style": "skitter", "wave": 0.01, "waves": 1.0, "stride": 34.0, "sway": 0.06, "curve": 0.6, "hz": 1.6},
	# Ordovician
	"Sacabambaspis": {"style": "swim", "wave": 0.075, "waves": 0.85, "stride": 90.0, "sway": 0.01, "curve": 1.8, "hz": 1.4},
	"Megalograptus": {"style": "skitter", "wave": 0.02, "waves": 0.8, "stride": 56.0, "sway": 0.04, "curve": 0.9, "hz": 0.5},
	"Orthoceras": {"style": "jet", "wave": 0.0, "stride": 999.0, "pulse": 0.09, "curve": 0.0, "hz": 1.3},
	"Isotelus": {"style": "skitter", "wave": 0.0, "stride": 48.0, "sway": 0.035, "curve": 0.2, "hz": 0.35},
	# Carboniferous
	"Meganeura": {"style": "fly", "wave": 0.015, "waves": 0.6, "stride": 999.0, "sway": 0.0, "curve": 0.4, "hz": 6.5},
	"Pulmonoscorpius": {"style": "skitter", "wave": 0.02, "waves": 0.7, "stride": 52.0, "sway": 0.045, "curve": 1.0, "hz": 0.4},
	"Archimylacris": {"style": "skitter", "wave": 0.0, "stride": 26.0, "sway": 0.07, "curve": 0.3, "hz": 2.0},
	"Helenodora": {"style": "creep", "wave": 0.03, "waves": 1.3, "stride": 38.0, "pulse": 0.05, "curve": 1.4, "hz": 0.5},
	# Permian / Triassic synapsids: sprawling, the spine flexes with each step
	"Lystrosaurus": {"style": "sprawl", "wave": 0.03, "waves": 0.9, "stride": 78.0, "sway": 0.035, "curve": 0.8, "hz": 0.45},
	"Inostrancevia": {"style": "sprawl", "wave": 0.035, "waves": 0.9, "stride": 96.0, "sway": 0.03, "curve": 1.0, "hz": 0.4},
	"Diictodon": {"style": "sprawl", "wave": 0.03, "waves": 1.0, "stride": 58.0, "sway": 0.04, "curve": 0.8, "hz": 0.6},
	"Euchambersia": {"style": "sprawl", "wave": 0.04, "waves": 1.0, "stride": 72.0, "sway": 0.035, "curve": 1.2, "hz": 0.5},
}

static func get_profile(species: String) -> Dictionary:
	var p: Dictionary = DEFAULT.duplicate()
	p.merge(SPECIES.get(species, {}), true)
	return p
