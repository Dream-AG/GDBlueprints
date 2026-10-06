@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Example event template. Copy into bricks/sensors/common/ or a project-local
## extension folder, then replace the native trigger expression.

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Example Event"

func _initialize_properties() -> void:
	properties = {}

func get_brick_info() -> Dictionary:
	return {
		"class":"ExampleEventSensor",
		"name":"Example Event",
		"type":"sensor",
		"category":"Examples",
		"description":"Contributor template event.",
		"aliases":["Example Event"],
		"godot_term":"Godot/GDScript: replace with the native event/condition",
		"menu_order":9990,
	}

func get_property_definitions() -> Array:
	return []

func generate_ir(_node: Node, _chain_name: String) -> Dictionary:
	# Sensors must assign the canonical sensor_active result. The manager safely
	# namespaces it when multiple Events/Sensors exist in one generated script.
	return {
		"sensor":[
			{"op":"statement", "code":"var sensor_active = true # TODO: native Godot trigger"}
		]
	}
