@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Copy this file into res://gdblueprints_nodes/ and rename the class metadata.
## Ordinary contributor nodes should not require edits to the panel or manager.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Example Action"

func _initialize_properties() -> void:
	properties = {
		"text": "Hello",
		"text_expression": "",
	}

func get_brick_info() -> Dictionary:
	return {
		"class":"ExampleActionActuator",
		"name":"Example Action",
		"type":"actuator",
		"category":"Examples",
		"description":"Contributor template action.",
		"aliases":["Example Action"],
		"godot_term":"GDScript: print(text)",
		"menu_order":9990,
	}

func get_property_definitions() -> Array:
	return [
		{"name":"text", "type":TYPE_STRING, "default":"Hello", "blueprint_pin":true, "pin_type":"String"}
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Small example showing the normal one-file contributor path.",
		"text":"Text to print. A connected String pin overrides the literal field."
	}

func generate_ir(_node: Node, _chain_name: String) -> Dictionary:
	var expression := str(properties.get("text_expression", "")).strip_edges()
	if expression.is_empty():
		expression = '"%s"' % _gd_string(str(properties.get("text", "Hello")))
	return {
		"actuator":[
			{"op":"call", "method":"print", "args":[expression]}
		]
	}
