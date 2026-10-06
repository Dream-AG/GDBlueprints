@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Spawn Scene"

func _initialize_properties() -> void:
	properties = {"scene":"null", "parent":"self", "local_transform":"null"}

func get_brick_info() -> Dictionary:
	return {"class":"SpawnScene", "name":"Spawn Scene", "type":"actuator", "category":"Scene", "description":"Instantiates a PackedScene under an explicit live parent. Optional Transform2D/Transform3D is local to that parent and applied before ready. Instance is null on invalid input; Then still runs. Use outside physics-query signal callbacks, or defer the calling event.", "godot_term":"PackedScene.instantiate() / Node.add_child()", "aliases":["Spawn Actor", "Instantiate Scene"]}

func get_property_definitions() -> Array:
	return [{"name":"scene", "type":TYPE_STRING, "default":"null", "blueprint_pin":true, "pin_type":"PackedScene"}, {"name":"parent", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Node"}, {"name":"local_transform", "type":TYPE_STRING, "default":"null", "blueprint_pin":true, "pin_type":"Variant"}]

func expression(key: String) -> String:
	var wired := str(properties.get(key + "_expression", "")).strip_edges()
	return wired if not wired.is_empty() else str(properties[key])

func generate_code(_node: Node, _chain: String) -> Dictionary:
	return {"actuator_code":'_flow.values[%s] = {"instance": preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").spawn_scene(%s, %s, %s)}' % [var_to_str(str(properties.get("_execution_id", ""))), expression("scene"), expression("parent"), expression("local_transform")]}

func get_value_output_definitions() -> Array:
	return [{"name":"Instance", "type":"Node", "expression":'_flow.values.get(%s, {}).get("instance", null)' % var_to_str(str(properties.get("_execution_id", "")))}]
