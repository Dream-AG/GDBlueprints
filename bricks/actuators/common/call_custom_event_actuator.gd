@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"
const Signature = preload("res://addons/GDBlueprints/core/event_signature.gd")

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Call Custom Event"

func _initialize_properties() -> void:
	properties = {"event_name":"my_event", "target":"self", "target_expression":"", "parameters":"", "_applied_parameters":""}

func get_property_definitions() -> Array:
	var result: Array = [
		{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object"},
		{"name":"event_name", "type":TYPE_STRING, "default":"my_event", "blueprint_pin":false, "required":true, "required_label":"Event Name"}
	]
	result.append(Signature.property_definition())
	for parameter in Signature.parameters(properties):
		var initial := Signature.Variables.to_gdscript_value_literal(Signature.Variables.get_default_value_for_variable_type(parameter.type), parameter.type)
		result.append({"name":"argument_" + parameter.name, "type":TYPE_STRING, "default":initial, "blueprint_pin":true, "pin_type":parameter.type, "pin_label":parameter.name})
	return result

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var result := super.get_configuration_warnings(node)
	result.append_array(Signature.warnings(properties))
	return result

func get_tooltip_definitions() -> Dictionary:
	return {"parameters":"Copy the event's name: Type pairs, then click Apply Parameters. Argument fields accept GDScript expressions; use quotes for text literals."}

func get_brick_info() -> Dictionary:
	return {
		"class":"CallCustomEventActuator",
		"name":"Call Custom Event",
		"type":"actuator",
		"category":"Events",
		"description":"Calls a named Custom Event on Self or another node with typed argument pins. The target's method signature is checked before dispatch; Then continues after dispatch, without waiting for delayed event work.",
		"menu_order":5,
		"aliases":["Call Event", "Trigger Event", "Invoke Event", "Call Custom Event"],
		"godot_term":"GDScript: target.call(\"event_name\")"
	}

func generate_code(_node: Node, chain_name: String) -> Dictionary:
	var arguments: Array[String] = []
	for parameter in Signature.parameters(properties):
		var key := "argument_" + str(parameter.name)
		var initial := Signature.Variables.to_gdscript_value_literal(Signature.Variables.get_default_value_for_variable_type(parameter.type), parameter.type)
		var expression := str(properties.get(key + "_expression", "")).strip_edges()
		if expression.is_empty(): expression = str(properties.get(key, initial)).strip_edges()
		arguments.append(expression if not expression.is_empty() else initial)
	var event_name := Signature.event_identifier(str(properties.get("event_name", "my_event")))
	var target_expression := str(properties.get("target_expression", "")).strip_edges()
	if target_expression.is_empty():
		var target_text := str(properties.get("target", "self")).strip_edges()
		if target_text.is_empty() or target_text.to_lower() == "self":
			target_expression = "self"
		else:
			target_expression = "get_node_or_null(\"%s\")" % _gd_string(target_text)
	var local := "_bfg_event_target_%s" % _unique_label(chain_name)
	var code := "var %s = %s\npreload(\"res://addons/GDBlueprints/core/event_dispatch.gd\").dispatch(%s, \"%s\", [%s])" % [local, target_expression, local, event_name, ", ".join(arguments)]
	return {"actuator_code":code}
