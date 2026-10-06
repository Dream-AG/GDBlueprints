extends "res://addons/GDBlueprints/tests/graph_functions.gd"

const Members = preload("res://addons/GDBlueprints/core/member_catalog.gd")
const MemberEditor = preload("res://addons/GDBlueprints/ui/member_editor.gd")
const Signals = preload("res://addons/GDBlueprints/core/signal_dispatch.gd")
const Region = preload("res://addons/GDBlueprints/core/generated_region.gd")

class Emitter extends Node:
	signal changed(amount: int, tags: Array[String])
	var received: Array = []
	func untyped_default(value = 5): return value
	func compute(amount: int, bonus: int = 3) -> int: return amount + bonus
	func record_change(amount: int, tags: Array[String]) -> void: received.append([amount, tags])
	func no_arguments() -> void: received.append("legacy")

func _run() -> void:
	var source := Emitter.new()
	root.add_child(source)
	var method: Dictionary = {}
	var signal_info: Dictionary = {}
	for entry in Members.collect(source):
		if entry.name == "compute": method = entry
		if entry.name == "untyped_default": check(entry.defaults.argument_value == "5", "Untyped reflected default lost")
	for entry in Members.collect(source, true):
		if entry.name == "changed": signal_info = entry
	check(method.parameters == "amount: int, bonus: int" and method.defaults.argument_bonus == "3", "Reflected method defaults/signature")
	check(signal_info.parameters == "amount: int, tags: Array[String]", "Reflected signal collection type")
	check(Signals.connect_event(source, "changed", source, "record_change", true), "Typed signal connection")
	check(Signals.connect_event(source, "changed", source, "record_change", true), "Duplicate connect is not idempotent")
	check(Signals.emit_checked(source, "changed", [7, ["a"]]), "Typed signal emission")
	check(source.received.size() == 1 and source.received[0] == [7, ["a"]], "Signal values changed or callback duplicated")
	check(not Signals.emit_checked(source, "changed", ["bad", []]), "Invalid signal argument was emitted")
	check(Signals.connect_event(source, "changed", source, "record_change", true, true), "Disconnect failed")
	Signals.emit_checked(source, "changed", [8, []])
	check(source.received.size() == 1, "Disconnected callback still called")
	check(Signals.connect_event(source, "changed", source, "no_arguments", false), "Legacy no-argument callback")
	Signals.emit_checked(source, "changed", [9, []])
	check(source.received.back() == "legacy", "Legacy callback did not discard arguments")
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = source
	var call: GraphNode = panel._create_graph_node("actuator", "CallGraphFunction", Vector2.ZERO)
	var call_id := str(call.name)
	check(MemberEditor.apply_member(panel, call, method).is_empty(), "Reflected method application")
	for i in 3: await process_frame
	call = panel.graph_edit.get_node(NodePath(call_id))
	check(call.get_meta("brick_data").brick_instance.properties.argument_bonus == "3", "Editor lost optional argument default")
	check(panel._get_value_output_info(call, 2).type == "int", "Result pin is not reflected")
	var connection: GraphNode = panel._create_graph_node("actuator", "ConnectSignalActuator", Vector2(200, 0))
	var connection_id := str(connection.name)
	check(MemberEditor.apply_member(panel, connection, signal_info).is_empty(), "Signal picker application")
	for i in 3: await process_frame
	connection = panel.graph_edit.get_node(NodePath(connection_id))
	check(MemberEditor.create_signal_event(panel, connection).is_empty(), "Signal event creation")
	for i in 3: await process_frame
	var event: GraphNode
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.has_meta("brick_data") and child.get_meta("brick_data").brick_class == "CustomEventSensor": event = child
	check(event != null and panel._get_value_output_info(event, 2).type == "Array[String]", "Signal event typed outputs missing")
	panel._save_graph_to_metadata("Test reflection", false)
	var saved: Dictionary = source.get_meta("blueprints_for_godot_graph").duplicate(true)
	await panel._load_graph_from_metadata()
	await process_frame
	check(source.get_meta("blueprints_for_godot_graph").nodes == saved.nodes, "Reflected graph changed on reload")
	panel.free()
	source.free()
	generated_signal_callback()
	external_file_roundtrip()
	global_file_roundtrip()
	var sealed := "extends Node\n" + Region.START + "\n" + Region.seal("var generated := 1") + Region.END + "\nfunc handwritten(): return 2\n"
	check(Region.edit_error(sealed).is_empty(), "Unmodified generated block rejected")
	check(Region.edit_error(sealed.replace("return 2", "return 3")).is_empty(), "Handwritten edit rejected")
	check(not Region.edit_error(sealed.replace("generated := 1", "generated := 2")).is_empty(), "Generated edit would be overwritten")
	check(Region.edit_error(sealed.replace("\n", "\r\n")).is_empty(), "CRLF conversion invalidated generated hash")
	print("Milestone 3 interoperability failures: ", failures)
	quit(0 if failures.is_empty() else 1)


