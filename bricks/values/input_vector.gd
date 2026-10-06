@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.VALUE
	brick_name = "Input Vector"

func _initialize_properties() -> void:
	properties = {"left":"ui_left", "right":"ui_right", "up":"ui_up", "down":"ui_down", "deadzone":-1.0}

func get_brick_info() -> Dictionary:
	return {"class":"InputVector", "name":"Input Vector", "type":"value", "category":"Input", "description":"Reads four Input Map actions as a length-limited Vector2. Missing actions return zero; -1 uses the actions' average deadzone. Map X/Y to X/Z for 3D movement.", "godot_term":"Input.get_vector()", "aliases":["Movement Input", "Axis 2D"]}

func get_property_definitions() -> Array:
	var result: Array = []
	for key in ["left", "right", "up", "down"]:
		result.append({"name":key, "type":TYPE_STRING, "default":properties[key], "blueprint_pin":false})
	result.append({"name":"deadzone", "type":TYPE_FLOAT, "default":-1.0, "blueprint_pin":false})
	return result

func get_value_output_definitions() -> Array:
	return [{"name":"Vector", "type":"Vector2", "expression":'preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").input_vector(%s, %s, %s, %s, %s)' % [var_to_str(str(properties.left)), var_to_str(str(properties.right)), var_to_str(str(properties.up)), var_to_str(str(properties.down)), str(float(properties.deadzone))]}]
