extends SceneTree

const Gameplay = preload("res://addons/GDBlueprints/core/gameplay_runtime.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Region = preload("res://addons/GDBlueprints/core/generated_region.gd")
const Debugger = preload("res://addons/GDBlueprints/gdblueprints_debugger.gd")
const Flow = preload("res://addons/GDBlueprints/core/execution_runtime.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for index in count: await physics_frame
	await process_frame

func run() -> void:
	invalid_inputs()
	await spawn_contract()
	await value_authoring()
	for dimension in [2, 3]:
		await game_loop(dimension)
		await graph_roundtrip(dimension)
	await debugger_regressions()
	print("Milestone 5 gameplay failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func invalid_inputs() -> void:
	for value in [null, 42, "Player", Vector2.ZERO, RefCounted.new()]:
		check(not Gameplay.move_2d(value, Vector2.ONE), "Invalid 2D target accepted")
		check(not Gameplay.move_3d(value, Vector3.ONE), "Invalid 3D target accepted")
		check(not Gameplay.destroy_node(value), "Invalid deletion accepted")
		check(Gameplay.overlapping_bodies(value).is_empty(), "Invalid overlap target accepted")
		check(Gameplay.spawn_scene(null, value) == null, "Invalid spawn accepted")
	var freed := Node.new()
	freed.free()
	check(not Gameplay.destroy_node(freed), "Freed target accepted")
	check(not Gameplay.move_2d(freed, Vector2.ZERO) and Gameplay.overlapping_bodies(freed).is_empty(), "Freed reference guard")
	var body_2d := CharacterBody2D.new()
	root.add_child(body_2d)
	check(not Gameplay.move_2d(body_2d, Vector2(INF, 0)) and body_2d.velocity.is_finite(), "Non-finite velocity reached physics")
	body_2d.free()
	check(Gameplay.input_vector("missing_gdb_action", "ui_right", "ui_up", "ui_down") == Vector2.ZERO, "Missing input action did not return zero")
	Input.action_press("ui_right")
	Input.action_press("ui_down")
	check(is_equal_approx(Gameplay.input_vector("ui_left", "ui_right", "ui_up", "ui_down").length(), 1.0), "Diagonal input exceeds unit length")
	Input.action_release("ui_right")
	Input.action_release("ui_down")
	var manager := Manager.new()
	for type in ["MoveCharacter2D", "MoveCharacter3D"]:
		check(manager._chain_needs_physics_process({"actuators":[{"type":type}]}), "Custom physics metadata ignored: " + type)

func spawn_contract() -> void:
	for dimension in [2, 3]:
		var parent: Node = Node2D.new() if dimension == 2 else Node3D.new()
		parent.position = Vector2(100, 200) if dimension == 2 else Vector3(10, 20, 30)
		root.add_child(parent)
		var scene: PackedScene = load("res://addons/GDBlueprints/examples/gameplay/pickup_%dd.tscn" % dimension)
		var transform: Variant = Transform2D(0.0, Vector2(7, 8)) if dimension == 2 else Transform3D(Basis.IDENTITY, Vector3(7, 8, 9))
		var instance := Gameplay.spawn_scene(scene, parent, transform)
		check(instance != null and instance.get_parent() == parent and instance.transform == transform, "Spawn local transform/parent contract")
		check(instance.global_position == parent.position + transform.origin, "Spawn transformed parent position")
		check(Gameplay.spawn_scene(scene, parent, "wrong") == null and parent.get_child_count() == 1, "Wrong spawn transform leaked an instance")
		check(Gameplay.destroy_node(instance) and not Gameplay.destroy_node(instance), "Deletion must be idempotent")
		await process_frame
		check(parent.get_child_count() == 0, "Queued node not removed")
		parent.queue_free()
		check(Gameplay.spawn_scene(scene, parent) == null, "Spawn into queued parent")
		await process_frame
	var source := Node2D.new()
	var script := GDScript.new()
	script.source_code = "extends Node2D\nvar position_at_ready: Vector2\nfunc _ready(): position_at_ready = position\n"
	check(script.reload() == OK, "Ready fixture parse")
	source.set_script(script)
	var packed := PackedScene.new()
	packed.pack(source)
	source.free()
	var spawned := Gameplay.spawn_scene(packed, root, Transform2D(0.0, Vector2(40, 50)))
	check(spawned.position_at_ready == Vector2(40, 50), "Ready ran before spawn transform was set")
	spawned.free()

func game_loop(dimension: int) -> void:
	var game: Node = load("res://addons/GDBlueprints/examples/gameplay/game_%dd.tscn" % dimension).instantiate()
	root.add_child(game)
	current_scene = game
	await frames(20)
	var player: Node = game.get_node("Player")
	check(game.get_node("Pickups").get_child_count() == 3, "Spawn graph did not create three pickups")
	var start: Variant = player.position
	Input.action_press("ui_right")
	await frames(120)
	Input.action_release("ui_right")
	check(player.position.x > start.x + (100 if dimension == 2 else 1), "Input/velocity graph did not move player")
	check(player.position.x < (398 if dimension == 2 else -1.3), "Character crossed solid obstacle")
	if dimension == 3:
		check(player.is_on_floor(), "Character did not settle on floor")
		Input.action_press("ui_accept")
		await frames(3)
		Input.action_release("ui_accept")
		check(player.position.y > 0.95 and player.velocity.y > 0, "Grounded jump did not rise")
		await frames(65)
		check(player.is_on_floor(), "Jump did not land")
	player.position = game.get_node("Goal").position
	await frames(5)
	check(not game.won, "Goal accepted missing pickups")
	player.position = game.start_position
	await frames(5)
	game.invulnerability = 0.0
	player.position = game.get_node("Hazard").position
	await frames(5)
	check(game.health == 2, "Native hazard signal did not reach graph")
	check(player.position.distance_to(game.start_position) < (3.0 if dimension == 2 else 0.3), "Damage did not respawn character")
	game.call("damage", player)
	check(game.health == 2, "Damage cooldown did not suppress repeated hit")
	for expected in [1, 2, 3]:
		var pickups := game.get_node("Pickups").get_children()
		if pickups.is_empty():
			check(false, "Pickup disappeared before collection")
			break
		player.position = pickups[0].position
		await frames(5)
		check(game.score == expected, "Overlap -> graph pickup -> score/delete sequence")
	check(game.get_node("Pickups").get_child_count() == 0, "Collected bodies were not freed")
	player.position = game.get_node("Goal").position
	await frames(5)
	check(game.won, "Goal signal failed after all pickups")
	check("You won" in game.get_node("HUD/Panel/Rows/Status").text, "HUD did not show win state")
	var win_x: float = player.position.x
	Input.action_press("ui_right")
	await frames(5)
	Input.action_release("ui_right")
	check(is_equal_approx(player.position.x, win_x), "Won game still permits movement")
	game.get_node("HUD/Panel/Rows/Restart").pressed.emit()
	await frames(5)
	check(game.score == 0 and game.health == 3 and not game.won and game.get_node("Pickups").get_child_count() == 3, "Restart button did not reset the round")
	for index in 3:
		game.invulnerability = 0.0
		game.call("damage", player)
	check(game.health == 0 and "Out of health" in game.get_node("HUD/Panel/Rows/Status").text, "Loss state/HUD")
	game.call("damage", player)
	check(game.health == 0, "Health underflow")
	game.free()
	current_scene = null
	await process_frame

func graph_roundtrip(dimension: int) -> void:
	var game: Node = load("res://addons/GDBlueprints/examples/gameplay/game_%dd.tscn" % dimension).instantiate()
	var saved: Dictionary = game.get_meta("blueprints_for_godot_graph").duplicate(true)
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = game
	await panel._load_graph_from_metadata()
	panel._save_graph_to_metadata("Roundtrip", false)
	var restored: Dictionary = game.get_meta("blueprints_for_godot_graph")
	check(restored.connections == saved.connections and restored.nodes.size() == saved.nodes.size(), "Gameplay graph reload lost nodes/wires")
	var chains: Array = Builder.build(panel)
	check(not chains.is_empty() and not chains[0].has("compile_error"), "Reloaded graph cannot compile")
	var generated := Manager.new()._generate_code_for_chains(game, chains)
	var source: String = game.get_script().source_code
	check(source.contains(Region.seal(generated)), "Reopened graph differs from shipped generated code")
	check(Region.edit_error(source).is_empty(), "Shipped example generated checksum mismatch")
	panel.free()
	game.free()

func value_authoring() -> void:
	var owner := Node.new()
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = owner
	panel.graph_edit.show()
	var input: GraphNode = panel._create_graph_node("value", "InputVector", Vector2.ZERO)
	var overlaps: GraphNode = panel._create_graph_node("value", "OverlappingBodies", Vector2(400, 0))
	for index in 3: await process_frame
	check(input.has_meta("brick_data") and input.get_input_port_count() == 0 and input.get_output_port_count() == 1, "Configurable value node port counts %d / %d" % [input.get_input_port_count(), input.get_output_port_count()])
	check(overlaps.get_input_port_count() == 1 and overlaps.get_output_port_count() == 1 and overlaps.get_meta("value_input_ports").get(0) == "area", "Pure reference node port counts %d / %d; input mapping %s" % [overlaps.get_input_port_count(), overlaps.get_output_port_count(), overlaps.get_meta("value_input_ports")])
	panel._on_property_changed("custom_left", input, "left")
	check('"custom_left"' in panel._get_value_output_info(input, 0).expression, "Value configuration did not change expression")
	var move: GraphNode = panel._create_graph_node("actuator", "MoveCharacter2D", Vector2(800, 0))
	panel.graph_edit.connect_node(input.name, 0, move.name, 2)
	panel._save_graph_to_metadata("Connect pure value", false)
	panel._on_property_changed("edited_left", input, "left")
	check('"edited_left"' in move.get_meta("brick_data").brick_instance.properties.velocity_expression, "Pure configuration did not propagate to consumer")
	panel._save_graph_to_metadata("Value configuration", false)
	var id := str(input.name)
	await panel._load_graph_from_metadata()
	check(panel.graph_edit.get_node(id).get_meta("brick_data").brick_instance.properties.left == "edited_left", "Value configuration lost on reload")
	panel.free()
	owner.free()

func debugger_regressions() -> void:
	# Generated hooks resolve this exact autoload path. Reuse it when the test
	# project enables the plugin, rather than testing a differently named instance.
	var debugger = root.get_node_or_null("GDBlueprintsDebugger")
	var owns_debugger := debugger == null
	if owns_debugger:
		debugger = Debugger.new()
		debugger.name = "GDBlueprintsDebugger"
		root.add_child(debugger)
	var game: Node = load("res://addons/GDBlueprints/examples/gameplay/game_2d.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	game.set_physics_process(false)
	var flow := Flow.context(game._gdb_execution_epoch)
	flow.meter.depth = 4
	debugger._mode = "step_out"
	debugger._origin_depth = 2
	debugger.before_node(game, "score", "in", flow, true)
	check(paused and debugger._paused, "Breakpoint ignored during Step Out")
	debugger._resume("step_into")
	debugger.before_node(game, "destroy", "in", flow, false)
	check(paused and debugger._paused, "Step Into did not pause actual debugger")
	debugger._resume("continue")
	paused = true
	debugger.before_node(game, "score", "in", flow, true)
	debugger._resume("continue")
	check(paused, "Debugger cleared a preexisting SceneTree pause")
	paused = false
	debugger.before_node(game, "first", "in", flow, true)
	debugger.before_node(game, "second", "in", flow, true)
	check(debugger._current.node_id == "first", "Concurrent breakpoint replaced paused snapshot")
	debugger._resume("continue")
	check(debugger._paused and debugger._current.node_id == "second", "Queued breakpoint lost")
	debugger._resume("continue")
	check(not paused, "Concurrent breakpoints left the SceneTree paused")
	# Run real generated code, suspend at its debugger hook, invalidate its epoch,
	# and verify the score side effect is suppressed when execution resumes.
	debugger._mode = "step_into"
	game.call("_gdb_exec_73636f7265", "in", 0.0, flow)
	check(debugger._paused and game.score == 0, "Generated score ran before breakpoint resumed")
	game._gdb_execution_epoch += 1
	debugger._resume("continue")
	check(game.score == 0 and flow.meter.depth == 4, "Cancelled paused graph ran an action or leaked execution depth")
	game.free()
	if owns_debugger: debugger.free()