func generated_signal_callback() -> void:
	var f := Fixture.new()
	var params := "amount: int, tags: Array[String]"
	add(f, "entry", "CustomEventSensor", {"event_name":"receive_change", "parameters":params, "_applied_parameters":params})
	add(f, "record", "CallGraphFunction", signature("record", "value: Variant", "void"))
	f.graph_edit.get_node("record").get_meta("brick_data").brick_instance.properties.argument_value = '[_flow.event_arguments["receive_change"]["amount"], _flow.event_arguments["receive_change"]["tags"]]'
	wire(f, "entry", "record")
	var receiver := compile(f)
	if receiver != null:
		var source := Emitter.new()
		root.add_child(source)
		check(Signals.connect_event(source, "changed", receiver, "receive_change", true), "Signal to generated event did not connect")
		Signals.emit_checked(source, "changed", [13, ["graph"]])
		check(receiver.hits == [[13, ["graph"]]], "Signal arguments did not reach graph and handwritten helper")
		source.free()
		receiver.free()
	f.dispose()

func external_file_roundtrip() -> void:
	var path := "res://interop_preservation_fixture.gd"
	var manual := "extends Node\nvar handwritten := 7\nfunc helper(): return handwritten\n"
	FileAccess.open(path, FileAccess.WRITE).store_string(manual)
	var node := Node.new()
	root.add_child(node)
	node.set_script(load(path))
	check(manager.regenerate_script(node), "Initial guarded generation")
	var first := FileAccess.get_file_as_string(path)
	var edited := first.replace("handwritten := 7", "handwritten := 9")
	FileAccess.open(path, FileAccess.WRITE).store_string(edited)
	check(manager.regenerate_script(node), "Saved external handwritten edit rejected")
	var second := FileAccess.get_file_as_string(path)
	check(second.contains("handwritten := 9") and second.contains("func helper(): return handwritten"), "External handwritten source was lost")
	check(Region.edit_error(second).is_empty(), "Generator wrote an invalid checksum")
	node.free()


func global_file_roundtrip() -> void:
	var path := "res://addons/GDBlueprints/global_vars.gd"
	var original := FileAccess.get_file_as_string(path)
	var manual := "extends Node\nfunc helper(): return 42\nfunc _init(): push_error(\"Global declaration discovery executed user code\")\n"
	FileAccess.open(path, FileAccess.WRITE).store_string(manual)
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	var owner := Node.new()
	root.add_child(owner)
	panel.current_node = owner
	panel.global_vars_data.append({"name":"inventory", "type":"Dictionary[String, int]", "value":{"potion":3}})
	panel.global_vars_data.append({"name":"status", "type":"Enum[Idle=0, Running=10]", "value":10})
	panel._update_global_vars_script()
	var generated := FileAccess.get_file_as_string(path)
	check(generated.begins_with(manual), "Handwritten global declarations were replaced")
	var records: Array = panel._read_global_vars_from_script()
	check(records.size() == 2 and records[0].type == "Dictionary[String, int]" and records[0].value == {"potion":3}, "Global collection schema/default roundtrip")
	check(records.size() == 2 and records[1].type == "Enum[Idle=0, Running=10]" and records[1].value == 10, "Global enum schema/default roundtrip")
	check(manager._read_global_vars_from_script() == records, "Compiler and editor disagree on global declarations")
	check(Region.edit_error(generated, "# === GDBLUEPRINTS GLOBALS START ===", "# === GDBLUEPRINTS GLOBALS END ===").is_empty(), "Globals checksum invalid")
	panel.free()
	owner.free()
	FileAccess.open(path, FileAccess.WRITE).store_string(original)
