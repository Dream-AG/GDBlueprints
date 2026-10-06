@tool
extends "res://addons/GDBlueprints/bricks/sensors/common/delay_sensor.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "Elapsed delta timer state", 
		"class": "UIDelaySensor",
		"name": "Timer Event",
		"type": "sensor",
		"category": "UI",
		"description": "Triggers after a delay or at an interval.",
		"menu_order": 20,
		"domain": "ui"
	}
