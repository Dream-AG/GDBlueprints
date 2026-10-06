@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"


func get_brick_info() -> Dictionary:
	return {
		"description": "Shakes a Camera2D for impact feedback.",
		"godot_term": "Camera2D offset / rotation",
		"class": "ScreenShake2DActuator",
		"name": "Camera Shake",
		"type": "actuator",
		"category": "Game Feel",
		"domain": "2d",
		"menu_order": 500
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Camera Shake"


func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera2D",
		"intensity": "10.0",
		"duration": "0.3",
		"rotation_intensity": "1.5"
	}


func get_property_definitions() -> Array:
	return [
		{"name": "camera_node_name", "type": TYPE_STRING, "default": "Camera2D"},
		{"name": "intensity", "type": TYPE_STRING, "default": "10.0"},
		{"name": "duration", "type": TYPE_STRING, "default": "0.3"},
		{"name": "rotation_intensity", "type": TYPE_STRING, "default": "1.5"}
	]


func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	var target := var_to_str(str(properties.get("camera_node_name", "Camera2D")))
	var intensity := _to_expr(properties.get("intensity", "10.0"))
	var duration := _to_expr(properties.get("duration", "0.3"))
	var rotation := _to_expr(properties.get("rotation_intensity", "1.5"))
	return {
		"actuator_code":
		(
			'preload("res://addons/GDBlueprints/core/camera_effects.gd").shake_2d(preload("res://addons/GDBlueprints/core/node_targets.gd").resolve(self, %s), float(%s), float(%s), float(%s))'
			% [target, intensity, duration, rotation]
		)
	}


func _to_expr(value: Variant) -> String:
	var expression := str(value).strip_edges()
	return "0.0" if expression.is_empty() else expression
