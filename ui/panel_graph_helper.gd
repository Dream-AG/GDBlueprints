extends RefCounted

var panel = null
const ExecutionGraphBuilder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")

func setup(target_panel) -> void:
	panel = target_panel

func sync_graph_ui_to_bricks() -> void:
	for graph_node in panel.graph_edit.get_children():
		if not (graph_node is GraphNode):
			continue
		if not graph_node.has_meta("brick_data"):
			continue

		var brick_data = graph_node.get_meta("brick_data")
		var brick_instance = brick_data.get("brick_instance", null)
		if brick_instance == null:
			continue

		for child in graph_node.get_children():
			if not child.has_meta("property_name"):
				continue

			var property_name = str(child.get_meta("property_name"))
			var control = child.get_node_or_null("PropertyControl_" + property_name)

			if control is Control and bool(control.get_meta("bfg_value_bound", false)):
				continue

			if control == null:
				if child is CheckBox:
					brick_instance.set_property(property_name, child.button_pressed)
				continue

			if control is SpinBox:
				var spinbox: SpinBox = control
				var current_value = spinbox.value
				var property_type = TYPE_NIL
				for prop_def in brick_instance.get_property_definitions():
					if prop_def.get("name", "") == property_name:
						property_type = int(prop_def.get("type", TYPE_NIL))
						break
				if property_type == TYPE_INT:
					brick_instance.set_property(property_name, int(current_value))
				else:
					brick_instance.set_property(property_name, current_value)
			elif control is CheckBox:
				brick_instance.set_property(property_name, control.button_pressed)
			elif control is OptionButton:
				var option_button: OptionButton = control
				var selected = option_button.selected
				if selected >= 0:
					var value = option_button.get_item_metadata(selected)
					if value == null:
						value = option_button.get_item_text(selected).to_lower().replace(" ", "_")
					brick_instance.set_property(property_name, value)
			elif control is LineEdit:
				var line_edit: LineEdit = control
				if bool(line_edit.get_meta("bfg_value_bound", false)):
					continue
				if not line_edit.editable and not line_edit.tooltip_text.is_empty():
					brick_instance.set_property(property_name, line_edit.tooltip_text)
				else:
					brick_instance.set_property(property_name, line_edit.text)
			elif control is ColorPickerButton:
				brick_instance.set_property(property_name, control.color)

func is_brick_in_complete_chain(graph_node: GraphNode, connections: Array) -> bool:
	if not graph_node.has_meta("brick_data"):
		return true
	var brick_data: Dictionary = graph_node.get_meta("brick_data")
	var brick_type := str(brick_data.get("brick_type", ""))
	if brick_type == "sensor":
		return _sensor_reaches_terminal(graph_node, connections, {})
	if brick_type == "controller":
		return _controller_has_trigger_upstream(graph_node, connections, {}) and _controller_reaches_terminal(graph_node, connections, {})
	if brick_type == "actuator":
		return _actuator_has_trigger_upstream(graph_node, connections)
	return true


func _sensor_reaches_terminal(sensor_node: GraphNode, connections: Array, visited: Dictionary) -> bool:
	if visited.has(sensor_node.name):
		return false
	var next_visited := visited.duplicate()
	next_visited[sensor_node.name] = true
	for output_node in trace_outputs(sensor_node.name, connections):
		if not output_node.has_meta("brick_data"):
			continue
		var data: Dictionary = output_node.get_meta("brick_data")
		var output_type := str(data.get("brick_type", ""))
		if output_type == "actuator":
			return true
		if output_type == "controller" and _controller_reaches_terminal(output_node, connections, next_visited):
			return true
	return false


func _controller_has_trigger_upstream(controller_node: GraphNode, connections: Array, visited: Dictionary) -> bool:
	if visited.has(controller_node.name):
		return false
	var next_visited := visited.duplicate()
	next_visited[controller_node.name] = true
	for input_node in trace_inputs(controller_node.name, connections):
		if not input_node.has_meta("brick_data"):
			continue
		var data: Dictionary = input_node.get_meta("brick_data")
		var brick_type := str(data.get("brick_type", ""))
		if brick_type == "sensor":
			return true
		if brick_type == "controller" and _controller_has_trigger_upstream(input_node, connections, next_visited):
			return true
	return false


