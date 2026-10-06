@tool
extends RefCounted
const ObjectPropertyBrowser = preload("res://addons/GDBlueprints/ui/object_property_browser.gd")
var panel
func setup(target_panel) -> void:
	panel = target_panel

func _resolve_property_reference(source: GraphNode, output_port: int = 0) -> Node:
	if not is_instance_valid(panel.current_node) or not is_instance_valid(source):
		return null
	if source.has_meta("value_node") and output_port == 0:
		var info: Dictionary = source.get_meta("value_node")
		if str(info.get("kind", "")) == "node":
			return panel.current_node.get_node_or_null(NodePath(str(info.get("node_path", ""))))
	if source.has_meta("brick_data"):
		var data: Dictionary = source.get_meta("brick_data")
		if data.get("brick_class", "") == "GetNodeByPathActuator" and str(panel._get_value_output_info(source, output_port).get("name", "")) == "Node":
			var path := str(data.brick_instance.get_property("node_path", ""))
			return panel.current_node.get_node_or_null(NodePath(path)) if not path.is_empty() else null
	return null


func _resolve_property_target(graph_node: GraphNode) -> Node:
	if not is_instance_valid(panel.current_node):
		return null
	var ports: Dictionary = graph_node.get_meta("value_input_ports", {})
	for connection in panel.graph_edit.get_connection_list():
		if str(connection.to_node) == str(graph_node.name) and str(ports.get(int(connection.to_port), "")) == "target":
			return _resolve_property_reference(panel.graph_edit.get_node_or_null(NodePath(connection.from_node)), int(connection.from_port))
	var instance = graph_node.get_meta("brick_data").brick_instance
	# Never evaluate arbitrary expressions, or silently browse self for a dynamic target.
	if not str(instance.get_property("target_expression", "")).is_empty():
		return null
	var path := str(instance.get_property("target", "self")).strip_edges()
	return panel.current_node if path.is_empty() or path.to_lower() == "self" else panel.current_node.get_node_or_null(NodePath(path))


func _browse_object_property(graph_node: GraphNode) -> void:
	var browser := ObjectPropertyBrowser.new()
	panel.add_child(browser)
	var owner_node: Node = panel.current_node
	var mode := "set" if graph_node.get_meta("brick_data").brick_class == "SetObjectPropertyActuator" else "get"
	browser.configure(_resolve_property_target(graph_node), func(entry: Dictionary, _operation: String):
		if panel.current_node != owner_node or not is_instance_valid(graph_node):
			return
		var error := preload("res://addons/GDBlueprints/ui/event_signature_editor.gd").apply(panel, graph_node, {"property_name":str(entry.name), "_property_type":str(entry.get("type", "Variant"))})
		if not error.is_empty(): push_warning(error)
	, mode)


func _browse_reference_properties(source: GraphNode) -> void:
	var browser := ObjectPropertyBrowser.new()
	panel.add_child(browser)
	var owner_node: Node = panel.current_node
	browser.configure(_resolve_property_reference(source), func(entry: Dictionary, operation: String):
		if panel.current_node != owner_node or not is_instance_valid(source):
			return
		var before: Dictionary = panel._take_graph_snapshot()
		var class_id := "SetObjectPropertyActuator" if operation == "set" else "GetObjectPropertyActuator"
		var created: GraphNode = panel._create_graph_node("actuator", class_id, source.position_offset + Vector2(source.size.x + 60, 0))
		if created == null:
			return
		created.get_meta("brick_data").brick_instance.set_property("property_name", str(entry.name))
		var control: Control = panel._find_property_control(created, "property_name")
		if control is LineEdit:
			control.text = str(entry.name)
		var ports: Dictionary = created.get_meta("value_input_ports", {})
		for port in ports:
			if str(ports[port]) == "target":
				panel.graph_edit.connect_node(source.name, 0, created.name, int(port))
				panel._apply_value_binding(created, "target", source, 0)
				break
		created.get_meta("brick_data").brick_instance.set_property("_property_type", str(entry.get("type", "Variant")))
		panel._save_graph_to_metadata("Add Object Property", false)
		panel._restore_graph_snapshot(panel._take_graph_snapshot())
		panel._record_undo("Add Object Property", before, panel._take_graph_snapshot())
	)



