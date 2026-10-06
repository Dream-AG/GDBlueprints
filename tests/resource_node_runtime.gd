extends SceneTree
## Executes generated nodes with native resources; syntax-only audits cannot do this.
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Audio = preload("res://addons/GDBlueprints/core/audio_runtime.gd")
const Targets = preload("res://addons/GDBlueprints/core/node_targets.gd")
const CameraEffects = preload("res://addons/GDBlueprints/core/camera_effects.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
var failures: Array[String] = []
var assertions := 0
var resource_path := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func definition(path: String, values: Dictionary = {}):
	var action = load("res://addons/GDBlueprints/bricks/actuators/" + path + "_actuator.gd").new()
	action.properties.merge(values, true)
	return action

func compile_actions(owner: Node, actions: Dictionary, extra: String = "") -> void:
	var source := "extends %s\n" % owner.get_class() + extra
	for method in actions:
		var generated: Dictionary = Manager.new()._generate_brick_with_bindings(actions[method], owner, str(method))
		for member in generated.get("member_vars", []): source += str(member) + "\n"
		for helper in generated.get("methods", []): source += str(helper) + "\n"
		source += "func %s():\n\tvar _delta = 1.0 / 60.0\n" % method
		for line in str(generated.get("actuator_code", "pass")).split("\n"): source += "\t" + line + "\n"
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "Generated resource fixture parse")
	owner.set_script(script)

