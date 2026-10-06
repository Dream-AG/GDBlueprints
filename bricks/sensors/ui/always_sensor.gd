@tool
extends "res://addons/GDBlueprints/bricks/sensors/common/always_sensor.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "Node._process(delta)", 
		"class": "UIAlwaysSensor",
		"name": "Always",
		"type": "sensor",
		"category": "UI",
		"description": "Always active while enabled.",
		"menu_order": 10,
		"domain": "ui"
	}
