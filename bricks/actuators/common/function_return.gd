@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Return"

func _initialize_properties() -> void:
	properties = {"value":"null", "value_expression":""}

func get_brick_info() -> Dictionary:
	return {"class":"FunctionReturn", "name":"Return", "type":"actuator", "category":"Functions", "description":"Ends the current function call and supplies its return value. Return exits nested loops and sequences. Use only on a Function Entry execution path.", "godot_term":"GDScript: return value", "aliases":["Return Value", "Function Return"]}

func get_property_definitions() -> Array:
	return [{"name":"value", "type":TYPE_STRING, "default":"null", "blueprint_pin":true, "pin_type":"Variant"}]

func get_exec_output_definitions() -> Array:
	return []

func get_execution_spec() -> Dictionary:
	var expression := str(properties.get("value_expression", "")).strip_edges()
	if expression.is_empty(): expression = str(properties.get("value", "null")).strip_edges()
	return {"kind":"function_return", "value":expression if not expression.is_empty() else "null"}
