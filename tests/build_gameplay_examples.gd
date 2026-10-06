extends SceneTree
## Rebuilds checked-in example scenes through the production graph UI/compiler.
## Run only when intentionally regenerating examples; normal tests do not rewrite them.
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Region = preload("res://addons/GDBlueprints/core/generated_region.gd")
const BASE := "res://addons/GDBlueprints/examples/gameplay/"
var failures: Array[String] = []

func _initialize() -> void:
	build.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func add(panel, id: String, type: String, position: Vector2, props: Dictionary = {}) -> GraphNode:
	return panel._create_graph_node_from_data({"id":id, "position":position, "brick_class":type, "brick_type":Registry.get_brick_info(type).type, "properties":props})

func event(panel, id: String, parameters: String, position: Vector2) -> void:
	add(panel, id, "CustomEventSensor", position, {"event_name":id, "parameters":parameters, "_applied_parameters":parameters})

func call_node(panel, id: String, method: String, parameters: String, returns: String, position: Vector2, props: Dictionary = {}) -> void:
	props.merge({"function_name":method, "parameters":parameters, "_applied_parameters":parameters, "return_type":returns, "_applied_return_type":returns}, true)
	add(panel, id, "CallGraphFunction", position, props)

func wire(panel, from: String, to: String, port: int = 0) -> void:
	check(panel.graph_edit.connect_node(from, port, to, 0) == OK, "Execution wire " + from)

func data_wire(panel, from: String, output: String, to: String, input: String) -> void:
	var source: GraphNode = panel.graph_edit.get_node(from)
	var target: GraphNode = panel.graph_edit.get_node(to)
	for port in source.get_meta("value_output_ports", {}):
		if str(panel._get_value_output_info(source, port).get("name", "")) != output: continue
		for target_port in target.get_meta("value_input_ports", {}):
			if target.get_meta("value_input_ports")[target_port] == input:
				check(panel.graph_edit.connect_node(from, port, to, target_port) == OK, "Data wire " + from)
				return
	check(false, "Missing data pins: " + from + "." + output + " -> " + to + "." + input)

