@tool
extends RefCounted
## Shared editor-side lowering; runtime code never imports editor definitions.
static func generate(properties: Dictionary, family: String) -> Dictionary:
	var settings := {
		"family":family,
		"mode":str(properties.get("mode", "play")).to_lower().replace(" ", "_"),
		"sound_file":str(properties.get("sound_file", "")),
		"channel":str(properties.get("channel", "")),
		"volume":float(properties.get("volume", 0.0)),
		"pitch":float(properties.get("pitch", 1.0)),
		"pitch_random":float(properties.get("pitch_random", 0.0)),
		"loop":bool(properties.get("loop", false)),
		"play_mode":str(properties.get("play_mode", "restart")).to_lower().replace(" ", "_"),
		"audio_bus":str(properties.get("audio_bus", "")).strip_edges(),
		"fade_duration":float(properties.get("fade_duration", 1.0)),
		"min_delay":float(properties.get("min_delay", 0.0)),
	}
	if family == "3d":
		settings.kind = "3d" if bool(properties.get("positional", false)) else "plain"
	else:
		var kind := str(properties.get("player_type", "stream_player")).to_lower().replace(" ", "_")
		settings.kind = "2d" if kind in ["audiostreamplayer2d", "audio_stream_player2d", "stream_player_2d", "player_2d", "2d"] else "plain"
	return {"actuator_code":'preload("res://addons/GDBlueprints/core/audio_runtime.gd").execute(self, %s)' % var_to_str(settings)}
