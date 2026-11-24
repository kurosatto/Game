# Unlocks.gd
# Which main menu GROW parts are open (kuro, 2026-11-24: "make the grow
# options locked until you get a certain achievement, some easy, some
# hard"). Three starter parts are open from the first run; every other part
# opens with a goal tied to its biology: trilobites see through calcite, so
# eating trilobites opens calcite lenses; chitons and other molluscs give
# magnetite teeth; reaching the Permian as an arachnid opens zinc venom.
# Counts are kept across runs in Progress (lineage/stats), fed by
# Main.tally / Main.flush_bank. A part you have already grown stays open.
extends RefCounted

const PROGRESS = preload("res://data/Progress.gd")

const STARTERS = ["photoreceptors", "phosphagen", "keratin_claws"]

const TRILOBITES = ["Olenoides", "Isotelus", "Phillipsia", "Ditomopyge", "Ampyx"]
const ECHINODERMS = ["Arkarua", "Petraster", "Archaeocidaris", "Miocidaris"]
const JAWLESS_FISH = ["Sacabambaspis", "Arandaspis"]
const MOLLUSCS = ["Kimberella", "Wiwaxia", "Orthoceras", "Plectronoceras", "Maclurites", "Goniatites", "Waagenoceras", "Syllipsimopodi"]
const CHELICERATES = ["Megalograptus", "Pulmonoscorpius", "Arthrolycosa", "Hibbertopterus", "Campylocephalus", "Pentecopterus"]

# type: eat (any of "species"), eat_all, event (a tally key), boss (floor),
# reach (floor as a descendant of "clade", a form id), won, fossils
const GOALS = {
	"iron_sulfur": {"tier": "easy", "type": "eat_all", "need": 100, "text": "Eat 100 animals",
		"icon": "res://assets/fauna/kimberella_sheet.png", "sheet": true,
		"why": "Hunting hard runs on mitochondria."},
	"calcium_signalling": {"tier": "easy", "type": "event", "key": "seep", "need": 5, "text": "Drink from 5 mineral seeps",
		"icon": "res://assets/biocrystal.png",
		"why": "Seawater is where cells first learned to use calcium."},
	"calcite_lenses": {"tier": "easy", "type": "eat", "species": TRILOBITES, "need": 10, "text": "Eat 10 trilobites",
		"icon": "res://assets/fauna/isotelus_sheet.png", "sheet": true,
		"why": "Trilobites saw through calcite lenses."},
	"regeneration": {"tier": "easy", "type": "event", "key": "hatch", "need": 1, "text": "Hatch from your clutch",
		"icon": "res://assets/item_cells.png",
		"why": "A young one grows from a few stem cells."},
	"bone": {"tier": "medium", "type": "eat", "species": JAWLESS_FISH, "need": 5, "text": "Eat 5 armoured jawless fish",
		"icon": "res://assets/fauna/sacabambaspis_sheet.png", "sheet": true,
		"why": "Bone first appeared as the armour of jawless fish."},
	"calcite_spines": {"tier": "medium", "type": "eat", "species": ECHINODERMS, "need": 5, "text": "Eat 5 echinoderms",
		"icon": "res://assets/lineages/spiny_echinozoan_sheet.png", "sheet": true,
		"why": "Every urchin spine is one calcite crystal."},
	"electric_organ": {"tier": "medium", "type": "boss", "floor": 2, "text": "Defeat the Cambrian boss",
		"icon": "res://assets/boss_anomalocaris.png",
		"why": "A body that can take on Anomalocaris has power to spare."},
	"haemoglobin": {"tier": "medium", "type": "reach", "floor": 3, "clade": "pikaia_chordate", "text": "Reach the Ordovician as a chordate",
		"icon": "res://assets/lineages/pikaia_chordate_sheet.png", "sheet": true,
		"why": "Red, iron-carrying blood is the vertebrate way."},
	"zinc_enzymes": {"tier": "medium", "type": "fossils", "need": 25, "text": "Find 25 fossils",
		"icon": "res://assets/eras/ordovician/fossil.png",
		"why": "A broad diet needs many enzymes."},
	"copper_myelin": {"tier": "medium", "type": "event", "key": "sketch", "need": 5, "text": "Sketch 5 animals from life",
		"icon": "res://assets/item_eye.png",
		"why": "Fast nerves for a watcher's quick reactions."},
	"magnetite_teeth": {"tier": "hard", "type": "eat", "species": MOLLUSCS, "need": 15, "text": "Eat 15 molluscs",
		"icon": "res://assets/fauna/orthoceras_sheet.png", "sheet": true,
		"why": "Chitons, molluscs, cap their teeth with magnetite."},
	"zinc_jaws": {"tier": "hard", "type": "eat", "species": CHELICERATES, "need": 8, "text": "Eat 8 sea scorpions, scorpions or spiders",
		"icon": "res://assets/fauna/pulmonoscorpius_sheet.png", "sheet": true,
		"why": "Their fangs and stings are hardened with zinc."},
	"sulfated_slime": {"tier": "hard", "type": "eat", "species": ["Helenodora"], "need": 5, "text": "Eat 5 velvet worms",
		"icon": "res://assets/fauna/helenodora_sheet.png", "sheet": true,
		"why": "Velvet worms squirt sticky slime."},
	"hemocyanin": {"tier": "hard", "type": "reach", "floor": 4, "clade": "early_arthropod", "text": "Reach the Carboniferous as an arthropod",
		"icon": "res://assets/lineages/early_arthropod_sheet.png", "sheet": true,
		"why": "Arthropods carry oxygen on copper: blue blood."},
	"zinc_venom": {"tier": "hard", "type": "reach", "floor": 5, "clade": "arachnid", "text": "Reach the Permian as an arachnid",
		"icon": "res://assets/lineages/arachnid_sheet.png", "sheet": true,
		"why": "Spider and scorpion venoms are zinc enzymes."},
	"keratin_horn": {"tier": "hard", "type": "won", "need": 1, "text": "Survive the Great Dying (win a run)",
		"icon": "res://assets/eras/permian/fossil.png",
		"why": "Horned beasts walked out of the Permian."},
}

