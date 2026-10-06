@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Reads a property from any live Godot Object reference.
## This intentionally mirrors Object.get() instead of inventing a custom
## reflection layer, so it stays aligned with Godot's native object model.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Get Object Property"

func _initialize_properties() -> void:
	properties = {
		"target":"self",
		"target_expression":"",
		"property_name":"text"
	}

func get_property_definitions() -> Array:
	return [
		{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object", "pin_label":"Target"},
		{"name":"property_name", "type":TYPE_STRING, "default":"text", "blueprint_pin":false, "required":true, "required_label":"Property Name"}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"GetObjectPropertyActuator",
		"name":"Get Object Property",
		"type":"actuator",
		"category":"References / Properties",
		"description":"Reads an Inspector/script property from a live Godot Object, such as Label.text or Button.disabled.",
		"menu_order":10,
		"aliases":["Get Property", "Get Member", "Read Property", "Get Inspector Property", "Get Variable From Object"],
		"godot_term":"Godot/GDScript: target.get(\"property\")"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Read a property on another Godot object. For a known child such as $Label, drag the child from the Scene Tree into the graph and connect it to Target. Property Name uses the GDScript property name shown by Godot, such as text, disabled, visible, position, or value.",
		"target":"The live Object/Node whose property you want to read.",
		"property_name":"Native Godot property name, for example text on Label or disabled on Button."
	}

func _target_expression() -> String:
	var expression := str(properties.get("target_expression", "")).strip_edges()
	if not expression.is_empty():
		return expression
	var target_text := str(properties.get("target", "self")).strip_edges()
	if target_text.is_empty() or target_text.to_lower() == "self":
		return "self"
	return "get_node_or_null(\"%s\")" % _gd_string(target_text)

func _property_expression() -> String:
	var property_name := str(properties.get("property_name", "")).strip_edges()
	if property_name.is_empty():
		return "null"
	var target := _target_expression()
	return 'preload("res://addons/GDBlueprints/core/property_access.gd").get_checked(%s, %s)' % [target, var_to_str(property_name)]

func get_value_output_definitions() -> Array:
	var target := _target_expression()
	return [
		{"name":"Value", "type":str(properties.get("_property_type", "Variant")), "expression":_property_expression()},
		{"name":"Target Valid", "type":"Bool", "expression":"is_instance_valid(%s)" % target}
	]

func generate_ir(_node: Node, _chain_name: String) -> Dictionary:
	return {"actuator":[{"op":"statement", "code":"pass # Get Object Property uses its typed data outputs"}]}
