@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Set Local"

func _initialize_properties() -> void:
	properties = {"local_name":"value", "value":"0", "value_expression":""}

func get_brick_info() -> Dictionary:
	return {"class":"SetFunctionLocal", "name":"Set Local", "type":"actuator", "category":"Functions", "description":"Assigns a declared local in the current function invocation. Other calls, including recursive calls, have independent locals. Read locals from Function Entry output pins.", "godot_term":"GDScript: local_name = value", "aliases":["Set Function Local"]}

func get_property_definitions() -> Array:
	return [{"name":"local_name", "type":TYPE_STRING, "default":"value", "blueprint_pin":false, "required":true}, {"name":"value", "type":TYPE_STRING, "default":"0", "blueprint_pin":true, "pin_type":"Variant"}]

func get_execution_spec() -> Dictionary:
	var expression := str(properties.get("value_expression", "")).strip_edges()
	if expression.is_empty(): expression = str(properties.get("value", "0")).strip_edges()
	return {"kind":"set_local", "local_name":str(properties.local_name), "value":expression if not expression.is_empty() else "null"}
