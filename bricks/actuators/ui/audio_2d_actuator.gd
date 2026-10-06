@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/audio_2d_actuator.gd"

## UI identity retained for existing graphs; implementation shared with common node.
func get_brick_info() -> Dictionary:
	return {"godot_term": "AudioStreamPlayer / AudioStreamPlayer2D", 
		"class": "UIAudio2DActuator",
		"name": "2D Audio",
		"type": "actuator",
		"category": "UI",
		"description": "Plays UI or 2D audio.",
		"menu_order": 160,
		"domain": "ui"
	}
