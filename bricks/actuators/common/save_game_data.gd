@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Save Game Data"

func _initialize_properties() -> void:
	properties = {"path":"user://saves/slot.gdbsave", "data":"{}", "version":1}

func get_brick_info() -> Dictionary:
	return {"class":"SaveGameData", "name":"Save Game Data", "type":"actuator", "category":"Persistence", "description":"Writes a data Dictionary under user:// with a schema version, checksum, temporary replacement and previous-good backup. Unsupported live references or I/O failures leave Success false; Then still runs.", "godot_term":"FileAccess / var_to_bytes / DirAccess.rename_absolute"}

func get_property_definitions() -> Array:
	return [{"name":"path", "type":TYPE_STRING, "default":"user://saves/slot.gdbsave", "blueprint_pin":true, "pin_type":"String"}, {"name":"data", "type":TYPE_STRING, "default":"{}", "blueprint_pin":true, "pin_type":"Dictionary"}, {"name":"version", "type":TYPE_INT, "default":1, "blueprint_pin":true, "pin_type":"Int"}]

func expression(key: String, literal: bool = false) -> String:
	var wired := str(properties.get(key + "_expression", "")).strip_edges()
	if not wired.is_empty(): return wired
	return var_to_str(str(properties[key])) if literal else str(properties[key])

func generate_code(_node: Node, _chain: String) -> Dictionary:
	return {"actuator_code":'_flow.values[%s] = preload("res://addons/GDBlueprints/core/persistence.gd").save_game(%s, %s, %s)' % [var_to_str(str(properties.get("_execution_id", ""))), expression("path", true), expression("data", false), expression("version", false)]}

func get_value_output_definitions() -> Array:
	var result := '_flow.values.get(%s, {})' % var_to_str(str(properties.get("_execution_id", "")))
	return [{"name":"Success", "type":"Bool", "expression":result + '.get("ok", false)'}, {"name":"Error", "type":"String", "expression":result + '.get("error", "")'}]