func _controller_reaches_terminal(controller_node: GraphNode, connections: Array, visited: Dictionary) -> bool:
	if visited.has(controller_node.name):
		return false
	var data: Dictionary = controller_node.get_meta("brick_data")
	if str(data.get("brick_class", "")) == "ScriptController":
		return true
	var next_visited := visited.duplicate()
	next_visited[controller_node.name] = true
	for output_node in trace_outputs(controller_node.name, connections):
		if not output_node.has_meta("brick_data"):
			continue
		var output_data: Dictionary = output_node.get_meta("brick_data")
		var brick_type := str(output_data.get("brick_type", ""))
		if brick_type == "actuator":
			return true
		if brick_type == "controller" and _controller_reaches_terminal(output_node, connections, next_visited):
			return true
	return false


func _actuator_has_trigger_upstream(actuator_node: GraphNode, connections: Array, visited: Dictionary = {}) -> bool:
	if visited.has(actuator_node.name):
		return false
	var next_visited := visited.duplicate()
	next_visited[actuator_node.name] = true
	for input_node in trace_inputs(actuator_node.name, connections):
		if not input_node.has_meta("brick_data"):
			continue
		var data: Dictionary = input_node.get_meta("brick_data")
		var input_type := str(data.get("brick_type", ""))
		if input_type == "sensor":
			return true
		if input_type == "controller" and _controller_has_trigger_upstream(input_node, connections, {}):
			return true
		if input_type == "actuator" and _actuator_has_trigger_upstream(input_node, connections, next_visited):
			return true
	return false


func extract_chains_from_graph(_include_incomplete: bool = false) -> Array:
	return ExecutionGraphBuilder.build(panel)

func trace_inputs(node_name: String, connections: Array) -> Array:
	var results = []
	for conn in connections:
		# Controllers receive execution on port 0. Ignore data-pin wires.
		if conn["to_node"] == node_name and int(conn.get("to_port", 0)) == 0:
			var from_node = panel.graph_edit.get_node_or_null(NodePath(conn["from_node"]))
			if from_node:
				if from_node.has_meta("is_reroute"):
					results.append_array(trace_inputs(from_node.name, connections))
				else:
					results.append(from_node)
	return results

func trace_outputs_for_port(node_name: String, output_port: int, connections: Array) -> Array:
	var results = []
	for conn in connections:
		if conn["from_node"] == node_name and int(conn["from_port"]) == output_port:
			var to_node = panel.graph_edit.get_node_or_null(NodePath(conn["to_node"]))
			if to_node:
				if to_node.has_meta("is_reroute"):
					results.append_array(trace_outputs(to_node.name, connections))
				else:
					results.append(to_node)
	return results


func trace_outputs(node_name: String, connections: Array) -> Array:
	var results = []
	for conn in connections:
		# Normal executable nodes use output port 0 for exec. Typed data outputs
		# live on higher ports and must never become execution-chain edges.
		if conn["from_node"] == node_name and int(conn.get("from_port", 0)) == 0:
			var to_node = panel.graph_edit.get_node_or_null(NodePath(conn["to_node"]))
			if to_node:
				if to_node.has_meta("is_reroute"):
					results.append_array(trace_outputs(to_node.name, connections))
				else:
					results.append(to_node)
	return results

func get_chain_name_for_controller(controller_node: GraphNode) -> String:
	if controller_node.has_meta("brick_data"):
		var brick_data = controller_node.get_meta("brick_data")
		var brick_class = brick_data["brick_class"]
		return brick_class.to_lower().replace("controller", "") + "_" + controller_node.name.replace("brick_node_", "")

	return controller_node.name.replace("brick_node_", "chain_")
