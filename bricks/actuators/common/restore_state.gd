@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Restore State"

func _initialize_properties() -> void:
	properties = {"target":"self", "data":"{}"}

func get_brick_info() -> Dictionary:
	return {"class":"RestoreState", "name":"Restore State", "type":"actuator", "category":"Persistence", "description":"Preflights all state keys and types before assigning a live Object's properties. Unknown, read-only or incompatible values fail before assignment. User setters remain ordinary code and their side effects cannot be rolled back.", "godot_term":"Object.set() / typed container validation"}

func get_property_definitions() -> Array:
	return [{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object"}, {"name":"data", "type":TYPE_STRING, "default":"{}", "blueprint_pin":true, "pin_type":"Dictionary"}]

func expression(key: String, literal: bool = false) -> String:
	var wired := str(properties.get(key + "_expression", "")).strip_edges()
	if not wired.is_empty(): return wired
	return var_to_str(str(properties[key])) if literal else str(properties[key])

func generate_code(_node: Node, _chain: String) -> Dictionary:
	return {"actuator_code":'_flow.values[%s] = preload("res://addons/GDBlueprints/core/persistence.gd").restore_state(%s, %s)' % [var_to_str(str(properties.get("_execution_id", ""))), expression("target", false), expression("data", false)]}

func get_value_output_definitions() -> Array:
	var result := '_flow.values.get(%s, {})' % var_to_str(str(properties.get("_execution_id", "")))
	return [{"name":"Success", "type":"Bool", "expression":result + '.get("ok", false)'}, {"name":"Error", "type":"String", "expression":result + '.get("error", "")'}]
