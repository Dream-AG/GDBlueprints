@tool
extends "res://addons/GDBlueprints/bricks/sensors/common/random_sensor.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "RandomNumberGenerator", 
		"class": "UIRandomSensor",
		"name": "Random",
		"type": "sensor",
		"category": "UI",
		"description": "Randomly activates based on chance.",
		"menu_order": 60,
		"domain": "ui"
	}
