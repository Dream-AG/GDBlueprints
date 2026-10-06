@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Move Character 3D"


func _initialize_properties() -> void:
	properties = {"body": "self", "velocity": "Vector3.ZERO"}


func get_brick_info() -> Dictionary:
	return {
		"class": "MoveCharacter3D",
		"name": "Move Character 3D",
		"type": "actuator",
		"category": "Motion",
		"requires_physics": true,
		"description":
		"Sets an explicit CharacterBody3D's velocity in units/second and calls move_and_slide once. Use once per physics tick; do not multiply velocity by delta. Invalid targets are ignored. Supply gravity/jump velocity separately; do not combine with Character 3D Physics on the same body.",
		"godot_term": "CharacterBody3D.velocity / move_and_slide()",
		"aliases": ["Move And Slide 3D"]
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "body",
			"type": TYPE_STRING,
			"default": "self",
			"blueprint_pin": true,
			"pin_type": "CharacterBody3D"
		},
		{
			"name": "velocity",
			"type": TYPE_STRING,
			"default": "Vector3.ZERO",
			"blueprint_pin": true,
			"pin_type": "Vector3"
		}
	]


func generate_code(_node: Node, _chain: String) -> Dictionary:
	var body := str(properties.get("body_expression", "")).strip_edges()
	if body.is_empty():
		body = str(properties.body)
	var velocity := str(properties.get("velocity_expression", "")).strip_edges()
	if velocity.is_empty():
		velocity = str(properties.velocity)
	return {
		"actuator_code":
		(
			'preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").move_3d(%s, %s)'
			% [body, velocity]
		)
	}
