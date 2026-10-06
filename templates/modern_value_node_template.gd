@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Example pure value template. Pure output expressions must be side-effect free.

func _init() -> void:
	super._init()
	brick_type = BrickType.VALUE
	brick_name = "Example Value"

func _initialize_properties() -> void:
	properties = {}

func get_brick_info() -> Dictionary:
	return {
		"class":"ExampleValue",
		"name":"Example Value",
		"type":"value",
		"category":"Examples",
		"description":"Contributor template pure value.",
		"aliases":["Example Value"],
		"godot_term":"GDScript: Vector3.ZERO",
		"menu_order":9990,
	}

func get_property_definitions() -> Array:
	return []

func get_value_output_definitions() -> Array:
	return [
		{"name":"Value", "type":"Vector3", "expression":"Vector3.ZERO"}
	]
