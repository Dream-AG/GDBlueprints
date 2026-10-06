extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Catalog = preload("res://addons/GDBlueprints/core/object_property_catalog.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const Browser = preload("res://addons/GDBlueprints/ui/object_property_browser.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for domain in ["", "3d", "2d", "ui"]:
		var classes: Array = []
		for entry in Registry.get_all_bricks(domain):
			classes.append(entry["class"])
		for required in ["PrintStringActuator", "CallCustomEventActuator", "GetObjectPropertyActuator", "SetObjectPropertyActuator", "CallObjectMethodActuator", "ConnectSignalActuator", "EmitSignalActuator"]:
			check(required in classes, "%s missing in %s" % [required, domain])
		if domain == "ui":
			check("UIVisibilityActuator" in classes and "VisibilityActuator" not in classes, "UI replacement filtering")
			check("MotionActuator" not in classes, "3D-only node leaked into UI")
	var scene := Node3D.new()
	root.add_child(scene)
	var owner_node := Control.new()
	owner_node.name = "UI"
	scene.add_child(owner_node)
	var target := Label.new()
	target.name = "Label"
	owner_node.add_child(target)
	target.set_meta("blueprints_for_godot_variables", [{"name":"score", "type":"int"}])
	var entries := Catalog.collect(target)
	check(entries.any(func(e): return e.name == "text" and e.type == "String"), "Label.text missing")
	check(entries.any(func(e): return e.name == "score" and e.type == "int"), "Uncompiled Blueprint variable missing")
	check(not entries.any(func(e): return str(e.name).begins_with("metadata/")), "Internal metadata exposed")
	var script := GDScript.new()
	script.source_code = "extends Label\n@export var health: int = 10\nvar other_value: float = 2.0\n"
	check(script.reload() == OK, "Fixture script parses")
	target.set_script(script)
	entries = Catalog.collect(target)
	check(entries.any(func(e): return e.name == "health" and e.source == "Script"), "Exported script variable missing")
	check(entries.any(func(e): return e.name == "other_value"), "Script member missing")
	var readonly: Dictionary = {}
	Catalog._add_properties(readonly, [{"name":"readonly", "type":TYPE_INT, "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY}], "Godot")
	check(readonly.readonly.read_only, "Read-only metadata lost")
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = owner_node
	panel.graph_edit.visible = true
	check(panel._get_selected_node_domain() == "ui", "Child Control domain")
	var reference := GraphNode.new()
	reference.name = "reference"
	panel._build_value_node_visual(reference, {"kind":"node", "name":"Label", "node_path":"Label", "type":"Label", "expression":"get_node(\"Label\")"})
	panel.graph_edit.add_child(reference)
	await process_frame
	check(reference.get_output_port_count() == 1, "Browse button changed reference ports: %d" % reference.get_output_port_count())
	check(panel._resolve_property_reference(reference) == target, "Child-relative reference resolution")
	panel._browse_reference_properties(reference)
	var browser: AcceptDialog = panel.get_children().filter(func(n): return n is Browser)[0]
	browser._filter("text")
	check(browser._list.item_count > 0, "Search has no text property")
	browser._selected.call({"name":"text"}, "set")
	browser.queue_free()
	var setters := panel.graph_edit.get_children().filter(func(n): return n.has_meta("brick_data") and n.get_meta("brick_data").brick_class == "SetObjectPropertyActuator")
	check(setters.size() == 1, "Browser did not create setter")
	var setter: GraphNode = setters[0]
	check(panel._resolve_property_target(setter) == target, "Connected target resolution")
	check(panel.graph_edit.get_connection_list().size() == 1, "Property node not wired")
	check(setter.get_meta("brick_data").brick_instance.get_property("property_name") == "text", "Property selection lost")
	check(setter.get_meta("brick_data").brick_instance.get_property("target_expression") == "get_node(\"Label\")", "Target expression not bound")
	check(setter.find_child("PropertyControl_property_name", true, false).get_parent().get_child_count() == 3, "Property Browse button missing")
	var graph: Dictionary = owner_node.get_meta("blueprints_for_godot_graph")
	check(graph.connections.size() == 1 and graph.nodes.size() == 2, "Graph serialization missing browser-created nodes")
	# Run the actual generated setter against a child Label, not just its metadata.
	var setter_instance = setter.get_meta("brick_data").brick_instance
	setter_instance.set_property("value", "Browser works")
	var generated_code: String = setter_instance.generate_ir(owner_node, "test").actuator[0].code
	var generated := GDScript.new()
	generated.source_code = "extends Control\nfunc run_property_test():\n\t" + generated_code.replace("\n", "\n\t") + "\n"
	check(generated.reload() == OK, "Generated setter does not parse")
	owner_node.set_script(generated)
	owner_node.call("run_property_test")
	check(target.text == "Browser works", "Generated setter did not update child Label")
	var getter = load("res://addons/GDBlueprints/bricks/actuators/common/get_object_property_actuator.gd").new()
	getter.set_property("target", "Label")
	var getter_script := GDScript.new()
	getter_script.source_code = "extends Control\nfunc read_property_test():\n\treturn " + str(getter.get_value_output_definitions()[0].expression) + "\n"
	check(getter_script.reload() == OK, "Generated getter does not parse")
	owner_node.set_script(getter_script)
	check(owner_node.call("read_property_test") == "Browser works", "Generated getter did not read child Label")
	for c in panel.graph_edit.get_connection_list():
		panel.graph_edit.disconnect_node(c.from_node, c.from_port, c.to_node, c.to_port)
	var instance = setter.get_meta("brick_data").brick_instance
	instance.set_property("target_expression", "")
	instance.set_property("target", "Label")
	check(panel._resolve_property_target(setter) == target, "Manual relative target")
	instance.set_property("target", "self")
	check(panel._resolve_property_target(setter) == owner_node, "Self resolves to graph owner, not scene root")
	instance.set_property("target_expression", "dynamic_target")
	check(panel._resolve_property_target(setter) == null, "Dynamic target incorrectly browses self")
	# Restore saved nodes and connections as the editor does on scene reopen.
	for child in panel.graph_edit.get_children():
		if child is GraphNode:
			panel.graph_edit.remove_child(child)
			child.queue_free()
	for node_data in graph.nodes:
		panel._create_graph_node_from_data(node_data)
	for connection in graph.connections:
		panel.graph_edit.connect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
	panel._sync_value_bindings_from_connections()
	var restored: GraphNode = panel.graph_edit.get_node(NodePath(str(graph.connections[0].to_node)))
	check(panel._resolve_property_target(restored) == target, "Restored property target lost")
	check(restored.get_meta("brick_data").brick_instance.get_property("property_name") == "text", "Restored property name lost")
	var missing := GraphNode.new()
	missing.set_meta("value_node", {"kind":"node", "node_path":"Missing"})
	check(panel._resolve_property_reference(missing) == null, "Missing target must not browse self")
	missing.free()
	# The legacy States tab is constructed off-tree by the existing panel.
	if is_instance_valid(panel.states_panel) and panel.states_panel.get_parent() == null:
		panel.states_panel.free()
	panel.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("0.4.7.2 regressions: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
