# eyelesstest.gd
# Forms with no eyes (vision 0 in data/Lineages.gd VISION): the fog shrinks to
# VisionFog.EYELESS_RADIUS, a pitch-dark room takes nothing more from them,
# their senses reach further (SenseHints.EYELESS_REACH) and the chemical sense
# tastes unhurt animals too. Crinoids show touch and vibration as well as taste.
# Run: godot --headless --path . -s res://tools/eyelesstest.gd
extends SceneTree
var lineages = preload("res://data/Lineages.gd")
var failures := 0
const EYELESS = ["ancestral_collar_cell", "early_echinoderm", "sea_lily", "isocrinid_sea_lily",
	"feather_star", "endoxocrinus", "metacrinus", "rosy_feather_star", "reef_feather_star",
	"free_moving_echinoderm", "spiny_echinozoan", "sea_urchin", "brittle_star", "sea_cucumber",
	"burrowing_clam", "oyster", "shipworm"]

func check(ok: bool, what: String):
	print("EYELESS %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures += 1

func form(id: String) -> Dictionary:
	for path in lineages.TREE:
		if lineages.TREE[path].id == id:
			return lineages.TREE[path]
	return {}

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var fog = main.get_node("VisionFog")
	for id in EYELESS:
		check(not form(id).is_empty(), "%s is a playable form" % id)
		check(lineages.get_vision(form(id)) == 0, "%s has no eyes" % id)
		var prof = lineages.sense_profile(form(id))
		var best = lineages.SENSES[id]
		check(prof.get(best[1], 0) == best[0], "%s best sense %s matches its profile" % [id, best[1]])
	# Every other form still sees at least as far as a blind one
	for path in lineages.TREE:
		var f = lineages.TREE[path]
		if not EYELESS.has(f.id):
			check(lineages.get_vision(f) >= 1, "%s keeps its eyes" % f.id)
	for id in ["sea_lily", "feather_star"]:
		var prof = lineages.sense_profile(form(id))
		check(prof.size() >= 3 and prof.has("Touch") and prof.has("Vibration") and prof.has("Chemical sense"),
			"%s feels by touch, vibration and taste (%s)" % [id, prof])
	p.apply_form(form("sea_urchin"))
	fog.set_vision(p.vision, true)
	check(fog.eyeless and is_equal_approx(fog.radius, fog.EYELESS_RADIUS), "urchin fog is %.0f px" % fog.radius)
	fog.pitch = 1.0
	check(is_equal_approx(fog.light_radius(), fog.EYELESS_RADIUS), "dark rooms take nothing from an eyeless form")
	fog.pitch = 0.0
	check(fog.hints._eyeless(), "senses know the form is eyeless")
	p.apply_form(form("sea_star"))
	fog.set_vision(p.vision, true)
	check(not fog.eyeless and fog.radius > 200.0, "sea star with arm-tip eyes sees %.0f px" % fog.radius)
	fog.pitch = 1.0
	check(fog.light_radius() < fog.radius, "a dark room still dims eyes")
	fog.pitch = 0.0
	# Eyeless forms taste unhurt animals; others only wounded ones
	p.apply_form(form("ancestral_collar_cell"))
	fog.set_vision(p.vision, true)
	fog.set_sense(p.sense, p.sense_kind, p.sense_profile)
	check(lineages.describe_vision(form("sea_lily")).contains("other senses reach further"), "pause text explains eyeless")
	print("EYELESS done, %d failures" % failures)
	quit(1 if failures > 0 else 0)
