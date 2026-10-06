@tool
extends RefCounted

const Browser = preload("res://addons/GDBlueprints/ui/member_browser.gd")
const SignatureEditor = preload("res://addons/GDBlueprints/ui/event_signature_editor.gd")

static func browse(panel, visual: GraphNode) -> void:
	var id := str(visual.get_meta("brick_data").brick_class)
	var signals := id in ["ConnectSignalActuator", "EmitTypedSignal"]
	var browser := Browser.new()
	panel.add_child(browser)
	var owner: Node = panel.current_node
	browser.configure(panel._reference_helper._resolve_property_target(visual), signals, func(entry: Dictionary):
		if not is_instance_valid(visual) or panel.current_node != owner: return
		var error := apply_member(panel, visual, entry)
		if not error.is_empty(): push_warning(error)
	)

static func apply_member(panel, visual: GraphNode, entry: Dictionary) -> String:
	if entry.get("unsupported", false): return "Variadic methods require a handwritten fixed-signature helper."
	var id := str(visual.get_meta("brick_data").brick_class)
	if id == "ConnectSignalActuator":
		var before: Dictionary = panel._take_graph_snapshot()
		var props: Dictionary = visual.get_meta("brick_data").brick_instance.properties
		props.signal_name = entry.name
		props.forward_arguments = true
		props._signal_parameters = entry.parameters
		panel._save_graph_to_metadata("Choose Signal", false)
		var after: Dictionary = panel._take_graph_snapshot()
		panel._restore_graph_snapshot(after)
		panel._record_undo("Choose Signal", before, after)
		return ""
	var proposed := {"parameters":entry.parameters}
	if id == "EmitTypedSignal": proposed.signal_name = entry.name
	else:
		proposed["function_name" if id == "CallGraphFunction" else "event_name"] = entry.name
		if id == "CallGraphFunction": proposed.return_type = entry.return_type
	var props: Dictionary = visual.get_meta("brick_data").brick_instance.properties
	for key in entry.get("defaults", {}):
		if not props.has(key): proposed[key] = entry.defaults[key]
	return SignatureEditor.apply(panel, visual, proposed)

static func create_signal_event(panel, visual: GraphNode) -> String:
	var props: Dictionary = visual.get_meta("brick_data").brick_instance.properties
	if not props.has("_signal_parameters"): return "Choose a signal with Browse Signals first."
	var name := SignatureEditor.Signature.event_identifier(str(props.event_name))
	for child in panel.graph_edit.get_children():
		if not child is GraphNode or not child.has_meta("brick_data"): continue
		var data: Dictionary = child.get_meta("brick_data")
		if str(data.brick_class) != "CustomEventSensor": continue
		if SignatureEditor.Signature.event_identifier(str(data.brick_instance.properties.event_name)) == name:
			return SignatureEditor.apply(panel, child, {"parameters":props._signal_parameters})
	var before: Dictionary = panel._take_graph_snapshot()
	var event: GraphNode = panel._create_graph_node("sensor", "CustomEventSensor", visual.position_offset + Vector2(350, 0))
	if event == null: return "Could not create the Custom Event."
	event.get_meta("brick_data").brick_instance.properties.merge({"event_name":name, "parameters":props._signal_parameters, "_applied_parameters":props._signal_parameters}, true)
	panel._save_graph_to_metadata("Create Signal Event", false)
	var after: Dictionary = panel._take_graph_snapshot()
	panel._restore_graph_snapshot(after)
	panel._record_undo("Create Signal Event", before, after)
	return ""