const TIER_COLOR = {"easy": Color(0.55, 0.8, 0.45), "medium": Color(0.95, 0.75, 0.35), "hard": Color(0.95, 0.45, 0.35)}

static func goal(id: String) -> Dictionary:
	return GOALS.get(id, {})

# [have, need] towards a part's goal
static func progress_of(id: String, stats: Dictionary = {}) -> Array:
	var g = goal(id)
	if g.is_empty():
		return [1, 1]
	if stats.is_empty():
		stats = PROGRESS.stats()
	var need = int(g.get("need", 1))
	match g.type:
		"eat":
			var n := 0
			for sp in g.species:
				n += int(stats.get("eat:" + sp, 0))
			return [n, need]
		"eat_all":
			return [int(stats.get("eat_all", 0)), need]
		"event":
			return [int(stats.get(g.key, 0)), need]
		"boss":
			return [min(1, int(stats.get("boss:%d" % g.floor, 0))), 1]
		"reach":
			return [1 if reached(g.clade, int(g.floor), stats) else 0, 1]
		"won":
			return [min(need, PROGRESS.run_stats().wins), need]
		"fossils":
			return [preload("res://data/Codex.gd").load_eaten().size(), need]
	return [0, need]

# Reached a floor as a descendant of a form: from the kept maximum, or from
# the past runs page (so runs before this was added count too)
static func reached(clade: String, floor_n: int, stats: Dictionary) -> bool:
	if int(stats.get("reach:" + clade, 0)) >= floor_n:
		return true
	var R = preload("res://data/Reproduction.gd")
	for r in PROGRESS.history():
		var path: Array = r.get("path", [])
		if path.is_empty() or int(r.get("era", 0)) < floor_n:
			continue
		if R.ancestry(String(path[-1])).has(clade):
			return true
	return false

static func is_unlocked(id: String, stats: Dictionary = {}, ranks: Dictionary = {}) -> bool:
	if id in STARTERS or not GOALS.has(id):
		return true
	if int(ranks.get(id, 0)) > 0:
		return true
	var p = progress_of(id, stats)
	return p[0] >= p[1]

static func unlocked_ids() -> Array:
	var stats = PROGRESS.stats()
	var ranks = PROGRESS.lineage_ranks()
	var out: Array = []
	for r in preload("res://data/Biominerals.gd").lineage_recipes():
		if is_unlocked(r.id, stats, ranks):
			out.append(r.id)
	return out

# Picture for a goal: a sheet's first frame, or the whole image
static func icon_texture(g: Dictionary) -> Texture2D:
	var path: String = g.get("icon", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if not g.get("sheet", false):
		return tex
	var at = AtlasTexture.new()
	at.atlas = tex
	var frames = max(1, int(round(float(tex.get_width()) / tex.get_height())))
	at.region = Rect2(0, 0, tex.get_width() / float(frames), tex.get_height())
	return at
