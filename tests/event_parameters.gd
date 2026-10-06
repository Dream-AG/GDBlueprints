extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Signature = preload("res://addons/GDBlueprints/core/event_signature.gd")
const Dispatch = preload("res://addons/GDBlueprints/core/event_dispatch.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const SignatureEditor = preload("res://addons/GDBlueprints/ui/event_signature_editor.gd")

var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func definition(type: String, properties: Dictionary = {}) -> Dictionary:
	var brick = load(Registry.get_script_path(type)).new()
	brick.properties.merge(properties, true)
	return brick.serialize()

func signature(text: String) -> Dictionary:
	return {"parameters":text, "_applied_parameters":text}

func event_chain(name: String, parameters: String, entry: String, actions: Array) -> Dictionary:
	var properties := signature(parameters)
	properties.event_name = name
	return {"name":name, "sensors":[definition("CustomEventSensor", properties)], "controllers":[], "actuators":actions, "execution_entries":[{"to":entry,"input":"in"}]}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for invalid in ["amount", "same: Int, same: Float", "self: Int", "value: MissingType", "_flow: Int"]:
		check(not str(Signature.parse(invalid).error).is_empty(), "Accepted invalid signature: " + invalid)
	check(Signature.event_identifier("on-hit") == "on_hit", "Historical public event spelling changed")
	var receiver_script := GDScript.new()
	receiver_script.source_code = "extends RefCounted\nvar received := false\nfunc receive(node: Node, resource: Resource, amount: float, data: Dictionary) -> void:\n\treceived = node != null and resource != null and amount == 3.0 and data.get(\"health\") == 10\n"
	check(receiver_script.reload() == OK, "Typed receiver fixture failed to compile")
	var receiver = receiver_script.new()
	var reference := Node3D.new()
	var resource := Resource.new()
	check(Dispatch.dispatch(receiver, "receive", [reference, resource, 3, {"health":10}], false) and receiver.received, "Object arguments or numeric widening failed")
	check(not Dispatch.dispatch(receiver, "receive", [resource, resource, 3, {}], false), "Wrong Object subclass accepted")
	reference.free()
	var amount := Signature.output_expression("collect", "amount")
	var label := Signature.output_expression("collect", "label")
	var record := definition("CallObjectMethodActuator", {"method_name":"record", "arguments":"[[%s, %s]]" % [amount, label]})
	var delay := definition("DelayExecution", {"duration":0.02})
	# Read the concrete Delay property default rather than relying on old names.
	var delay_brick = load(Registry.get_script_path("DelayExecution")).new()
	for prop in delay_brick.get_property_definitions():
		if prop.name in ["seconds", "duration", "wait_time"]: delay.properties[prop.name] = 0.02
	var call_properties := signature("amount: Int, label: String")
	call_properties.merge({"event_name":"collect", "argument_amount":"bump()", "argument_label":'"once"'}, true)
	var call := definition("CallCustomEventActuator", call_properties)
	var chains: Array = [event_chain("collect", "amount: Int, label: String", "before", [record, delay, record]), event_chain("start", "", "call", [call])]
	chains[0].execution_graph = {"version":2, "nodes":{"before":record, "delay":delay, "after":record, "call":call}, "edges":[{"from":"before","output":"then","to":"delay","input":"in"}, {"from":"delay","output":"completed","to":"after","input":"in"}]}
	chains[0].execution_graph.edges[0].legacy_async = true
	check(Signature.validate_chains(chains).is_empty(), "Valid signatures rejected")
	var target := Node3D.new()
	var manager := Manager.new()
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar hits: Array = []\nvar counter := 0\nfunc bump():\n\tcounter += 1\n\treturn counter\nfunc record(value):\n\thits.append(value)\n" + manager._generate_code_for_chains(target, chains)
	var error := script.reload()
	check(error == OK, "Event graph failed to compile")
	if error == OK:
		target.set_script(script)
		root.add_child(target)
		target.set_process(false)
		target.call("collect", 10, "first")
		target.call("collect", 20, "second")
		var deadline := Time.get_ticks_msec() + 2000
		while target.hits.size() < 3 and Time.get_ticks_msec() < deadline: await process_frame
		check(target.hits == [[10, "first"], [20, "second"], [10, "first"]], "Overlapping event arguments were overwritten: " + str(target.hits))
		target.call("start")
		check(target.counter == 1 and target.hits.back() == [1, "once"], "Call arguments were not evaluated exactly once")
		check(not Dispatch.dispatch(target, "collect", ["wrong", 1], false), "Wrong types dispatched")
		check(not Dispatch.dispatch(target, "collect", [], false), "Wrong arity dispatched")
		check(not Dispatch.dispatch(null, "collect", [], false), "Null target dispatched")
		check(not Dispatch.dispatch(target, "missing_event", [], false), "Missing event dispatched")
	var outside := chains.duplicate(true)
	outside[1].actuators = [record]
	check(not Signature.validate_chains(outside).is_empty(), "Out-of-scope event argument accepted")
	var conflict := chains.duplicate(true)
	conflict.append(event_chain("collect", "other: Float", "before", []))
	check(not Signature.validate_chains(conflict).is_empty(), "Conflicting event declarations accepted")
	var unapplied := chains.duplicate(true)
	unapplied[0].sensors[0].properties.parameters = "new_amount: Float"
	check(not Signature.validate_chains(unapplied).is_empty(), "Unapplied signature accepted")
	var mismatch := chains.duplicate(true)
	mismatch[1].actuators[0].properties.merge(signature("amount: Float, label: String"), true)
	check(not Signature.validate_chains(mismatch).is_empty(), "Mismatched Self call accepted")
	target.free()
	await editor_checks()
	print("Event parameter failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func editor_checks() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = target
	var event = panel._create_graph_node("sensor", "CustomEventSensor", Vector2.ZERO)
	var event_id := str(event.name)
	var brick = event.get_meta("brick_data").brick_instance
	brick.properties.parameters = "amount: Int, label: String"
	check(SignatureEditor.apply(panel, event).is_empty(), "Editor failed to apply parameters")
	await process_frame
	await process_frame
	await process_frame
	event = panel.graph_edit.get_node(NodePath(event_id))
	check(event.has_node("ApplyParametersButton"), "Apply Parameters button missing")
	check(panel._get_value_output_info(event, 1).get("name") == "amount", "Typed output missing")
	var call = panel._create_graph_node("actuator", "CallCustomEventActuator", Vector2(400, 0))
	var call_id := str(call.name)
	call.get_meta("brick_data").brick_instance.properties.parameters = "amount: Int, label: String"
	check(SignatureEditor.apply(panel, call).is_empty(), "Call input signature failed")
	await process_frame
	await process_frame
	await process_frame
	event = panel.graph_edit.get_node(NodePath(event_id))
	call = panel.graph_edit.get_node(NodePath(call_id))
	panel.graph_edit.connect_node(event.name, 1, call.name, 2)
	panel._save_graph_to_metadata("Connect argument", false)
	event.get_meta("brick_data").brick_instance.properties.parameters = "label: String, amount: Int"
	check(SignatureEditor.apply(panel, event).is_empty(), "Reordering parameters failed")
	await process_frame
	await process_frame
	await process_frame
	event = panel.graph_edit.get_node(NodePath(event_id))
	check(panel.graph_edit.is_node_connected(event_id, 2, call_id, 2), "Wire did not follow parameter name")
	check(int(target.get_meta("blueprints_for_godot_graph").execution_version) == 3, "Parameterized graph lacks version guard")
	var scene := PackedScene.new()
	check(scene.pack(target) == OK, "Could not pack event metadata")
	check(ResourceSaver.save(scene, "res://event_parameters_fixture.tscn") == OK, "Could not save event metadata")
	var loaded = load("res://event_parameters_fixture.tscn").instantiate()
	check(loaded.get_meta("blueprints_for_godot_graph") == target.get_meta("blueprints_for_godot_graph"), "Event signatures or wiring changed on disk reload")
	loaded.free()
	event.get_meta("brick_data").brick_instance.properties.parameters = "label: String, amount: String"
	check(not SignatureEditor.apply(panel, event).is_empty(), "Incompatible connected parameter change accepted")
	event.get_meta("brick_data").brick_instance.properties.parameters = "label: String"
	check(not SignatureEditor.apply(panel, event).is_empty(), "Connected parameter removal accepted")
	check(panel.graph_edit.is_node_connected(event_id, 2, call_id, 2), "Rejected signature edit changed wires")
	panel.free()
	target.free()
