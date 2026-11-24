# Traces.gd
# Trace fossils: the tracks, trails and resting marks animals leave in the
# sediment. Palaeontologists name them as their own genera (ichnogenera),
# because the same track can be made by different animals and the maker is
# seldom found in it. In the game you and the animals leave them as you
# move (rooms/TraceLayer.gd); the first time you see each kind it goes into
# the fossil record's TRACES page.
#
# kind: how it is drawn (draw_mark). gap: distance between marks at size 1.
extends RefCounted

const INK = Color(0.24, 0.15, 0.08)

const TRACES = {
	"kimberichnus": {"name": "Kimberichnus", "maker": "Kimberella", "kind": "scratch", "gap": 34.0,
		"short": "Kimberella's feeding scratches",
		"fact": "Fans of paired scratches raked into the Ediacaran microbial mat by Kimberella as it fed, often found right beside the animal itself. They are some of the oldest traces of an animal feeding."},
	"epibaion": {"name": "Epibaion", "maker": "Dickinsonia", "kind": "oval", "gap": 120.0,
		"short": "where Dickinsonia lay and fed",
		"fact": "A row of faint, Dickinsonia-shaped imprints. Dickinsonia lay on the microbial mat and digested it through its underside, then moved on a little and lay down again."},
	"radulichnus": {"name": "Radulichnus", "maker": "grazing molluscs", "kind": "rasp", "gap": 30.0,
		"short": "a mollusc's radula grazing",
		"fact": "Rows of tiny paired scrapes left by a radula, the ribbon of rasping teeth that molluscs graze with, scraping a film of microbes or algae off the sea floor."},
	"archaeonassa": {"name": "Archaeonassa", "maker": "snails and other creepers", "kind": "trail", "gap": 14.0,
		"short": "a creeping snail's trail",
		"fact": "A smooth groove between two low ridges, ploughed by a snail or another soft animal creeping through the top of the sediment. Trails like it run through rocks from the end of the Ediacaran on."},
	"lockeia": {"name": "Lockeia", "maker": "clams", "kind": "almond", "gap": 64.0,
		"short": "where a clam dug in",
		"fact": "Small almond-shaped hollows where a clam settled into the sand on its muscular foot, then shuffled on and settled again."},
	"asteriacites": {"name": "Asteriacites", "maker": "sea stars and brittle stars", "kind": "star", "gap": 130.0,
		"short": "a sea star's resting print",
		"fact": "A five-armed, star-shaped hollow where a sea star or brittle star sat half-buried in the sand. Brittle stars in shallow seas today leave exactly the same marks."},
	"diplichnites": {"name": "Diplichnites", "maker": "many-legged arthropods", "kind": "pairs", "gap": 20.0,
		"short": "an arthropod's walking track",
		"fact": "Two rows of small leg prints left by a walking arthropod. The biggest, Diplichnites cuithensis from the Carboniferous, is up to half a metre wide: the trackway of the giant millipede relative Arthropleura."},
	"cruziana": {"name": "Cruziana", "maker": "trilobites", "kind": "furrow", "gap": 16.0,
		"short": "a trilobite's ploughed furrow",
		"fact": "A long two-lobed furrow, scored with V-shaped leg scratches, ploughed by a trilobite through the sea floor. It is so common in Cambrian and Ordovician rocks that geologists use the different kinds to tell the age of the rock."},
	"rusophycus": {"name": "Rusophycus", "maker": "trilobites", "kind": "rest", "gap": 96.0,
		"short": "where a trilobite dug in",
		"fact": "A two-lobed, coffee-bean shaped hollow where a trilobite dug in to rest or hide. Some are found with a worm burrow running into them: a trilobite caught in the act of hunting."},
	"palmichnium": {"name": "Palmichnium", "maker": "sea scorpions", "kind": "paddle", "gap": 32.0,
		"short": "a sea scorpion's trackway",
		"fact": "The broad trackway of a sea scorpion pushing along on its legs, with the drag of its tail between them. A Carboniferous trackway in Scotland shows that the giant sea scorpion Hibbertopterus could walk out of the water."},
	"kouphichnium": {"name": "Kouphichnium", "maker": "horseshoe crabs", "kind": "tail", "gap": 22.0,
		"short": "a horseshoe crab and its tail drag",
		"fact": "Rows of prints with a line dragged down the middle by the tail spine. Some Jurassic ones end at the body of the horseshoe crab that made them, which died in its tracks."},
	"paleohelcura": {"name": "Paleohelcura", "maker": "scorpions", "kind": "sting", "gap": 28.0,
		"short": "a scorpion's trackway",
		"fact": "Little clusters of prints either side of a dragged tail: the trackway of a scorpion. Many come from the Permian desert dunes of the Coconino Sandstone in Arizona."},
	"octopodichnus": {"name": "Octopodichnus", "maker": "spiders", "kind": "eight", "gap": 28.0,
		"short": "four prints a side: a spider",
		"fact": "Four prints a side in neat little sets: a spider's trackway, first named from Permian sand dunes in Arizona. Living spiders walked across sand leave the same pattern."},
	"tonganoxichnus": {"name": "Tonganoxichnus", "maker": "jumping bristletails", "kind": "hop", "gap": 48.0,
		"short": "a wingless insect's prints",
		"fact": "Leg prints round a small body imprint, left by jumping bristletails (wingless insects) on a Carboniferous tidal flat in Kansas. They are some of the oldest trace fossils of insects."},
	"undichna": {"name": "Undichna", "maker": "fish", "kind": "wave", "gap": 12.0,
		"short": "a fish's fin drawn in the mud",
		"fact": "Wavy lines drawn in the mud by the fins of a fish swimming close to the bottom. Some are so clear that the shape of the fish's fins can be worked out from them."},
	"zachelmie": {"name": "Zachelmie tracks", "maker": "the first four-legged animals", "kind": "feet", "gap": 40.0, "toes": 5,
		"short": "the first footprints",
		"fact": "Footprints with digits, pressed into a lagoon in Poland about 395 million years ago. Found in 2010, they are older than any skeleton of a four-legged animal yet known."},
	"batrachichnus": {"name": "Batrachichnus", "maker": "small amphibians", "kind": "feet", "gap": 34.0, "toes": 4,
		"short": "a small amphibian's footprints",
		"fact": "Little four-fingered hand prints and five-toed foot prints of small temnospondyl amphibians, very common on Carboniferous and Permian mudflats."},
	"limnopus": {"name": "Limnopus", "maker": "big amphibians like Eryops", "kind": "feet", "gap": 52.0, "toes": 4,
		"short": "a big amphibian's footprints",
		"fact": "Large, four-fingered prints of big temnospondyl amphibians such as Eryops, waddling over Permian riverbanks."},
	"dimetropus": {"name": "Dimetropus", "maker": "sail-backed synapsids", "kind": "feet", "gap": 46.0, "toes": 5, "long": true,
		"short": "a Dimetrodon-kind's footprints",
		"fact": "Long-fingered, five-toed prints of early synapsids like Dimetrodon, walking with their legs sprawled out to the sides and the tail sometimes dragging."},
	"dicynodontipus": {"name": "Dicynodontipus", "maker": "tusked dicynodonts", "kind": "feet", "gap": 40.0, "toes": 5, "stubby": true,
		"short": "a dicynodont's footprints",
		"fact": "Broad, short-toed prints of therapsids such as the tusked dicynodonts. Their feet sat closer under the body than in earlier synapsids, so the prints run in a narrower track."},
	"hyloidichnus": {"name": "Hyloidichnus", "maker": "captorhinid reptiles", "kind": "feet", "gap": 30.0, "toes": 5, "long": true,
		"short": "a small reptile's footprints",
		"fact": "Small five-toed prints with slender, curved toes, thought to be made by captorhinid reptiles like Captorhinus, scurrying over Permian sand."},
}

