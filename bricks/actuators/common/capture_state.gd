@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Capture State"

func _initialize_properties() -> void:
	properties = {"target":"self", "names":"PackedStringArray([\"health\"])"}

func get_brick_info() -> Dictionary:
	return {"class":"CaptureState", "name":"Capture State", "type":"actuator", "category":"Persistence", "description":"Copies explicitly named properties from a live Object into a data Dictionary. Unknown fields and live references fail without partial output. Getter code may run; choose plain state fields.", "godot_term":"Object.get_property_list() / Object.get()"}

func get_property_definitions() -> Array:
	return [{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object"}, {"name":"names", "type":TYPE_STRING, "default":"PackedStringArray([\"health\"])", "blueprint_pin":true, "pin_type":"PackedStringArray"}]

func expression(key: String, literal: bool = false) -> String:
	var wired := str(properties.get(key + "_expression", "")).strip_edges()
	if not wired.is_empty(): return wired
	return var_to_str(str(properties[key])) if literal else str(properties[key])

func generate_code(_node: Node, _chain: String) -> Dictionary:
	return {"actuator_code":'_flow.values[%s] = preload("res://addons/GDBlueprints/core/persistence.gd").capture_state(%s, %s)' % [var_to_str(str(properties.get("_execution_id", ""))), expression("target", false), expression("names", false)]}

func get_value_output_definitions() -> Array:
	var result := '_flow.values.get(%s, {})' % var_to_str(str(properties.get("_execution_id", "")))
	return [{"name":"Success", "type":"Bool", "expression":result + '.get("ok", false)'}, {"name":"Error", "type":"String", "expression":result + '.get("error", "")'}, {"name":"Data", "type":"Dictionary", "expression":result + '.get("data", {})'}]
