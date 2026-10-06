@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/modulate_actuator.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "CanvasItem.modulate / self_modulate", 
		"class": "UIModulateActuator",
		"name": "Modulate",
		"type": "actuator",
		"category": "UI",
		"description": "Sets or transitions color/alpha on a Control or CanvasItem node.",
		"menu_order": 120,
		"domain": "ui"
	}
