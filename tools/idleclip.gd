# idleclip.gd
# Frames of the player walking, then standing still, to judge the idle
# fidgets (PlayerBody: glance, resettle feet, flick fins). Saves every 2nd
# frame as <form>_<n>.png in SHOT_DIR. Needs a window and --fixed-fps 60:
#   SHOT_DIR=<folder> FORMS=id,id godot --fixed-fps 60 --path . --rendering-driver opengl3 -s res://tools/idleclip.gd
extends "res://tools/motionstrip.gd"

func plan(f: int) -> Array:
	return ["move_right"] if f < 40 else []

func _init():
	pass
