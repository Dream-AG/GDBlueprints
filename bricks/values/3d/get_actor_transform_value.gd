@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Pure value node with multiple outputs, useful for testing Blueprint-style data flow.

func _init() -> void:
	super._init()
	brick_type = BrickType.VALUE
	brick_name = "Get Actor Transform"

func _initialize_properties() -> void:
	properties = {}

func get_property_definitions() -> Array:
	return []

func get_brick_info() -> Dictionary:
	return {
		"class":"GetActorTransformValue",
		"name":"Get Actor Transform",
		"type":"value",
		"category":"Actor / Transform",
		"description":"Pure value node exposing several properties of the current Node3D.",
		"menu_order":1,
		"domain":"3d",
		"aliases":["Get Actor Transform", "Get Actor Location", "Get Actor Rotation", "Get Actor Scale"],
		"godot_term":"Godot: global_transform / global_position / global_rotation / scale"
	}

func get_value_output_definitions() -> Array:
	return [
		{"name":"Name", "type":"String", "expression":"str(name)"},
		{"name":"Transform", "type":"Transform3D", "expression":"global_transform"},
		{"name":"Location", "type":"Vector3", "expression":"global_position"},
		{"name":"Rotation", "type":"Vector3", "expression":"global_rotation"},
		{"name":"Scale", "type":"Vector3", "expression":"scale"}
	]
