@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Event Physics Tick"

func _initialize_properties() -> void:
	properties = {}

func get_property_definitions() -> Array:
	return []

func get_brick_info() -> Dictionary:
	return {
		"class": "EventPhysicsTickSensor",
		"name": "Event Physics Tick",
		"type": "sensor",
		"category": "Events",
		"description": "Runs every fixed physics step. Closest Godot equivalent to physics-focused Tick logic.",
		"menu_order": 2,
		"aliases": ["Physics Tick", "Fixed Tick", "Physics Process", "_physics_process"],
		"godot_term": "Godot/GDScript: _physics_process(delta)"
	}

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Runs each physics frame.\nGodot/GDScript: func _physics_process(delta):"}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {"sensor_code": "var sensor_active = true"}
