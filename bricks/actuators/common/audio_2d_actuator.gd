@tool

extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Audio 2D Actuator - Play 2D/UI audio with file selection, volume, pitch, and play modes
## Creates and manages its own AudioStreamPlayer or AudioStreamPlayer2D at runtime
## Playback lifecycle is shared with 3D Audio through core/audio_runtime.gd.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "2D Audio"


func get_brick_info() -> Dictionary:
	return {"godot_term": "AudioStreamPlayer2D / AudioStreamPlayer", 
		"class": "Audio2DActuator",
		"name": "2D Audio",
		"type": "actuator",
		"category": "Audio",
		"description": "Play 2D or UI audio with owner-scoped channels shared by Play, Stop, Pause and Fade nodes.",
		"menu_order": 20,
		"aliases": ["Audio2dActuator"]
	}


func _initialize_properties() -> void:
	properties = {
		"channel": "",
		"sound_file":    "",
		"player_type":   "stream_player",   # stream_player, stream_player_2d
		"mode":          "play",            # play, stop, pause, fade_in, fade_out
		"volume":        0.0,
		"pitch":         1.0,
		"pitch_random":  0.0,
		"loop":          false,
		"play_mode":     "restart",         # restart, overlap, ignore_if_playing
		"audio_bus":     "",
		"fade_duration": 1.0,
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
			"name": "player_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "AudioStreamPlayer,AudioStreamPlayer2D",
			"default": "stream_player"
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
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-80,24,0.1",
			"default": 0.0
		},
		{
			"name": "pitch",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,4.0,0.01",
			"default": 1.0
		},
		{
			"name": "pitch_random",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01",
			"default": 0.0
		},
		{
			"name": "loop",
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
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1,10.0,0.1",
			"default": 1.0
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"channel": "Optional shared channel. Blank Play uses the file; blank Stop/Pause/Fade Out with no file controls all channels of this owner and audio family.",
		"_description": "Play 2D/UI audio from a file.\nCreates its own AudioStreamPlayer at runtime — no @export needed.",
		"mode":         "Play, Stop, Pause, Fade In, or Fade Out.",
		"sound_file":   "Audio file to play. Supports .wav, .ogg, .mp3.",
		"player_type":  "AudioStreamPlayer: non-positional (music, UI sounds).\nAudioStreamPlayer2D: positional in 2D space.",
		"play_mode":    "Restart: stop and restart if already playing.\nOverlap: spawn a new player each time.\nIgnore: do nothing if already playing.",
		"volume":       "Volume in dB. 0 = mixer-neutral, lower values reduce volume, -80 = silent.",
		"pitch":        "Pitch multiplier. 1.0 = normal.",
		"pitch_random": "Random pitch variation ± this amount each play.",
		"loop":         "Replay the sound again when it finishes.",
		"audio_bus":    "Audio bus name. Leave empty for Master.",
		"fade_duration":"Duration of fade in/out in seconds.",
	}


func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return preload("res://addons/GDBlueprints/core/audio_codegen.gd").generate(properties, "2d")
