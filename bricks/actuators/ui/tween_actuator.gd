@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/tween_actuator.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "Node.create_tween() / Tween.tween_property()", 
		"class": "UITweenActuator",
		"name": "Tween",
		"type": "actuator",
		"category": "UI",
		"description": "Tweens a UI node property.",
		"menu_order": 140,
		"domain": "ui"
	}
