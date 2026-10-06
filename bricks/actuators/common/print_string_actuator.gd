@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Unreal-familiar Print String action. Generates native GDScript print().

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Print String"

func _initialize_properties() -> void:
	properties = {"text": "Hello from GDBlueprints!", "text_expression": "", "as_warning": false}

func get_property_definitions() -> Array:
	return [
		{"name": "text", "type": TYPE_STRING, "default": "Hello from GDBlueprints!"},
		{"name": "as_warning", "type": TYPE_BOOL, "default": false},
	]

func get_brick_info() -> Dictionary:
	return {
		"class": "PrintStringActuator",
		"name": "Print String",
		"type": "actuator",
		"category": "Utilities / Debug",
		"description": "Prints text to Godot's Output panel. Unreal: Print String. GDScript: print().",
		"menu_order": 1,
		"aliases": ["Print", "Print Text", "Debug Print", "PrintString"],
		"godot_term": "GDScript: print() / push_warning()"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Unreal: Print String\nGodot/GDScript: print(\"text\")\nUse this as the easiest test that your Blueprint compiled and executed.",
		"text": "Text written to Godot's Output panel.",
		"as_warning": "Use push_warning() instead of print(), so the message appears as a warning."
	}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	var expression := str(properties.get("text_expression", "")).strip_edges()
	var code := ""
	if not expression.is_empty():
		code = "push_warning(str(%s))" % expression if bool(properties.get("as_warning", false)) else "print(%s)" % expression
	else:
		var text = _gd_string(str(properties.get("text", "")))
		code = "push_warning(\"%s\")" % text if bool(properties.get("as_warning", false)) else "print(\"%s\")" % text
	return {"actuator_code": code}
