# amoebaclip.gd
# Frames of the starter amoeba crawling right, turning down, then resting,
# to judge the crawl cycle (PlayerBody.cell_amoeba). Saves every frame as
# <form>_<n>.png in SHOT_DIR. Needs a window and --fixed-fps 60:
#   SHOT_DIR=<folder> FRAMES=150 STEP=1 godot --fixed-fps 60 --path . --rendering-driver opengl3 -s res://tools/amoebaclip.gd
extends "res://tools/motionstrip.gd"

func plan(f: int) -> Array:
	if f < 75:
		return ["move_right"]
	if f < 115:
		return ["move_down"]
	return []

func _init():
	pass
