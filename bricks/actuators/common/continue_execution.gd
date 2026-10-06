@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/break_execution.gd"

func _init() -> void:
	super._init()
	brick_name = "Continue"

func get_brick_info() -> Dictionary:
	return {"class":"ContinueExecution","name":"Continue","type":"actuator","category":"Flow","domain":"common","description":"Skips the rest of the innermost loop body and advances to its next iteration. An event path outside a loop is a compile error.","godot_term":"GDScript continue"}

func get_execution_spec() -> Dictionary:
	return {"kind":"continue"}
