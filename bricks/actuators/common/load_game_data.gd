@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Load Game Data"

func _initialize_properties() -> void:
	properties = {"path":"user://saves/slot.gdbsave", "version":1, "migrations":"{}", "recover_backup":true}

func get_brick_info() -> Dictionary:
	return {"class":"LoadGameData", "name":"Load Game Data", "type":"actuator", "category":"Persistence", "description":"Reads a versioned data save without modifying live objects. Optional trusted migration Callables are keyed by old version. Recovered reports loading the previous-good backup. Missing, corrupt, unsupported or newer saves return Success false.", "godot_term":"FileAccess / bytes_to_var / schema migrations"}

func get_property_definitions() -> Array:
	return [{"name":"path", "type":TYPE_STRING, "default":"user://saves/slot.gdbsave", "blueprint_pin":true, "pin_type":"String"}, {"name":"version", "type":TYPE_INT, "default":1, "blueprint_pin":true, "pin_type":"Int"}, {"name":"migrations", "type":TYPE_STRING, "default":"{}", "blueprint_pin":true, "pin_type":"Dictionary"}, {"name":"recover_backup", "type":TYPE_BOOL, "default":true, "blueprint_pin":true, "pin_type":"Bool"}]

func expression(key: String, literal: bool = false) -> String:
	var wired := str(properties.get(key + "_expression", "")).strip_edges()
	if not wired.is_empty(): return wired
	return var_to_str(str(properties[key])) if literal else str(properties[key])

func generate_code(_node: Node, _chain: String) -> Dictionary:
	return {"actuator_code":'_flow.values[%s] = preload("res://addons/GDBlueprints/core/persistence.gd").load_game(%s, %s, %s, %s)' % [var_to_str(str(properties.get("_execution_id", ""))), expression("path", true), expression("version", false), expression("migrations", false), expression("recover_backup", false)]}

func get_value_output_definitions() -> Array:
	var result := '_flow.values.get(%s, {})' % var_to_str(str(properties.get("_execution_id", "")))
	return [{"name":"Success", "type":"Bool", "expression":result + '.get("ok", false)'}, {"name":"Error", "type":"String", "expression":result + '.get("error", "")'}, {"name":"Data", "type":"Dictionary", "expression":result + '.get("data", {})'}, {"name":"Recovered", "type":"Bool", "expression":result + '.get("recovered", false)'}]
