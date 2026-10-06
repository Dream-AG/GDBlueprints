extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")

class GraphFixture:
	extends RefCounted
	var graph_edit := GraphEdit.new()
	var current_node := Node3D.new()

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func add_node(fixture, id: String, type: String, properties: Dictionary = {}) -> GraphNode:
	var brick = load(Registry.get_script_path(type)).new()
	brick.properties.merge(properties, true)
	var graph_node := GraphNode.new()
	graph_node.name = id
	graph_node.set_meta("brick_data", {"brick_instance":brick, "brick_class":type, "brick_type":Registry.get_brick_info(type).type})
	for index in 3:
		graph_node.add_child(Label.new())
		graph_node.set_slot(index, true, 0, Color.WHITE, true, 0, Color.WHITE)
	fixture.graph_edit.add_child(graph_node)
	return graph_node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture := GraphFixture.new()
	add_node(fixture, "fire", "CustomEventSensor", {"event_name":"fire"})
	add_node(fixture, "reset", "CustomEventSensor", {"event_name":"reset_once"})
	add_node(fixture, "direct", "CustomEventSensor", {"event_name":"direct_delay"})
	add_node(fixture, "once", "DoOnceExecution")
	add_node(fixture, "wait", "DelayExecution", {"duration":99.0, "duration_expression":"wait_seconds"})
	check(Builder.build(fixture).is_empty(), "Disconnected flow drafts created execution entries")
	add_node(fixture, "branch", "BranchController", {"condition_expression":"choose_true"})
	add_node(fixture, "yes", "CallObjectMethodActuator", {"method_name":"record", "arguments":"[1]"})
	add_node(fixture, "no", "CallObjectMethodActuator", {"method_name":"record", "arguments":"[2]"})
	fixture.graph_edit.connect_node("fire", 0, "once", 0)
	fixture.graph_edit.connect_node("reset", 0, "once", 1)
	fixture.graph_edit.connect_node("once", 0, "wait", 0)
	fixture.graph_edit.connect_node("direct", 0, "wait", 0)
	fixture.graph_edit.connect_node("wait", 0, "branch", 0)
	fixture.graph_edit.connect_node("branch", 0, "yes", 0)
	fixture.graph_edit.connect_node("branch", 1, "no", 0)
	var chains := Builder.build(fixture)
	check(Builder.is_required(fixture), "Connected flow failed to select the new backend")
	check(chains.size() == 3 and not chains[0].has("compile_error"), "Graph extraction failed")
	var manager := Manager.new()
	var source := "extends Node3D\nvar hits: Array = []\nvar wait_seconds = 0.02\nvar choose_true = true\nfunc record(value):\n\thits.append(value)\n" + manager._generate_code_for_chains(fixture.current_node, chains)
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		var debug_file := FileAccess.open("user://execution_flow_failed.gd.txt", FileAccess.WRITE)
		debug_file.store_string(source)
		check(false, "Execution graph code failed to parse")
	else:
		var owner := Node3D.new()
		owner.set_script(script)
		root.add_child(owner)
		owner.call("fire")
		owner.call("fire")
		check(owner.get("hits").is_empty(), "Delay did not defer execution")
		await create_timer(0.06).timeout
		check(owner.get("hits") == [1], "Do Once or delayed True branch failed")
		owner.call("fire")
		await create_timer(0.04).timeout
		check(owner.get("hits") == [1], "Do Once fired again without Reset")
		owner.call("reset_once")
		check(owner.get("hits") == [1], "Reset executed Then")
		owner.set("choose_true", false)
		owner.call("fire")
		await create_timer(0.06).timeout
		check(owner.get("hits") == [1, 2], "Reset did not reopen the False branch")
		var other := Node3D.new()
		other.set_script(script)
		root.add_child(other)
		other.call("fire")
		await create_timer(0.06).timeout
		check(other.get("hits") == [1], "Do Once state leaked between instances")
		other.free()
		owner.call("direct_delay")
		owner.call("direct_delay")
		paused = true
		await create_timer(0.06, true).timeout
		check(owner.get("hits") == [1, 2], "Delay continued while SceneTree was paused")
		paused = false
		await create_timer(0.06).timeout
		check(owner.get("hits") == [1, 2, 2], "Delay accepted re-entry or failed to resume after pause")
		owner.call("reset_once")
		owner.call("fire")
		owner.free()
		await create_timer(0.04).timeout
	fixture.graph_edit.connect_node("yes", 0, "once", 0)
	check(Builder.build(fixture)[0].has("compile_error"), "Execution cycle accepted")
	fixture.graph_edit.free()
	fixture.current_node.free()
	# Real UI: the second input must be execution Reset, not a data pin.
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	var once = load(Registry.get_script_path("DoOnceExecution")).new()
	var visual := GraphNode.new()
	visual.set_meta("brick_data", {"brick_instance":once, "brick_class":"DoOnceExecution", "brick_type":"actuator"})
	panel._create_brick_ui(visual, once)
	panel._setup_value_input_pins(visual, "DoOnceExecution")
	panel.graph_edit.add_child(visual)
	await process_frame
	check(visual.is_slot_enabled_left(0) and visual.is_slot_enabled_left(1) and visual.get_slot_type_left(1) == 0, "Do Once Reset UI pin is missing or typed as data")
	visual.free()
	panel.free()
	print("Execution flow failures: %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
