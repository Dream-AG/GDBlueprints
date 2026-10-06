@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Destroy Node"

func _initialize_properties() -> void:
	properties = {"target":"self"}

func get_brick_info() -> Dictionary:
	return {"class":"DestroyNode", "name":"Destroy Node", "type":"actuator", "category":"Scene", "description":"Queues an explicit node and its children for deletion. Invalid/already queued targets are ignored. Deleting Self stops its remaining graph execution; other targets leave Then available.", "godot_term":"Node.queue_free()", "aliases":["Destroy Actor", "Queue Free"]}

func get_property_definitions() -> Array:
	return [{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Node"}]

func generate_code(_node: Node, _chain: String) -> Dictionary:
	var target := str(properties.get("target_expression", "")).strip_edges()
	if target.is_empty(): target = str(properties.target)
	return {"actuator_code":'preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").destroy_node(%s)' % target}