func run() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(4000)
	samples.fill(128)
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	resource_path = "user://gdb_resource_fixture_%d.tres" % Time.get_ticks_usec()
	check(ResourceSaver.save(stream, resource_path) == OK, "Audio resource fixture write")
	await audio_nodes()
	animation_nodes()
	sprite_node()
	await ui_nodes()
	await physics_and_effects()
	await object_flashes()
	target_lifetime()
	DirAccess.remove_absolute(resource_path)
	print("Resource node runtime: ", assertions, " assertions; failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func audio_nodes() -> void:
	for specification in [["common/audio_2d", "2d", {"player_type":"stream_player"}], ["common/audio_2d", "2d", {"player_type":"stream_player_2d"}], ["3d/sound", "3d", {"positional":false}], ["3d/sound", "3d", {"positional":true}]]:
		var values: Dictionary = specification[2].duplicate()
		values.merge({"sound_file":resource_path, "channel":"music", "pitch":1.0, "pitch_expression":"-2.0", "volume_expression":"-6.0", "loop":true, "min_delay":0.0}, true)
		var owner := Node.new()
		var actions := {}
		for mode in ["play", "pause", "stop", "fade_in", "fade_out"]:
			var settings := values.duplicate()
			settings.mode = mode
			settings.fade_duration = 0.02
			if mode in ["stop", "pause", "fade_out"]: settings.sound_file = ""
			actions[mode] = definition(specification[0], settings)
		compile_actions(owner, actions)
		root.add_child(owner)
		owner.call("play")
		await process_frame
		var state: Dictionary = owner.get_meta(Audio.STATE, {}).get(specification[1] + ":music", {})
		check(not state.is_empty(), "Generated audio Play did not create shared channel")
		if state.is_empty(): owner.free(); continue
		var player: Node = state.player
		check(player.stream is AudioStreamWAV and player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Private stream loop normalization")
		check((load(resource_path) as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Audio mutated source resource")
		check(player.pitch_scale >= 0.00999, "Invalid pitch escaped clamp")
		check(player.playing, "Audio did not start")
		owner.call("play")
		check(owner.get_child_count() == 1, "Repeated looping play created extra players")
		owner.call("pause")
		await physics_frame
		await process_frame
		check(player.stream_paused, "Separate Pause node did not control Play node")
		owner.call("pause")
		check(not player.stream_paused, "Pause toggle did not resume")
		owner.call("stop")
		check(not player.playing and not player.get_meta("gdb_loop"), "Separate Stop node failed")
		owner.call("fade_in")
		await (player.get_meta(Audio.FADE) as Tween).finished
		check(player.playing and is_equal_approx(player.volume_db, -6.0), "Fade In target volume")
		owner.call("fade_out")
		await (player.get_meta(Audio.FADE) as Tween).finished
		check(not player.playing, "Separate Fade Out node failed to stop")
		owner.call("play")
		owner.call("fade_out")
		var interrupted: Tween = player.get_meta(Audio.FADE)
		owner.call("play")
		check(not interrupted.is_valid() and player.playing, "New playback did not cancel pending Fade Out")
		player.free()
		owner.call("play")
		check(owner.get_child_count() == 1, "Freed audio player was not recreated")
		owner.free()
	var owner := Node.new()
	root.add_child(owner)
	var settings := {"family":"2d", "sound_file":resource_path, "play_mode":"overlap", "pitch":1.0}
	for index in 40: check(Audio.execute(owner, settings), "Overlap playback failed")
	await process_frame
	check(owner.get_child_count() <= 33, "Overlap voice count is unbounded")
	var state: Dictionary = owner.get_meta(Audio.STATE)["2d:" + resource_path]
	for player in state.voices:
		if is_instance_valid(player): player.emit_signal("finished")
	await process_frame
	check(owner.get_child_count() == 1, "Finished overlap players leaked")
	check(Audio.execute(owner, {"family":"2d", "mode":"stop"}), "Blank-path Stop did not address owner channels")
	check(not Audio.execute(owner, {"sound_file":resource_path, "pitch":NAN}), "Non-finite pitch accepted")
	check(not Audio.execute(owner, {"sound_file":"res://missing-audio-file.tres"}), "Missing resource accepted")
	owner.free()
	var first_owner := Node.new()
	var second_owner := Node.new()
	root.add_child(first_owner)
	root.add_child(second_owner)
	var shared := {"sound_file":resource_path, "channel":"same", "family":"2d", "min_delay":5.0}
	check(Audio.execute(first_owner, shared) and Audio.execute(second_owner, shared), "First play incorrectly delayed")
	var first_player: Node = first_owner.get_meta(Audio.STATE)["2d:same"].player
	var second_player: Node = second_owner.get_meta(Audio.STATE)["2d:same"].player
	check(Audio.execute(first_owner, {"mode":"stop", "channel":"same"}), "Named-channel stop failed")
	check(not first_player.playing and second_player.playing, "Audio controls leaked between graph owners")
	check(Audio.execute(first_owner, shared) and not first_player.playing, "Minimum delay did not suppress repeated play")
	first_owner.free()
	second_owner.free()

func animation_nodes() -> void:
	for on_owner in [true, false]:
		var owner: Node = AnimationPlayer.new() if on_owner else Node.new()
		var player: AnimationPlayer = owner if on_owner else AnimationPlayer.new()
		player.name = "Player"
		var library := AnimationLibrary.new()
		for name in ["idle", "next"]:
			var animation := Animation.new()
			animation.length = 2.0
			library.add_animation(name, animation)
		player.add_animation_library("", library)
		var actions := {
			"reverse":definition("common/animation", {"animation_name":"idle", "speed":"speed_value", "blend_time":0.1, "play_backwards":true}),
			"forward":definition("common/animation", {"animation_name":"idle", "speed":"1.0"}),
			"pause_anim":definition("common/animation", {"animation_name":"idle", "mode":"pause"}),
			"queue_anim":definition("common/animation", {"animation_name":"next", "mode":"queue"}),
			"stop_anim":definition("common/animation", {"animation_name":"idle", "mode":"stop"}),
		}
		compile_actions(owner, actions, "var speed_value := 2.0\n")
		root.add_child(owner)
		if not on_owner: owner.add_child(player)
		owner.call("reverse")
		check(player.is_playing() and is_equal_approx(player.get_playing_speed(), -2.0), "Reverse/blend/expression speed mismatch")
		check(is_equal_approx(player.current_animation_position, 2.0), "Reverse playback did not start at end")
		owner.call("pause_anim")
		check(not player.is_playing(), "Animation Pause failed")
		owner.call("forward")
		check(is_equal_approx(player.get_playing_speed(), 1.0), "Default speed retained previous multiplier")
		owner.call("queue_anim")
		check(player.get_queue().size() == 1 and player.get_queue()[0] == &"next", "Animation Queue failed")
		owner.call("stop_anim")
		check(not player.is_playing(), "Animation Stop failed")
		owner.free()

func sprite_node() -> void:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	frames.add_frame("default", texture)
	sprite.sprite_frames = frames
	compile_actions(sprite, {"play_sprite":definition("2d/sprite_animation_2d"), "stop_sprite":definition("2d/sprite_animation_2d", {"mode":"stop"})})
	root.add_child(sprite)
	sprite.speed_scale = 3.0
	sprite.call("play_sprite")
	check(sprite.is_playing() and is_equal_approx(sprite.speed_scale, 1.0), "Sprite self targeting/default speed")
	sprite.call("stop_sprite")
	check(not sprite.is_playing(), "Sprite Stop failed")
	sprite.free()

func ui_nodes() -> void:
	var panel := BlueprintPanel.new()
	for name in ["button", "focus", "popup", "scroll", "slider", "tab", "window"]:
		var inputs: Array = panel._get_brick_input_definitions(definition("ui/" + name))
		check(str(inputs.back().name) == "target", "New UI pin must append after existing pins: " + name)
	for name in ["common/audio_2d", "3d/sound"]:
		var action = definition(name)
		for property in action.get_property_definitions():
			if property.name == "channel": check(not panel._property_is_blueprint_value_input(property, action), "Channel shifted saved data pins")
	panel.free()
	var owner := Node.new()
	compile_actions(owner, {"press":definition("ui/button", {"target_node_name":"Container/Button", "action":"press"}), "toggle":definition("ui/button", {"target_expression":"get_node(\"Container/Button\")", "action":"toggle"}), "value":definition("ui/slider", {"target_node_name":"Container/Slider", "value":"42"}), "invalid_popup":definition("ui/popup", {"target_node_name":"self"})})
	root.add_child(owner)
	var container := Control.new()
	container.name = "Container"
	owner.add_child(container)
	var button := Button.new()
	button.name = "Button"
	button.toggle_mode = true
	container.add_child(button)
	var slider := HSlider.new()
	slider.name = "Slider"
	container.add_child(slider)
	owner.call("press")
	check(button.button_pressed, "UI relative NodePath failed")
	owner.call("toggle")
	check(not button.button_pressed, "UI direct-reference pin failed")
	owner.call("value")
	check(slider.value == 42.0, "UI slider generated action failed")
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(100, 100)
	compile_actions(scroll, {"scroll_to":definition("ui/scroll", {"axis":"both", "x":"30", "y":"40"})})
	owner.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(1000, 1000)
	scroll.add_child(content)
	await process_frame
	await process_frame
	scroll.call("scroll_to")
	check(scroll.scroll_horizontal == 30 and scroll.scroll_vertical == 40, "Scroll action failed")
	var focus := Button.new()
	compile_actions(focus, {"focus_on":definition("ui/focus"), "focus_off":definition("ui/focus", {"action":"release_focus"})})
	owner.add_child(focus)
	focus.call("focus_on")
	check(focus.has_focus(), "Grab Focus failed")
	focus.call("focus_off")
	check(not focus.has_focus(), "Release Focus failed")
	var popup := Control.new()
	compile_actions(popup, {"hide_popup":definition("ui/popup", {"action":"hide"}), "show_popup":definition("ui/popup", {"action":"show"})})
	owner.add_child(popup)
	popup.call("hide_popup")
	check(not popup.visible, "Popup Hide failed")
	popup.call("show_popup")
	check(popup.visible, "Popup Show failed")
	root.gui_embed_subwindows = true
	var window := Window.new()
	window.visible = false
	compile_actions(window, {"show_window":definition("ui/window"), "hide_window":definition("ui/window", {"action":"hide"})})
	owner.add_child(window)
	window.call("show_window")
	check(window.visible, "Window Show failed")
	window.call("hide_window")
	check(not window.visible, "Window Hide failed")
	owner.call("invalid_popup") # Must warn, never call show() on a plain Node.
	owner.free()
	await process_frame

func physics_and_effects() -> void:
	var owner := Node2D.new()
	compile_actions(owner, {"disable_shape":definition("2d/collision_2d", {"target_node":"Body/Shape"}), "shake":definition("2d/screen_shake_2d", {"camera_node_name":"Camera", "duration":"0.04"})})
	root.add_child(owner)
	var body := StaticBody2D.new()
	body.name = "Body"
	owner.add_child(body)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	owner.call("disable_shape")
	await process_frame
	check(shape.disabled, "Collision path/deferred shape disable failed")
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.offset = Vector2(3, 7)
	camera.rotation = 0.2
	owner.add_child(camera)
	owner.call("shake")
	await create_timer(0.08).timeout
	check(camera.offset.is_equal_approx(Vector2(3, 7)) and is_equal_approx(camera.rotation, 0.2), "Camera shake did not restore original transform")
	check(CameraEffects.shake_2d(camera, 10, 100000, 2), "Long shake rejected")
	var first: Tween = camera.get_meta(CameraEffects.STATE).tween
	check(CameraEffects.shake_2d(camera, 4, 0.03, 1) and not first.is_valid(), "Repeated shake did not replace old tween")
	await create_timer(0.08).timeout
	check(camera.offset == Vector2(3, 7), "Repeated shake accumulated offset drift")
	check(not CameraEffects.shake_2d(camera, NAN, 1, 1), "Non-finite shake accepted")
	owner.free()

func target_lifetime() -> void:
	var owner := Node.new()
	root.add_child(owner)
	var child := Node.new()
	child.name = "Target"
	owner.add_child(child)
	check(Targets.resolve(owner, child) == child, "Explicit target reference")
	check(Targets.resolve(owner, NodePath("Target")) == child, "Explicit NodePath")
	check(Targets.resolve(owner, "Missing/Target", "tree") == null, "Invalid explicit path fell back to a name")
	var sibling := Node.new()
	sibling.name = "OutsideTarget"
	root.add_child(sibling)
	check(Targets.resolve(owner, NodePath("OutsideTarget"), "tree") == null, "NodePath value fell back to scene-wide name search")
	sibling.free()
	child.queue_free()
	check(Targets.resolve(owner, child) == null, "Queued target accepted")
	owner.free()

func object_flashes() -> void:
	for dimension in [2, 3]:
		for mode in ["single_flash", "strobe", "color_strobe"]:
			var owner: Node = Node2D.new() if dimension == 2 else MeshInstance3D.new()
			var original: StandardMaterial3D
			if dimension == 3:
				owner.mesh = BoxMesh.new()
				original = StandardMaterial3D.new()
				original.albedo_color = Color(0.1, 0.2, 0.3)
				owner.material_overlay = original
			else:
				owner.modulate = Color(0.2, 0.4, 0.6, 0.8)
			var action = definition("2d/object_flash_2d" if dimension == 2 else "3d/object_flash", {"effect":mode, "speed":"0.001"})
			compile_actions(owner, {"flash":action})
			root.add_child(owner)
			owner.call("flash")
			await create_timer(0.1).timeout
			if dimension == 2:
				check(owner.modulate.is_equal_approx(Color(0.2, 0.4, 0.6, 0.8)), "2D flash did not restore base color: " + mode)
			else:
				check(owner.material_overlay == original and original.albedo_color.is_equal_approx(Color(0.1, 0.2, 0.3)), "3D flash changed original material: " + mode)
			owner.free()
