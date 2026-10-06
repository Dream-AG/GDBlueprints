@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Do Once"

func _initialize_properties() -> void:
	properties = {"start_closed":false}

func get_brick_info() -> Dictionary:
	return {"class":"DoOnceExecution", "name":"Do Once", "type":"actuator", "category":"Flow", "domain":"common", "description":"Runs Then once per reset. Reset reopens this node without executing Then. State is shared by all paths entering this node and isolated per scene instance.", "godot_term":"Persistent GDScript boolean with separate execution entry points", "aliases":["Once", "Resettable Do Once"]}

func get_property_definitions() -> Array:
	return [{"name":"start_closed", "type":TYPE_BOOL, "default":false, "blueprint_pin":false}]

func get_exec_input_definitions() -> Array:
	return [{"name":"In", "id":"in"}, {"name":"Reset", "id":"reset"}]

func get_execution_spec() -> Dictionary:
	return {"kind":"once", "start_closed":bool(properties.get("start_closed", false))}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {"actuator_code":"pass # Do Once is compiled by the execution graph backend"}