func build() -> void:
	for dimension in [2, 3]:
		make_pickup(dimension)
		var game := make_world(dimension)
		var panel := BlueprintPanel.new()
		root.add_child(panel)
		panel.current_node = game
		add(panel, "tick", "EventPhysicsTickSensor", Vector2(0, 0))
		add(panel, "input", "InputVector", Vector2(0, 300))
		call_node(panel, "velocity", "desired_%dd" % dimension, "input: Vector2, delta: float", "Vector%d" % dimension, Vector2(340, 0), {"argument_delta":"_delta"})
		add(panel, "move", "MoveCharacter%dD" % dimension, Vector2(700, 0), {"body":'$Player'})
		add(panel, "overlaps", "OverlappingBodies", Vector2(700, 400), {"area":'$Player/Detector'})
		call_node(panel, "collect", "collect_bodies", "bodies: Array[Node]", "void", Vector2(1060, 0))
		call_node(panel, "hud", "update_hud", "", "void", Vector2(1420, 0))
		wire(panel, "tick", "velocity")
		wire(panel, "velocity", "move")
		wire(panel, "move", "collect")
		wire(panel, "collect", "hud")
		data_wire(panel, "input", "Vector", "velocity", "argument_input")
		data_wire(panel, "velocity", "Result", "move", "velocity")
		data_wire(panel, "overlaps", "Bodies", "collect", "argument_bodies")
		event(panel, "start_round", "", Vector2(0, 800))
		add(panel, "spawn_loop", "ForEachExecution", Vector2(340, 800), {"items":"spawn_transforms"})
		add(panel, "spawn", "SpawnScene", Vector2(700, 800), {"scene":"pickup_scene", "parent":"$Pickups"})
		wire(panel, "start_round", "spawn_loop")
		wire(panel, "spawn_loop", "spawn")
		wire(panel, "spawn_loop", "hud", 1)
		data_wire(panel, "spawn_loop", "Item", "spawn", "local_transform")
		event(panel, "pickup", "body: Node", Vector2(0, 1400))
		add(panel, "valid_pickup", "BranchController", Vector2(340, 1400), {"condition_expression":'is_instance_valid(_flow.event_arguments["pickup"]["body"]) and not _flow.event_arguments["pickup"]["body"].is_queued_for_deletion() and _flow.event_arguments["pickup"]["body"].is_in_group("gdb_demo_pickup")'})
		call_node(panel, "score", "add_score", "", "void", Vector2(700, 1400))
		add(panel, "destroy", "DestroyNode", Vector2(1060, 1400))
		wire(panel, "pickup", "valid_pickup")
		wire(panel, "valid_pickup", "score")
		wire(panel, "score", "destroy")
		data_wire(panel, "pickup", "body", "destroy", "target")
		event(panel, "damage", "body: Node", Vector2(0, 1800))
		call_node(panel, "hurt", "apply_damage", "body: Node", "void", Vector2(340, 1800))
		wire(panel, "damage", "hurt")
		data_wire(panel, "damage", "body", "hurt", "argument_body")
		event(panel, "reach_goal", "body: Node", Vector2(0, 2200))
		add(panel, "unlocked", "BranchController", Vector2(340, 2200), {"condition_expression":'score == 3 and health > 0 and _flow.event_arguments["reach_goal"]["body"] == player'})
		call_node(panel, "win", "finish_game", "", "void", Vector2(700, 2200))
		wire(panel, "reach_goal", "unlocked")
		wire(panel, "unlocked", "win")
		panel._sync_value_bindings_from_connections()
		panel._save_graph_to_metadata("Build gameplay example", false)
		var chains: Array = Builder.build(panel)
		check(not chains.is_empty() and not chains[0].has("compile_error"), "Build graph: " + str(chains[0].get("compile_error", "")) if not chains.is_empty() else "Empty graph")
		if not failures.is_empty():
			panel.free()
			game.free()
			break
		game.set_meta("blueprints_for_godot", chains)
		var source := 'extends "res://addons/GDBlueprints/examples/gameplay/game_base.gd"\n\n' + Region.START + "\n" + Region.seal(Manager.new()._generate_code_for_chains(game, chains)) + Region.END + "\n"
		var path := BASE + "game_%dd.gd" % dimension
		FileAccess.open(path, FileAccess.WRITE).store_string(source)
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "Generated gameplay script parses")
		game.set_script(script)
		game.dimension = dimension
		game.get_node("Hazard").body_entered.connect(Callable(game, "damage"), CONNECT_PERSIST)
		game.get_node("Goal").body_entered.connect(Callable(game, "reach_goal"), CONNECT_PERSIST)
		game.get_node("HUD/Panel/Rows/Restart").pressed.connect(Callable(game, "restart"), CONNECT_PERSIST)
		save_scene(game, BASE + "game_%dd.tscn" % dimension)
		panel.free()
		game.free()
	print("Gameplay example build failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func save_scene(node: Node, path: String) -> void:
	for child in node.find_children("*", "", true, false): child.owner = node
	var packed := PackedScene.new()
	check(packed.pack(node) == OK, "Pack " + path)
	check(ResourceSaver.save(packed, path) == OK, "Save " + path)

func solid_2d(parent: Node, node: Node2D, label: String, position: Vector2, size: Vector2, color: Color) -> Node2D:
	node.name = label
	node.position = position
	parent.add_child(node)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	node.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([-size / 2, Vector2(size.x, -size.y) / 2, size / 2, Vector2(-size.x, size.y) / 2])
	visual.color = color
	node.add_child(visual)
	return node

func solid_3d(parent: Node, node: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> Node3D:
	node.name = label
	node.position = position
	parent.add_child(node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	node.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	visual.mesh = mesh
	node.add_child(visual)
	return node

func make_pickup(dimension: int) -> void:
	var container := Node.new()
	var pickup: Node
	if dimension == 2: pickup = solid_2d(container, StaticBody2D.new(), "Pickup", Vector2.ZERO, Vector2(18, 18), Color.GOLD)
	else: pickup = solid_3d(container, StaticBody3D.new(), "Pickup", Vector3.ZERO, Vector3(0.4, 0.4, 0.4), Color.GOLD)
	pickup.collision_layer = 2
	pickup.collision_mask = 0
	pickup.add_to_group("gdb_demo_pickup", true)
	save_scene(pickup, BASE + "pickup_%dd.tscn" % dimension)
	container.free()

func make_world(dimension: int) -> Node:
	var game := Node.new()
	game.name = "Gameplay%dD" % dimension
	var pickups := Node.new()
	pickups.name = "Pickups"
	game.add_child(pickups)
	var player: Node
	var detector: Node
	if dimension == 2:
		player = solid_2d(game, CharacterBody2D.new(), "Player", Vector2(96, 300), Vector2(26, 26), Color.CORNFLOWER_BLUE)
		player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		detector = solid_2d(player, Area2D.new(), "Detector", Vector2.ZERO, Vector2(48, 48), Color(0.4, 0.7, 1, 0.15))
		for data in [[Vector2(480, 48), Vector2(900, 20)], [Vector2(480, 550), Vector2(900, 20)], [Vector2(30, 300), Vector2(20, 520)], [Vector2(930, 300), Vector2(20, 520)], [Vector2(480, 300), Vector2(140, 70)]]:
			solid_2d(game, StaticBody2D.new(), "Wall", data[0], data[1], Color.SLATE_GRAY)
		solid_2d(game, Area2D.new(), "Hazard", Vector2(460, 140), Vector2(140, 70), Color.INDIAN_RED)
		solid_2d(game, Area2D.new(), "Goal", Vector2(850, 300), Vector2(55, 80), Color.SEA_GREEN)
		var camera := Camera2D.new()
		camera.name = "DemoCamera"
		camera.position = Vector2(480, 194)
		camera.zoom = Vector2(0.8, 0.8)
		game.add_child(camera)
	else:
		player = solid_3d(game, CharacterBody3D.new(), "Player", Vector3(-9, 1, 0), Vector3(0.7, 1.6, 0.7), Color.CORNFLOWER_BLUE)
		detector = solid_3d(player, Area3D.new(), "Detector", Vector3.ZERO, Vector3(1.5, 2, 1.5), Color(0.4, 0.7, 1))
		detector.get_child(1).visible = false
		solid_3d(game, StaticBody3D.new(), "Ground", Vector3(0, -0.5, 0), Vector3(24, 1, 18), Color(0.16, 0.22, 0.3))
		solid_3d(game, StaticBody3D.new(), "Wall", Vector3(0, 1, 0), Vector3(2, 2, 4), Color.SLATE_GRAY)
		solid_3d(game, Area3D.new(), "Hazard", Vector3(-2, 0.1, -5), Vector3(3, 0.3, 2), Color.INDIAN_RED)
		solid_3d(game, Area3D.new(), "Goal", Vector3(9, 0.5, 0), Vector3(1.5, 1, 2), Color.SEA_GREEN)
		var camera := Camera3D.new()
		camera.position = Vector3(15, 20, 22)
		camera.rotation_degrees = Vector3(-37, 34, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 29
		camera.current = true
		game.add_child(camera)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -25, 0)
		game.add_child(light)
	player.collision_layer = 1
	player.collision_mask = 1
	detector.collision_layer = 0
	detector.collision_mask = 2
	for area in [game.get_node("Hazard"), game.get_node("Goal")]:
		area.collision_layer = 0
		area.collision_mask = 1
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	game.add_child(hud)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(16, 12)
	hud.add_child(panel)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	panel.add_child(rows)
	var title := Label.new()
	title.text = "  GDBlueprints | Collect & Escape  "
	title.add_theme_font_size_override("font_size", 23)
	rows.add_child(title)
	var status := Label.new()
	status.name = "Status"
	status.text = "Loading graph..."
	rows.add_child(status)
	var controls := Label.new()
	controls.text = "Arrow keys: move | Avoid red hazards" + (" | Space/Enter: jump" if dimension == 3 else "")
	rows.add_child(controls)
	var button := Button.new()
	button.name = "Restart"
	button.text = "Restart round"
	button.focus_mode = Control.FOCUS_NONE
	rows.add_child(button)
	return game