# Each form takes the trace of the nearest ancestor (or itself) listed here;
# "" means it leaves none (it swims or flies clear of the bottom)
const BY_FORM = {
	"ancestral_collar_cell": "",
	"pikaia_chordate": "",
	"early_echinoderm": "",
	"free_moving_echinoderm": "asteriacites",
	"spiny_echinozoan": "",
	"early_mollusc": "radulichnus",
	"sea_snail": "archaeonassa",
	"bivalve": "lockeia",
	"cephalopod": "",
	"early_arthropod": "diplichnites",
	"chelicerate": "palmichnium",
	"horseshoe_crab": "kouphichnium",
	"arachnid": "octopodichnus",
	"scorpion": "paleohelcura",
	"hexapod": "tonganoxichnus",
	"dragonfly_line": "",
	"jawless_fish": "undichna",
	"jawed_fish": "undichna",
	"lobe_finned_shorewalker": "zachelmie",
	"lissamphibian": "batrachichnus",
	"synapsid": "dimetropus",
	"sauropsid": "hyloidichnus",
}

# Era animals and bosses by name; these win over their drawn form
const BY_NAME = {
	"Kimberella": "kimberichnus", "Dickinsonia": "epibaion", "Spriggina": "", "Arkarua": "",
	"Olenoides": "cruziana", "Wiwaxia": "radulichnus", "Marrella": "", "Waptia": "", "Opabinia": "",
	"Sanctacaris": "diplichnites", "Sidneyia": "diplichnites", "Anomalocaris": "", "Plectronoceras": "",
	"Isotelus": "rusophycus", "Megalograptus": "palmichnium", "Pentecopterus": "palmichnium",
	"Lunataspis": "kouphichnium", "Petraster": "asteriacites", "Maclurites": "archaeonassa",
	"Sacabambaspis": "undichna", "Arandaspis": "undichna", "Orthoceras": "", "Cameroceras": "",
	"Pulmonoscorpius": "paleohelcura", "Arthrolycosa": "octopodichnus", "Euphoberia": "diplichnites",
	"Latzelia": "diplichnites", "Arthropleura": "diplichnites", "Orthacanthus": "undichna",
	"Rhizodus": "undichna", "Meganeura": "", "Archimylacris": "", "Helenodora": "", "Hylonomus": "",
	"Cacops": "batrachichnus", "Eryops": "limnopus", "Edaphosaurus": "dimetropus", "Dimetrodon": "dimetropus",
	"Lystrosaurus": "dicynodontipus", "Diictodon": "dicynodontipus", "Captorhinus": "hyloidichnus",
	"Inostrancevia": "", "Euchambersia": "", "Permocupes": "", "Stentor": "", "Salpingoeca": "", "Charnia": "", "Fractofusus": "",
}

