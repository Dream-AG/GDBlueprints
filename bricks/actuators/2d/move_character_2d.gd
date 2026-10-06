@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Move Character 2D"


func _initialize_properties() -> void:
	properties = {"body": "self", "velocity": "Vector2.ZERO"}


func get_brick_info() -> Dictionary:
	return {
		"class": "MoveCharacter2D",
		"name": "Move Character 2D",
		"type": "actuator",
		"category": "Motion",
		"requires_physics": true,
		"description":
		"Sets an explicit CharacterBody2D's velocity in units/second and calls move_and_slide once. Use once per physics tick; do not multiply velocity by delta. Invalid targets are ignored. Supply gravity/jump velocity separately; do not combine with Character 2D Physics on the same body.",
		"godot_term": "CharacterBody2D.velocity / move_and_slide()",
		"aliases": ["Move And Slide 2D"]
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "body",
			"type": TYPE_STRING,
			"default": "self",
			"blueprint_pin": true,
			"pin_type": "CharacterBody2D"
		},
		{
			"name": "velocity",
			"type": TYPE_STRING,
			"default": "Vector2.ZERO",
			"blueprint_pin": true,
			"pin_type": "Vector2"
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
			'preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").move_2d(%s, %s)'
			% [body, velocity]
		)
	}
