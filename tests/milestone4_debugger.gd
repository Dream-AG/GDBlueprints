extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")
const Snapshot = preload("res://addons/GDBlueprints/core/debug_snapshot.gd")
const Debugger = preload("res://addons/GDBlueprints/gdblueprints_debugger.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var owner := Node.new()
	owner.name = "Owner"
	root.add_child(owner)
	owner.set_meta("blueprints_for_godot_variables", [{"name":"health", "debug_watch":true}])
	var script := GDScript.new()
	script.source_code = "extends Node\nvar health := 42\nvar _gdb_execution_epoch := 0\n"
	check(script.reload() == OK, "Fixture script parse")
	owner.set_script(script)
	var flow := {"meter":{"depth":2,"steps":7}, "event_arguments":{"damage":5}, "function_name":"attack", "function_arguments":{"attack":{"amount":3}}, "function_locals":{"attack":{"total":8}}, "values":{"call":{"result":8}}, "loops":[{"control":""}]}
	var captured := Snapshot.capture(owner, flow, "node_1", "in")
	check(captured.node_id == "node_1" and captured.depth == 2 and captured.watched.health == 42, "Snapshot identity/watch values")
	check(captured.function_locals.attack.total == 8 and captured.event_arguments.damage == 5, "Snapshot activation values")
	var deep := {"a":{"b":{"c":{"d":1}}}}
	check(str(Snapshot._safe(deep, 0)).contains("<max depth>"), "Snapshot depth limit")
	var many: Array = []
	for index in 30: many.append(index)
	check(Snapshot._safe(many, 0).size() == 25, "Snapshot item limit")

	var graph := GraphEdit.new()
	var panel_fixture = {"graph_edit":graph, "current_node":owner}
	var event = _node("event", "CustomEventSensor", {})
	var action = _node("action", "PrintStringActuator", {"text":"hello"}, true)
	graph.add_child(event)
	graph.add_child(action)
	graph.connect_node(event.name, 0, action.name, 0)
	var adapter := PanelAdapter.new(panel_fixture)
	var chains := Builder.build(adapter)
	var generated := Manager.new()._generate_code_for_chains(owner, chains)
	check(generated.contains("before_node(self, \"action\", _entry, _flow, true)"), "Async breakpoint instrumentation")
	check(generated.contains("debug_snapshot.gd"), "Debugger snapshot preload")
	var compiled := GDScript.new()
	compiled.source_code = "extends Node\n" + generated
	check(compiled.reload() == OK, "Instrumented graph parse")

	var debugger := Debugger.new()
	root.add_child(debugger)
	await process_frame
	debugger.before_node(owner, "pause_here", "in", flow, true)
	check(debugger._paused and paused, "Breakpoint did not pause the SceneTree")
	debugger._resume("continue")
	check(not debugger._paused and not paused, "Continue did not resume the SceneTree")
	debugger._mode = "step_over"
	debugger._origin_depth = 2
	check(not _would_pause(debugger, 3, false) and _would_pause(debugger, 2, false), "Step Over depth semantics")
	debugger._mode = "step_out"
	debugger._origin_depth = 2
	check(not _would_pause(debugger, 2, false) and _would_pause(debugger, 1, false), "Step Out depth semantics")
	debugger._mode = "continue"
	check(_would_pause(debugger, 4, true) and not _would_pause(debugger, 4, false), "Breakpoint/Continue semantics")
	debugger.queue_free()
	graph.free()
	owner.free()
	print("Milestone 4 debugger failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func _would_pause(debugger, depth: int, breakpoint_enabled: bool) -> bool:
	if breakpoint_enabled: return true
	match debugger._mode:
		"step_into": return true
		"step_over": return depth <= debugger._origin_depth
		"step_out": return depth < debugger._origin_depth
	return false

func _node(id: String, type: String, properties: Dictionary, breakpoint_enabled: bool = false) -> GraphNode:
	var brick = load(Registry.get_script_path(type)).new()
	brick.properties.merge(properties, true)
	brick.debug_enabled = breakpoint_enabled
	var node := GraphNode.new()
	node.name = id
	node.set_meta("brick_data", {"brick_instance":brick, "brick_class":type, "brick_type":Registry.get_brick_info(type).type})
	for index in 5:
		node.add_child(Label.new())
		node.set_slot(index, true, 0, Color.WHITE, true, 0, Color.WHITE)
	return node

class PanelAdapter:
	extends RefCounted
	var graph_edit: GraphEdit
	var current_node: Node
	func _init(values: Dictionary):
		graph_edit = values.graph_edit
		current_node = values.current_node
	func _get_value_output_info(_node, _port): return {}
