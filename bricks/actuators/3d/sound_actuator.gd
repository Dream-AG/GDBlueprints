@tool

extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Sound Actuator - Play, stop, pause, and fade audio from a file
## Creates and manages its own AudioStreamPlayer / AudioStreamPlayer3D at runtime
## No @export variables needed on the target node


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "3D Audio"


func get_brick_info() -> Dictionary:
	return {"godot_term": "AudioStreamPlayer3D", 
		"class": "SoundActuator",
		"name": "3D Audio",
		"type": "actuator",
		"category": "Audio",
		"description": "Play, stop, pause and fade spatial or non-positional audio using shared owner-scoped channels.",
		"menu_order": 10,
		"aliases": ["Audio3DActuator", "Audio3dActuator"]
	}


func _initialize_properties() -> void:
	properties = {
		"channel": "",
		"mode": "play",             # play, stop, pause, fade_in, fade_out
		"sound_file": "",           # File path to the audio stream
		"volume": 0.0,              # dB
		"pitch": 1.0,               # Pitch scale
		"pitch_random": 0.0,        # Random pitch range (+/-)
		"loop": false,              # Loop the sound
		"positional": false,        # Use AudioStreamPlayer3D if true
		"play_mode": "restart",     # restart, overlap, ignore
		"audio_bus": "",            # Audio bus name (empty = Master)
		"fade_duration": 1.0,       # Duration for fade_in / fade_out in seconds
		"min_delay": 0.0,           # Minimum delay between plays (seconds)
	}


func get_property_definitions() -> Array:
	return [
		{"name":"channel", "blueprint_pin":false, "type":TYPE_STRING, "default":"", "placeholder":"Optional shared audio channel"},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play,Stop,Pause,Fade In,Fade Out",
			"default": "play"
		},
		{
			"name": "sound_file", "required": true, "required_label": "a sound file", "required_if": {"mode": ["play", "fade_in"]},
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.wav,*.ogg,*.mp3",
			"default": ""
		},
		{
			"name": "play_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Restart,Overlap,Ignore If Playing",
			"default": "restart"
		},
		{
			"name": "volume",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-80,24,0.1"
		},
		{
			"name": "pitch",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,4.0,0.01"
		},
		{
			"name": "pitch_random",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01"
		},
		{
			"name": "loop",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "positional",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "audio_bus",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "fade_duration",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1,10.0,0.1"
		},
		{
			"name": "min_delay",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,5.0,0.05"
		},
	]


func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return preload("res://addons/GDBlueprints/core/audio_codegen.gd").generate(properties, "3d")
