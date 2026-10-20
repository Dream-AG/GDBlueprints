extends Node
## Runs inside an actual export template. No editor classes are loaded here.
const Saves = preload("res://addons/GDBlueprints/core/persistence.gd")
var failures: Array[String] = []

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame
	await get_tree().process_frame

func run() -> void:
	check(not OS.has_feature("editor"), "This test requires an export template, not the editor executable")
	var debugger := get_tree().root.get_node_or_null("GDBlueprintsDebugger")
	check(debugger != null, "Debugger autoload missing")
	if debugger != null:
		check((debugger.get_child_count() > 0) == OS.is_debug_build(), "Overlay must exist only in debug exports")
		if not OS.is_debug_build():
			check(not debugger.is_processing() and not debugger.is_processing_unhandled_key_input(), "Release debugger still processes frames or keys")
	for dimension in [2, 3]:
		var game: Node = load("res://addons/GDBlueprints/examples/gameplay/game_%dd.tscn" % dimension).instantiate()
		get_tree().root.add_child(game)
		get_tree().current_scene = game
		await frames(20)
		if not OS.is_debug_build():
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--capture-dir="):
					await RenderingServer.frame_post_draw
					var path := argument.trim_prefix("--capture-dir=").path_join("demo-%dd.png" % dimension)
					check(get_viewport().get_texture().get_image().save_png(path) == OK, "Screenshot capture failed")
		check(game.get_node("Pickups").get_child_count() == 3, "Exported spawn graph failed")
		var player: Node = game.get_node("Player")
		var start: Variant = player.position
		Input.action_press("ui_right")
		await frames(30)
		Input.action_release("ui_right")
		check(player.position.x > start.x, "Exported input/movement graph failed")
		for pickup in game.get_node("Pickups").get_children():
			game.call("pickup", pickup)
		await frames(3)
		check(game.score == 3 and game.get_node("Pickups").get_child_count() == 0, "Exported event/data/deletion graph failed")
		game.restart()
		await frames(3)
		check(game.score == 0 and game.get_node("Pickups").get_child_count() == 3, "Exported restart failed")
		game.queue_free()
		await get_tree().process_frame
	var path := "user://gdb-export-smoke-%s.save" % str(Time.get_ticks_usec())
	var payload := {"health": 3, "position": Vector3(1, 2, 3), "items": PackedStringArray(["key"])}
	check(Saves.save_game(path, payload).get("ok", false), "Exported save failed")
	var loaded := Saves.load_game(path)
	check(loaded.get("ok", false) and loaded.get("data") == payload, "Exported typed load failed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await resource_helpers()
	print("Export smoke failures: ", failures, "; debug=", OS.is_debug_build())
	get_tree().quit(0 if failures.is_empty() else 1)

func resource_helpers() -> void:
	var audio = preload("res://addons/GDBlueprints/core/audio_runtime.gd")
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(8000)
	samples.fill(128)
	stream.data = samples
	var path := "user://gdb-export-audio-%d.tres" % Time.get_ticks_usec()
	check(ResourceSaver.save(stream, path) == OK, "Exported audio fixture write")
	for kind in ["plain", "2d", "3d"]:
		var owner := Node.new()
		add_child(owner)
		check(audio.execute(owner, {"sound_file":path, "kind":kind, "channel":"test"}), "Exported audio Play")
		check(audio.execute(owner, {"mode":"pause", "channel":"test"}), "Exported audio Pause")
		await get_tree().physics_frame
		await get_tree().process_frame
		var player: Node = owner.get_meta(audio.STATE)["2d:test"].player
		check(player.stream_paused, "Exported immediate spatial Pause")
		check(audio.execute(owner, {"mode":"stop", "channel":"test"}) and not player.playing, "Exported audio Stop")
		owner.free()
	# Let AudioServer process stopped playback objects before the smoke process exits.
	# Fixed-FPS acceleration can outrun the audio thread and report false shutdown leaks.
	await frames(3)
	DirAccess.remove_absolute(path)
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 1.0
	library.add_animation("idle", animation)
	player.add_animation_library("", library)
	add_child(player)
	check(preload("res://addons/GDBlueprints/core/animation_runtime.gd").execute(player, "idle", "play", 2.0, 0.1, true, false), "Exported Animation runtime")
	check(is_equal_approx(player.get_playing_speed(), -2.0), "Exported reverse speed")
	player.free()
	var camera := Camera2D.new()
	add_child(camera)
	check(preload("res://addons/GDBlueprints/core/camera_effects.gd").shake_2d(camera, 1.0, 0.02, 1.0), "Exported camera effect")
	await (camera.get_meta("_gdblueprints_camera_shake").tween as Tween).finished
	check(camera.offset == Vector2.ZERO and camera.rotation == 0.0, "Exported camera restoration")
	camera.free()
