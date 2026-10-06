@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Break"

func get_brick_info() -> Dictionary:
	return {"class":"BreakExecution","name":"Break","type":"actuator","category":"Flow","domain":"common","description":"Stops the innermost active loop and runs its Completed path. Remaining actions in that loop body are skipped. An event path outside a loop is a compile error.","godot_term":"GDScript break"}

func get_exec_output_definitions() -> Array:
	return []

func get_execution_spec() -> Dictionary:
	return {"kind":"break"}
