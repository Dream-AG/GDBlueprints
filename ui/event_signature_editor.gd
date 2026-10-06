extends RefCounted

const Signature = preload("res://addons/GDBlueprints/core/event_signature.gd")
const Pins = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")

static func _inputs(brick) -> Dictionary:
	var result: Dictionary = {}
	var port: int = brick.get_exec_input_definitions().size()
	for definition in brick.get_property_definitions():
		if not bool(definition.get("blueprint_pin", false)): continue
		result[port] = {"name":str(definition.name), "type":str(definition.get("pin_type", "Variant"))}
		port += 1
	return result

static func _outputs(brick) -> Dictionary:
	var result: Dictionary = {}
	if not brick.has_method("get_value_output_definitions"): return result
	var port: int = maxi(1, brick.get_exec_output_definitions().size())
	for definition in brick.get_value_output_definitions():
		result[port] = {"name":str(definition.name), "type":str(definition.type)}
		port += 1
	return result

static func _find(ports: Dictionary, name: String) -> int:
	for port in ports:
		if ports[port].name == name: return int(port)
	return -1

static func use_local_definition(panel, visual: GraphNode) -> String:
	var data: Dictionary = visual.get_meta("brick_data")
	var brick = data.brick_instance
	if str(brick.properties.get("target", "self")).strip_edges().to_lower() not in ["", "self"] or str(brick.properties.get("target_expression", "")).strip_edges() not in ["", "self"]:
		return "Use Local Definition applies to Self. For another target, enter its public method signature."
	var is_function := str(data.brick_class) == "CallGraphFunction"
	var field := "function_name" if is_function else "event_name"
	var definition_type := "FunctionEntry" if is_function else "CustomEventSensor"
	var name := Signature.event_identifier(str(brick.properties.get(field, "")))
	var definition: Dictionary = {}
	for child in panel.graph_edit.get_children():
		if not child is GraphNode or not child.has_meta("brick_data"): continue
		var candidate: Dictionary = child.get_meta("brick_data")
		if str(candidate.brick_class) != definition_type: continue
		var props: Dictionary = candidate.brick_instance.properties
		if Signature.event_identifier(str(props.get(field, ""))) != name: continue
		var errors := Signature.warnings(props)
		if not errors.is_empty(): return "Apply the definition's signature first. " + "; ".join(errors)
		if not definition.is_empty() and (is_function or Signature.identity(definition) != Signature.identity(props)):
			return "Resolve duplicate or conflicting definitions before copying the signature."
		definition = props
	if definition.is_empty(): return "No matching definition exists in this node's graph."
	brick.properties.parameters = str(definition.get("_applied_parameters", ""))
	if is_function: brick.properties.return_type = str(definition.get("_applied_return_type", "Variant"))
	for property in ["parameters", "return_type"]:
		var control = panel._find_property_control(visual, property)
		if control is LineEdit: control.text = str(brick.properties.get(property, ""))
	return apply(panel, visual)

## Returns an explanation on rejection. Mutations occur only after every wire
## has been checked; snapshot restore supplies the existing undo/redo behavior.
static func apply(panel, visual: GraphNode, proposed: Dictionary = {}) -> String:
	var brick = visual.get_meta("brick_data").brick_instance
	var pending := str(proposed.get("parameters", brick.properties.get("parameters", "")))
	var parsed := Signature.parse(pending)
	if not str(parsed.error).is_empty(): return parsed.error
	var candidate = brick.get_script().new()
	candidate.properties = brick.properties.duplicate(true)
	candidate.properties.merge(proposed, true)
	candidate.properties._applied_parameters = pending
	if candidate.properties.has("return_type"):
		candidate.properties._applied_return_type = Signature.return_type(str(candidate.properties.return_type))
	if candidate.properties.has("locals"):
		candidate.properties._applied_locals = str(candidate.properties.locals)
	var errors := Signature.warnings(candidate.properties)
	if not errors.is_empty(): return "; ".join(errors)
	var old_inputs := _inputs(brick)
	var new_inputs := _inputs(candidate)
	var old_outputs := _outputs(brick)
	var new_outputs := _outputs(candidate)
	var rewired: Array = []
	for connection in panel.graph_edit.get_connection_list():
		var updated: Dictionary = connection.duplicate()
		var source_type := ""
		var target_type := ""
		if str(connection.from_node) == str(visual.name) and old_outputs.has(int(connection.from_port)):
			var old: Dictionary = old_outputs[int(connection.from_port)]
			var replacement := _find(new_outputs, old.name)
			if replacement < 0: return "Disconnect parameter %s before removing or renaming it." % old.name
			updated.from_port = replacement
			source_type = new_outputs[replacement].type
		if str(connection.to_node) == str(visual.name) and old_inputs.has(int(connection.to_port)):
			var old: Dictionary = old_inputs[int(connection.to_port)]
			var replacement := _find(new_inputs, old.name)
			if replacement < 0: return "Disconnect parameter %s before removing or renaming it." % old.name
			updated.to_port = replacement
			target_type = new_inputs[replacement].type
		if not source_type.is_empty() or not target_type.is_empty():
			var source = panel.graph_edit.get_node_or_null(NodePath(connection.from_node))
			var target = panel.graph_edit.get_node_or_null(NodePath(connection.to_node))
			if source_type.is_empty(): source_type = str(panel._get_value_output_info(source, int(connection.from_port)).get("type", "Variant"))
			if target_type.is_empty(): target_type = str(target.get_meta("value_input_types", {}).get(int(connection.to_port), "Variant"))
			if not Pins.compatible(source_type, target_type):
				return "Disconnect incompatible %s to %s wires before changing parameter types." % [source_type, target_type]
		rewired.append(updated)
	panel._save_graph_to_metadata("Edit Event Parameters", false)
	var before: Dictionary = panel._take_graph_snapshot()
	var after: Dictionary = before.duplicate(true)
	for record in after.graph.nodes:
		if str(record.id) != str(visual.name): continue
		record.properties.merge(proposed, true)
		record.properties._applied_parameters = pending
		for field in ["_applied_return_type", "_applied_locals"]:
			if candidate.properties.has(field): record.properties[field] = candidate.properties[field]
		for parameter in Signature.parameters(brick.properties):
			if _find(new_inputs, "argument_" + str(parameter.name)) < 0:
				record.properties.erase("argument_" + str(parameter.name))
				record.properties.erase("argument_" + str(parameter.name) + "_expression")
	after.graph.connections = rewired
	panel._restore_graph_snapshot(after)
	panel._record_undo("Apply Function Signature" if candidate.properties.has("return_type") else "Apply Event Parameters", before, after)
	return ""
