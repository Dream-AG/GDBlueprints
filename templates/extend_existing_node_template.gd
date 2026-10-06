@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/print_string_actuator.gd"

## Copy this file into res://gdblueprints_nodes/ and rename it.
## Inheriting keeps your changes outside the addon so upgrades cannot replace them.

func _initialize_properties() -> void:
	super._initialize_properties()
	properties["prefix"] = "[Game] "

func get_brick_info() -> Dictionary:
	var info: Dictionary = super.get_brick_info().duplicate(true)
	info.merge({
		"class": "PrefixedPrintStringActuator",
		"name": "Print String (Prefixed)",
		"category": "Game / Debug",
		"description": "Prints text with a project-specific prefix.",
		"aliases": ["Print", "Prefixed Print"],
		"godot_term": "GDScript: print(prefix + text)"
	}, true)
	return info

func get_property_definitions() -> Array:
	var definitions: Array = super.get_property_definitions().duplicate(true)
	definitions.append({"name": "prefix", "type": TYPE_STRING, "default": "[Game] "})
	return definitions

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var previous_expression: String = str(properties.get("text_expression", ""))
	var text_expression := previous_expression.strip_edges()
	if text_expression.is_empty():
		text_expression = '"%s"' % _gd_string(str(properties.get("text", "")))
	properties["text_expression"] = '"%s" + str(%s)' % [_gd_string(str(properties.get("prefix", ""))), text_expression]
	var generated: Dictionary = super.generate_code(node, chain_name)
	properties["text_expression"] = previous_expression
	return generated
