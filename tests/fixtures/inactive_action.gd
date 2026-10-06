@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Inactive action test fixture"

func get_brick_info() -> Dictionary:
	return {"class":"TestInactiveAction","name":"Inactive action test fixture","type":"actuator","category":"Tests","description":"Runtime fixture for continuous inactive updates.","godot_term":"Conditional per-frame updates"}

func generate_code(_node: Node, _namespace: String) -> Dictionary:
	return {"actuator_code":'record("active")',"inactive_code":'record("inactive")'}
