@tool

extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Animation Actuator - Play, stop, or control animations via AnimationPlayer
## Automatically finds the AnimationPlayer that owns the named animation
## Works with AnimationPlayers nested at any depth in the scene tree


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation"


func _initialize_properties() -> void:
	properties = {
		"target_node": "",
		"mode": "play",             # play, stop, pause, queue
		"animation_name": "",       # Name of the animation to play
		"speed": "1.0",             # Speed: number, variable, or expression
		"blend_time": -1.0,         # -1 means use AnimationPlayer default
		"play_backwards": false,
		"from_end": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play,Stop,Pause,Queue",
			"default": "play"
		},
		{
			"name": "animation_name",
			"required": true,
			"required_label": "an animation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__ANIMATION_LIST__",
			"default": ""
		},
		{
			"name": "speed",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "blend_time",
			"type": TYPE_FLOAT,
			"default": -1.0
		},
		{
			"name": "play_backwards",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "from_end",
			"type": TYPE_BOOL,
			"default": false
		},
		{"name":"target", "type":TYPE_OBJECT, "default":null, "blueprint_pin":true, "pin_type":"AnimationPlayer"},
		{"name":"target_node", "blueprint_pin":false, "type":TYPE_STRING, "default":"", "placeholder":"Optional player NodePath or name"},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play, stop, or control animations by name.\nAutomatically finds the AnimationPlayer that owns the animation.\nWorks with AnimationPlayers nested at any depth.",
		"mode": "Play: start animation\nStop: stop playback\nPause: freeze at current frame\nQueue: play after current finishes",
		"animation_name": "Name of the animation to play.",
		"speed": "Playback speed. Accepts:\n• A number: 1.0\n• A variable: move_speed\n• An expression: move_speed * 2",
		"blend_time": "Blend time in seconds (-1 = use default).\nSmooth transition from previous animation.",
		"play_backwards": "Play the animation in reverse.",
		"from_end": "Start from the last frame.",
	}


func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	var speed := str(properties.get("speed", "1.0")).strip_edges()
	if speed.is_empty(): speed = "1.0"
	var target := str(properties.get("target_expression", "")).strip_edges()
	if target.is_empty(): target = var_to_str(str(properties.get("target_node", "")))
	return {"actuator_code": 'preload("res://addons/GDBlueprints/core/animation_runtime.gd").execute(self, %s, %s, float(%s), %s, %s, %s, %s)' % [
		var_to_str(str(properties.get("animation_name", ""))),
		var_to_str(str(properties.get("mode", "play")).to_lower()), speed,
		str(float(properties.get("blend_time", -1.0))),
		str(bool(properties.get("play_backwards", false))).to_lower(),
		str(bool(properties.get("from_end", false))).to_lower(), target]}