static func for_form(form_id: String) -> String:
	var line: Array = preload("res://data/Reproduction.gd").ancestry(form_id)
	for i in range(line.size() - 1, -1, -1):
		if BY_FORM.has(line[i]):
			return BY_FORM[line[i]]
	return ""

static func for_animal(animal_name: String, form_id: String = "") -> String:
	if BY_NAME.has(animal_name):
		return BY_NAME[animal_name]
	if form_id != "":
		return for_form(form_id)
	return ""

static func gap(id: String) -> float:
	return TRACES[id].gap if TRACES.has(id) else 30.0

static func all_ids() -> Array:
	return TRACES.keys()

# ---- Drawing ----
# One mark in the sediment at `pos`, heading `angle`; `side` alternates +1/-1
# from mark to mark (left and right feet), `phase` is the distance walked
# (wavy fin lines), `s` the animal's size and `a` the fade.
static func draw_mark(ci: CanvasItem, id: String, pos: Vector2, angle: float, side: float, phase: float, s: float, a: float):
	if not TRACES.has(id) or a <= 0.01:
		return
	var t: Dictionary = TRACES[id]
	var ink = Color(INK, 0.85 * a)
	var hollow = Color(0.2, 0.13, 0.07, 0.26 * a)
	var g: float = t.gap
	ci.draw_set_transform(pos, angle, Vector2(s, s))
	match t.kind:
		"pairs":
			# Two rows of small slanted leg prints
			for y in [-9.0, 9.0]:
				var x = side * 4.0
				ci.draw_line(Vector2(x - 2.5, y - sign(y) * 1.5), Vector2(x + 2.5, y + sign(y) * 1.5), ink, 2.2, true)
				ci.draw_line(Vector2(x - 8.0, y + sign(y) * 0.5), Vector2(x - 4.5, y + sign(y) * 2.5), ink, 1.6, true)
		"furrow":
			# Two lobes, each with V scratches
			_ell(ci, Vector2(-g * 0.5, 0), g * 0.62, 9.0, hollow, Color(0, 0, 0, 0))
			ci.draw_line(Vector2(-g, 0), Vector2(0, 0), Color(INK, 0.55 * a), 1.2, true)
			for y in [-1.0, 1.0]:
				ci.draw_line(Vector2(-g, y * 9.0), Vector2(0, y * 9.0), Color(INK, 0.6 * a), 1.2, true)
				ci.draw_line(Vector2(-g * 0.2, y * 1.5), Vector2(-g * 0.7, y * 7.5), ink, 1.5, true)
		"rest":
			for y in [-6.5, 6.5]:
				_ell(ci, Vector2(0, y), 13.0, 6.5, hollow, ink)
				for k in 3:
					var x = -6.0 + k * 6.0
					ci.draw_line(Vector2(x - 2.0, y - sign(y) * 4.0), Vector2(x + 2.0, y + sign(y) * 3.0), Color(INK, 0.55 * a), 1.0, true)
		"scratch":
			# A fan of paired scratches, raked back toward the body
			for k in 5:
				var ang = PI + (k - 2) * 0.28
				var d = Vector2.from_angle(ang)
				for o in [-1.6, 1.6]:
					var off = d.orthogonal() * o
					ci.draw_line(d * 6.0 + off, d * 20.0 + off, ink, 1.2, true)
		"rasp":
			for k in 3:
				var x = -k * 7.0
				ci.draw_line(Vector2(x, -5.0), Vector2(x - 3.0, -1.0), ink, 1.4, true)
				ci.draw_line(Vector2(x, 5.0), Vector2(x - 3.0, 1.0), ink, 1.4, true)
		"oval":
			# The animal's outline, quilted, laid on the mat
			_ell(ci, Vector2.ZERO, 26.0, 19.0, hollow, ink)
			ci.draw_line(Vector2(-24.0, 0), Vector2(24.0, 0), Color(INK, 0.65 * a), 1.2, true)
			for k in 7:
				var x = -18.0 + k * 6.0
				var h = 17.0 * sqrt(max(0.0, 1.0 - pow(x / 26.0, 2)))
				ci.draw_line(Vector2(x, -h), Vector2(x, h), Color(INK, 0.45 * a), 1.0, true)
		"trail":
			ci.draw_line(Vector2(-g - 1.0, 0), Vector2(0, 0), ink, 2.0, true)
			for y in [-5.5, 5.5]:
				ci.draw_line(Vector2(-g - 1.0, y), Vector2(0, y), Color(INK, 0.45 * a), 1.2, true)
		"almond":
			_ell(ci, Vector2(0, side * 4.0), 11.0, 5.0, hollow, ink)
			ci.draw_line(Vector2(-7.0, side * 4.0), Vector2(7.0, side * 4.0), Color(INK, 0.55 * a), 1.0, true)
		"star":
			for k in 5:
				var d = Vector2.from_angle(TAU * k / 5.0 + phase * 0.01)
				var tip = d * 22.0
				var n = d.orthogonal() * 3.5
				var arm = PackedVector2Array([d * 4.0 + n, tip, d * 4.0 - n])
				ci.draw_colored_polygon(arm, hollow)
				ci.draw_polyline(arm, ink, 1.2, true)
			_ell(ci, Vector2.ZERO, 6.0, 6.0, hollow, ink)
		"tail":
			# Paired prints and the tail-spine drag down the middle
			ci.draw_line(Vector2(-g - 1.0, 0), Vector2(0, 0), Color(INK, 0.65 * a), 1.3, true)
			for y in [-10.0, 10.0]:
				ci.draw_circle(Vector2(side * 3.0, y), 2.2, ink)
				ci.draw_circle(Vector2(side * 3.0 - 5.0, y * 0.75), 1.6, ink)
		"paddle":
			ci.draw_line(Vector2(-g - 1.0, 0), Vector2(0, 0), Color(INK, 0.55 * a), 1.2, true)
			for y in [-14.0, 14.0]:
				ci.draw_line(Vector2(side * 4.0 - 6.0, y), Vector2(side * 4.0 + 4.0, y * 0.85), ink, 2.6, true)
				ci.draw_circle(Vector2(side * 4.0 - 10.0, y * 0.6), 1.7, ink)
		"sting":
			if side > 0.0:
				ci.draw_line(Vector2(-g * 0.5, 0), Vector2(0, 0), Color(INK, 0.65 * a), 1.2, true)
			for y in [-10.0, 10.0]:
				for k in 3:
					ci.draw_circle(Vector2(side * 3.0 - k * 4.0, y + sign(y) * k * 1.5), 1.6, ink)
		"eight":
			for y in [-8.0, 8.0]:
				for k in 4:
					ci.draw_circle(Vector2(side * 2.0 + 6.0 - k * 4.5, y + sign(y) * (abs(k - 1.5) * -1.2 + 2.0)), 1.4, ink)
		"hop":
			_ell(ci, Vector2(-2.0, 0), 7.0, 3.0, hollow, Color(INK, 0.6 * a))
			for y in [-7.0, 7.0]:
				for k in 3:
					ci.draw_circle(Vector2(5.0 - k * 5.0, y + sign(y) * k * 1.2), 1.5, ink)
		"wave":
			# The fin's sweep, drawn on from the last mark
			var pts := PackedVector2Array()
			for k in 5:
				var x = -g * (1.0 - k / 4.0) - 1.0
				pts.append(Vector2(x, sin((phase + x) * 0.045) * 11.0))
			ci.draw_polyline(pts, ink, 1.6, true)
		"feet":
			# Alternating hand and foot prints with toes
			var toes: int = t.get("toes", 5)
			var long: bool = t.get("long", false)
			var stubby: bool = t.get("stubby", false)
			var y = side * (9.0 if stubby else 12.0)
			var palm = Vector2(0, y)
			_ell(ci, palm, 4.5, 4.0, hollow, ink)
			var tl = 4.0 if stubby else (8.0 if long else 6.0)
			for k in toes:
				var spread = (k - (toes - 1) * 0.5) * (0.42 if not stubby else 0.34)
				var d = Vector2.from_angle(spread + side * 0.15)
				ci.draw_line(palm + d * 3.5, palm + d * (3.5 + tl), ink, 1.5 if not stubby else 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, line: Color):
	var pts := PackedVector2Array()
	for i in 14:
		var t = TAU * i / 14.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	if line.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, line, 1.2, true)

# A short sample trackway across a box, for the TRACES page
static func draw_sample(ci: CanvasItem, id: String, box: Rect2, a: float = 1.0):
	if not TRACES.has(id):
		return
	var g: float = TRACES[id].gap
	var s = clamp(box.size.y / 64.0, 0.6, 1.6)
	var y = box.position.y + box.size.y * 0.5
	var x = box.position.x + 18.0 * s
	var step = g * s
	if step > box.size.x * 0.45:
		# One big resting mark in the middle
		draw_mark(ci, id, box.get_center(), 0.0, 1.0, 0.0, s * 0.9, a)
		return
	var side := 1.0
	var walked := 0.0
	x += step
	while x < box.end.x - 6.0 * s:
		walked += g
		draw_mark(ci, id, Vector2(x, y), 0.0, side, walked, s, a)
		side = -side
		x += step
