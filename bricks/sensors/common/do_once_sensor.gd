@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Unreal-style Do Once gate represented as a one-shot condition sensor.

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "One Shot Event (Compatibility)"

func _initialize_properties() -> void:
	properties = {"start_closed": false}

func get_property_definitions() -> Array:
	return [{"name": "start_closed", "type": TYPE_BOOL, "default": false}]

func get_brick_info() -> Dictionary:
	return {
		"class": "DoOnceSensor",
		"name": "One Shot Event (Compatibility)",
		"type": "sensor",
		"category": "Flow Control",
		"description": "Legacy event that fires once after processing starts. For an incoming execution path and Reset input, use the Do Once action.",
		"menu_order": 20,
		"aliases": ["DoOnce", "Once", "Gate Once"],
		"godot_term": "GDScript: persistent bool guard"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Compatibility event: fires once after processing starts. Use the Do Once action for an execution input and Reset.",
		"start_closed": "If enabled, this legacy event stays closed. Use the Do Once action when you need Reset."
	}

func generate_code(_node: Node, chain_name: String) -> Dictionary:
	var used_var = "_bfg_do_once_used_%s" % _unique_label(chain_name)
	var start_closed = bool(properties.get("start_closed", false))
	return {
		"member_vars": ["var %s: bool = %s" % [used_var, "true" if start_closed else "false"]],
		"sensor_code": "var sensor_active = not %s\nif sensor_active:\n\t%s = true" % [used_var, used_var]
	}
