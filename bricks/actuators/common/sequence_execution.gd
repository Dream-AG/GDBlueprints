@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Sequence"

func get_brick_info() -> Dictionary:
	return {"class":"SequenceExecution","name":"Sequence","type":"actuator","category":"Flow","domain":"common","description":"Runs Then 0 through Then 3 in order, waiting for each connected path to finish. Unconnected outputs are skipped. Chain another Sequence for more outputs.","godot_term":"Ordered GDScript calls with await"}

func get_exec_output_definitions() -> Array:
	return [{"name":"Then 0","id":"then_0"},{"name":"Then 1","id":"then_1"},{"name":"Then 2","id":"then_2"},{"name":"Then 3","id":"then_3"}]

func get_execution_spec() -> Dictionary:
	return {"kind":"sequence"}
