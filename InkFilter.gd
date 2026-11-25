# InkFilter.gd
# The world's art style pass (data/ArtStyles.gd holds the shaders; the style
# is picked on the main menu and saved in SettingsManager.art_style). The
# default, described below, is the sepia sketch:
# Turns the world into a naturalist's sepia ink sketch: one full-screen pass
# over everything drawn below it (rooms, scenery, animals, the player) that
# maps light and dark onto paper and brown ink, keeps only a pale wash of the
# original colours, hatches the shadows with pen strokes, and inks every edge
# with a slightly wobbly line that redraws a few times a second like a
# hand-drawn animation. Sits in the VisionFog layer under the fog, so unseen
# parts of the room stay blank paper, and under the HUD.
extends ColorRect

const EraLook = preload("res://data/EraLook.gd")
const ArtStyles = preload("res://data/ArtStyles.gd")
var mat: ShaderMaterial
# Paper level to use outside a run (the main menu); below 0 follows the era
var fixed_light: float = -1.0
# Light tint over the floor outside a run (the main menu has no
# CanvasModulate); alpha 0 means read the run's CanvasModulate
var fixed_floor_tint: Color = Color(1, 1, 1, 0)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	material = mat
	apply_style(SettingsManager.art_style)
	SettingsManager.art_style_changed.connect(apply_style)

func apply_style(id: String):
	mat.shader = ArtStyles.shader(id)

# Each era's floor is a different brightness, so each sets where bare paper
# starts (EraLook "ink_light"): dark swamps still read as paper, not ink
var boil_time: float = 0.0

func _process(_delta: float):
	boil_time = fmod(boil_time + _delta, 64.0 / 6.0)
	var light: float = fixed_light
	var main = get_tree().current_scene
	if light < 0.0:
		if main == null or not ("floor_number" in main):
			return
		light = EraLook.get_look(main.floor_number).get("ink_light", 0.45)
	# Where the colour styles' flat floor key lands on screen (ArtStyles.floor_material)
	var st: Dictionary = ArtStyles.get_style(SettingsManager.art_style)
	if st.has("floor"):
		var tint: Color = fixed_floor_tint
		if tint.a == 0.0:
			var cm = main.get_node_or_null("CanvasModulate") if main else null
			tint = cm.color if cm else Color.WHITE
		var seen: Color = (st.floor * tint).clamp()
		mat.set_shader_parameter("floor_seen", Vector3(seen.r, seen.g, seen.b))
	else:
		mat.set_shader_parameter("floor_seen", Vector3(-1, -1, -1))
	# The sepia line redraws six times a second; the count wraps so it never grows large
	mat.set_shader_parameter("boil_step", floor(boil_time * 6.0))
	mat.set_shader_parameter("light_lum", light)
	mat.set_shader_parameter("dark_lum", light * 0.12)
