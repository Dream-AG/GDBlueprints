@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/screen_flash_actuator.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "CanvasLayer / ColorRect / Tween", 
		"class": "UIScreenFlashActuator",
		"name": "Screen Flash",
		"type": "actuator",
		"category": "UI",
		"description": "Flashes a full-screen ColorRect overlay.",
		"menu_order": 150,
		"domain": "ui"
	}
