@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/visibility_actuator.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "CanvasItem.show() / hide() / visible", 
		"class": "UIVisibilityActuator",
		"name": "Visibility",
		"type": "actuator",
		"category": "UI",
		"description": "Shows, hides, or toggles a UI node.",
		"menu_order": 130,
		"domain": "ui"
	}
