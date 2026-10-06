extends RefCounted
## Owner-scoped channels let separate Play/Stop/Pause nodes control the same sound.
## Streams are prepared once per channel. Overlaps share that immutable stream.
const STATE := &"_gdblueprints_audio"
const FADE := &"_gdblueprints_audio_fade"

static func execute(owner: Node, settings: Dictionary) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return false
	for key in ["volume", "pitch", "pitch_random", "fade_duration", "min_delay"]:
		if not is_finite(float(settings.get(key, 0.0))): return false
	var mode := str(settings.get("mode", "play"))
	var family := str(settings.get("family", "2d"))
	var channel := str(settings.get("channel", ""))
	var path := str(settings.get("sound_file", ""))
	var key := family + ":" + (channel if not channel.is_empty() else path)
	var states: Dictionary = owner.get_meta(STATE, {})
	for stale in states.keys():
		if not is_instance_valid(states[stale].player): states.erase(stale)
	owner.set_meta(STATE, states)
	if mode in ["stop", "pause", "fade_out"]:
		var matched := false
		for id in states:
			var state: Dictionary = states[id]
			if state.family != family or (not channel.is_empty() and id != key) or (channel.is_empty() and not path.is_empty() and state.path != path): continue
			matched = true
			for player in _players(state):
				match mode:
					"stop":
						_cancel_fade(player)
						player.set_meta("gdb_loop", false)
						player.stop()
						if player != state.player: player.queue_free()
					"pause": _pause(player)
					"fade_out":
						player.set_meta("gdb_loop", false)
						_fade(player, -80.0, maxf(0.0, float(settings.get("fade_duration", 1.0))), true, player != state.player)
		return matched
	if mode not in ["play", "fade_in"] or path.is_empty(): return false
	var kind := str(settings.get("kind", "plain"))
	var state: Dictionary = states.get(key, {})
	if state.is_empty() or state.path != path or state.kind != kind or state.player.is_queued_for_deletion():
		if not ResourceLoader.exists(path):
			push_warning("Audio: resource does not exist: " + path)
			return false
		var resource := load(path) as AudioStream
		if resource == null:
			push_warning("Audio: resource is not an AudioStream: " + path)
			return false
		# Changing a channel resource stops its former voices, but failed loads do not.
		if not state.is_empty():
			for old in _players(state): old.queue_free()
		var stream: AudioStream = resource.duplicate()
		if stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3: stream.loop = false
		var primary := _create_player(owner, kind, stream)
		state = {"family":family, "path":path, "kind":kind, "player":primary, "voices":[], "last_play":-INF}
		states[key] = state
	var primary: Node = state.player
	var now := Time.get_ticks_usec() / 1000000.0
	if now - float(state.last_play) < maxf(0.0, float(settings.get("min_delay", 0.0))): return true
	var play_mode := str(settings.get("play_mode", "restart"))
	var loop := bool(settings.get("loop", false))
	# A looping channel never creates an unbounded stream of overlapping players.
	if loop: play_mode = "ignore_if_playing"
	if (play_mode in ["ignore", "ignore_if_playing"] or mode == "fade_in") and primary.playing and not primary.stream_paused and not primary.get_meta("gdb_fading_out", false):
		return true
	state.last_play = now
	var player: Node = primary
	if play_mode == "overlap" and mode == "play":
		var active: Array = []
		for voice in state.voices:
			if is_instance_valid(voice) and not voice.is_queued_for_deletion(): active.append(voice)
		# Bound per-channel resource use during rapid-fire events.
		if active.size() >= 32:
			active.pop_front().queue_free()
		player = _create_player(owner, kind, primary.stream)
		player.set_meta("gdb_one_shot", true)
		active.append(player)
		state.voices = active
	_cancel_fade(player)
	player.set_meta("gdb_loop", loop)
	player.volume_db = clampf(float(settings.get("volume", 0.0)), -80.0, 24.0)
	var variation := absf(float(settings.get("pitch_random", 0.0)))
	player.pitch_scale = clampf(float(settings.get("pitch", 1.0)) + randf_range(-variation, variation), 0.01, 4.0)
	var bus := str(settings.get("audio_bus", ""))
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	player.set_meta("gdb_paused", false)
	player.stream_paused = false
	if mode == "fade_in":
		var volume: float = player.volume_db
		player.volume_db = -80.0
		player.play()
		_fade(player, volume, maxf(0.0, float(settings.get("fade_duration", 1.0))), false, false)
	else:
		player.stop()
		player.play()
	return true

static func _players(state: Dictionary) -> Array[Node]:
	var result: Array[Node] = []
	for player in [state.player] + state.voices:
		if is_instance_valid(player) and not player.is_queued_for_deletion(): result.append(player)
	return result

static func _create_player(owner: Node, kind: String, stream: AudioStream) -> Node:
	var player: Node = AudioStreamPlayer2D.new() if kind == "2d" else (AudioStreamPlayer3D.new() if kind == "3d" else AudioStreamPlayer.new())
	player.stream = stream
	owner.add_child(player)
	player.finished.connect(_finished.bind(player))
	return player

static func _finished(player: Node) -> void:
	if player.is_queued_for_deletion(): return
	if player.get_meta("gdb_one_shot", false): player.queue_free()
	elif player.get_meta("gdb_loop", false): player.play()

static func _cancel_fade(player: Node) -> void:
	player.set_meta("gdb_fading_out", false)
	if not player.has_meta(FADE): return
	var tween: Tween = player.get_meta(FADE)
	if tween != null and tween.is_valid(): tween.kill()
	player.remove_meta(FADE)

static func _fade(player: Node, volume: float, duration: float, stop: bool, dispose: bool) -> void:
	_cancel_fade(player)
	var tween: Tween = player.create_tween()
	player.set_meta(FADE, tween)
	player.set_meta("gdb_fading_out", stop)
	tween.tween_property(player, "volume_db", volume, duration)
	tween.tween_callback(_finish_fade.bind(player, stop, dispose))

static func _finish_fade(player: Node, stop: bool, dispose: bool) -> void:
	player.set_meta("gdb_fading_out", false)
	player.remove_meta(FADE)
	if stop: player.stop()
	if dispose: player.queue_free()

static func _pause(player: Node) -> void:
	var paused := not bool(player.get_meta("gdb_paused", false))
	player.set_meta("gdb_paused", paused)
	player.stream_paused = paused
	# Spatial players can defer creating playback until the next physics frame.
	# Apply the latest request after that frame without retaining freed players.
	if not player.get_meta("gdb_pause_pending", false):
		player.set_meta("gdb_pause_pending", true)
		player.get_tree().physics_frame.connect(_apply_requested_pause.bind(weakref(player)), CONNECT_ONE_SHOT | CONNECT_DEFERRED)

static func _apply_requested_pause(reference: WeakRef) -> void:
	var player = reference.get_ref()
	if not is_instance_valid(player) or player.is_queued_for_deletion(): return
	player.set_meta("gdb_pause_pending", false)
	player.stream_paused = bool(player.get_meta("gdb_paused", false))
