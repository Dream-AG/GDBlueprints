@tool
extends "res://addons/GDBlueprints/bricks/sensors/common/input_map_sensor.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "Input Map / Input.is_action_*()", 
		"class": "UIInputMapSensor",
		"name": "Input",
		"type": "sensor",
		"category": "UI",
		"description": "Detects Godot Input Map actions for UI logic.",
		"menu_order": 30,
		"domain": "ui"
	}
