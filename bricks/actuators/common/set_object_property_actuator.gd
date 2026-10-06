@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Writes a native Object property using Object.set().

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Set Object Property"

func _initialize_properties() -> void:
	properties = {
		"target":"self",
		"target_expression":"",
		"property_name":"text",
		"value":"",
		"value_expression":""
	}

func get_property_definitions() -> Array:
	return [
		{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object", "pin_label":"Target"},
		{"name":"property_name", "type":TYPE_STRING, "default":"text", "blueprint_pin":false, "required":true, "required_label":"Property Name"},
		{"name":"value", "type":TYPE_STRING, "default":"", "blueprint_pin":true, "pin_type":str(properties.get("_property_type", "Variant")), "pin_label":"Value"}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"SetObjectPropertyActuator",
		"name":"Set Object Property",
		"type":"actuator",
		"category":"References / Properties",
		"description":"Changes an Inspector/script property on another live Godot Object using Object.set().",
		"menu_order":11,
		"aliases":["Set Property", "Set Member", "Set Inspector Property", "Set Variable On Object"],
		"godot_term":"Godot/GDScript: target.set(\"property\", value)"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Set a native Godot property on another object. Example: drag Label into the graph, connect it to Target, enter property_name = text, and feed a String into Value.",
		"target":"The live Object/Node to modify.",
		"property_name":"Native Godot property name, such as text, disabled, visible, value, position, or modulate.",
		"value":"Fallback manual value. For non-String values, connect a typed data wire so GDBlueprints passes the real Variant value."
	}

func _target_expression() -> String:
	var expression := str(properties.get("target_expression", "")).strip_edges()
	if not expression.is_empty():
		return expression
	var target_text := str(properties.get("target", "self")).strip_edges()
	if target_text.is_empty() or target_text.to_lower() == "self":
		return "self"
	return "get_node_or_null(\"%s\")" % _gd_string(target_text)

func _value_expression() -> String:
	var expression := str(properties.get("value_expression", "")).strip_edges()
	if not expression.is_empty():
		return expression
	return "\"%s\"" % _gd_string(str(properties.get("value", "")))

func generate_ir(_node: Node, _chain_name: String) -> Dictionary:
	var code := 'preload("res://addons/GDBlueprints/core/property_access.gd").set_checked(%s, %s, %s)' % [_target_expression(), var_to_str(str(properties.property_name)), _value_expression()]
	return {"actuator":[{"op":"statement", "code":code}]}
