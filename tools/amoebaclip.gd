# amoebaclip.gd
# Frames of the starter amoeba crawling right, turning down, stopping,
# shooting a few times, then crawling off left, to judge the crawl cycle
# (PlayerBody.cell_amoeba). Saves every frame as <form>_<n>.png in SHOT_DIR.
# Needs a window and --fixed-fps 60:
#   SHOT_DIR=<folder> FRAMES=260 STEP=1 godot --fixed-fps 60 --path . --rendering-driver opengl3 -s res://tools/amoebaclip.gd
extends "res://tools/motionstrip.gd"

func plan(f: int) -> Array:
	if f < 80:
		return ["move_right"]
	if f < 125:
		return ["move_down"]
	if f < 150:
		return []
	if f < 190:
		return ["shoot_right"]
	if f < 200:
		return []
	return ["move_left"]

func _init():
	pass
