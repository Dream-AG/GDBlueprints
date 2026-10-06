@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Unreal-familiar BeginPlay event.
## In this execution-chain architecture it fires on the first generated process
## pass after Godot's _ready() has completed. That keeps downstream Actions in
## the normal generated chain while matching BeginPlay's one-shot semantics.

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Event BeginPlay"

func _initialize_properties() -> void:
	properties = {}

func get_property_definitions() -> Array:
	return []

func get_brick_info() -> Dictionary:
	return {
		"class": "EventBeginPlaySensor",
		"name": "Event BeginPlay",
		"type": "sensor",
		"category": "Events",
		"description": "Runs once when gameplay begins. Godot equivalent: _ready(). In this graph compiler the connected Actions execute on the first process pass immediately after _ready().",
		"menu_order": 1,
		"aliases": ["Begin Play", "BeginPlay", "Event Ready", "Ready", "_ready"],
		"godot_term": "Godot/GDScript: _ready() (one-shot startup)"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Unreal: Event BeginPlay\nGodot: func _ready() -> void\nGDBlueprints fires this chain once, on the first process pass after _ready()."
	}

func generate_code(_node: Node, chain_name: String) -> Dictionary:
	var fired_var = "_bfg_begin_play_fired_%s" % _unique_label(chain_name)
	return {
		"member_vars": ["var %s: bool = false" % fired_var],
		"sensor_code": "var sensor_active = not %s\nif sensor_active:\n\t%s = true" % [fired_var, fired_var]
	}
