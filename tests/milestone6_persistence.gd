extends "res://addons/GDBlueprints/tests/graph_functions.gd"

const Codec = preload("res://addons/GDBlueprints/core/data_codec.gd")
const Saves = preload("res://addons/GDBlueprints/core/persistence.gd")
const Templates = preload("res://addons/GDBlueprints/core/template_store.gd")
var fixture_dir := "user://gdb_milestone6_" + str(Time.get_ticks_usec())

class State extends Node:
	var health: int = 10
	var items: Array[int] = [1, 2]
	var stats: Dictionary[String, int] = {"score":3}
	var transform_value := Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))

func _run() -> void:
	codec_roundtrip()
	file_roundtrip()
	state_preflight()
	generated_save_load()
	await template_roundtrip()
	large_graph()
	for file in DirAccess.get_files_at(fixture_dir): DirAccess.remove_absolute(fixture_dir.path_join(file))
	DirAccess.remove_absolute(fixture_dir)
	print("Milestone 6 persistence/project-scale failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func codec_roundtrip() -> void:
	var typed_array: Array[Vector3] = [Vector3(1, 2, 3)]
	var typed_dictionary: Dictionary[String, int] = {"coins":4}
	var values := [null, true, 9223372036854775806, 0.125, "hello\nworld", &"name", ^"Player/Camera", Vector2(1, 2), Vector2i(1, 2), Rect2(1, 2, 3, 4), Rect2i(1, 2, 3, 4), Vector3(1, 2, 3), Vector3i(1, 2, 3), Vector4(1, 2, 3, 4), Vector4i(1, 2, 3, 4), Transform2D.IDENTITY, Plane(Vector3.UP, 2), Quaternion.IDENTITY, AABB(Vector3.ZERO, Vector3.ONE), Basis.IDENTITY, Transform3D.IDENTITY, Projection.IDENTITY, Color(0.5, 0.25, 1, 1), [1, {"nested":Vector3.ONE}], {7:"integer key"}, PackedByteArray([0, 255]), PackedInt32Array([1, -2]), PackedInt64Array([9223372036854775806]), PackedFloat32Array([0.125]), PackedFloat64Array([0.125]), PackedStringArray(["a", "b"]), PackedVector2Array([Vector2.ONE]), PackedVector3Array([Vector3.ONE]), PackedColorArray([Color.RED]), PackedVector4Array([Vector4.ONE]), typed_array, typed_dictionary]
	for value in values:
		var encoded := Codec.encode({"value":value})
		check(encoded.ok, "Encoding failed: " + type_string(typeof(value)))
		if not encoded.ok: continue
		var decoded := Codec.decode(encoded.bytes)
		check(decoded.ok and var_to_bytes(decoded.data.value) == var_to_bytes(value), "Value/type changed: " + type_string(typeof(value)))
	var cyclic: Array = []
	cyclic.append(cyclic)
	check(not Codec.encode({"cycle":cyclic}).ok, "Cyclic data accepted")
	cyclic.clear()
	var large := PackedByteArray()
	large.resize(100001)
	check(not Codec.encode({"large":large}).ok, "Entry budget ignored")
	var object := RefCounted.new()
	check(not Codec.encode({"object":object}).ok, "Object serialized")
	check(not Codec.encode({"callable":Callable(self, "codec_roundtrip")}).ok, "Callable serialized")
	var refs: Array[Node] = []
	check(not Codec.encode({"refs":refs}).ok, "Object container serialized")

func migrate_v1(data: Dictionary) -> Dictionary:
	data["coins"] = data.get("score", 0)
	data.erase("score")
	return data

func migrate_v2(data: Dictionary) -> Dictionary:
	data["inventory"] = ["starter"]
	return data

func invalid_migration(_data: Dictionary) -> String:
	return "wrong type"

func file_roundtrip() -> void:
	var path := fixture_dir.path_join("state.gdbsave")
	check(not Saves.save_game("res://do_not_write.gdbsave", {}).ok and not Saves.valid_path("user://../escape"), "Invalid save path accepted")
	check(Saves.save_game(path, {"score":12}, 1).ok, "Initial disk save")
	var before := FileAccess.get_sha256(path)
	var migrated := Saves.load_game(path, 2, {1:Callable(self, "migrate_v1")})
	check(migrated.ok and migrated.data == {"coins":12} and migrated.version == 2, "Migration chain")
	check(FileAccess.get_sha256(path) == before, "Load/migration rewrote disk")
	var multi := Saves.load_game(path, 3, {1:Callable(self, "migrate_v1"), 2:Callable(self, "migrate_v2")})
	check(multi.ok and multi.data.coins == 12 and multi.data.inventory == ["starter"], "Multi-step schema migration")
	check(not Saves.load_game(path, 2, {1:Callable(self, "invalid_migration")}).ok, "Invalid migration return accepted")
	check(not Saves.save_game(path + "/child.gdbsave", {}).ok and FileAccess.get_sha256(path) == before, "Directory I/O failure damaged existing save")
	check(not Saves.load_game(path, 2).ok, "Missing migration accepted")
	check(not Saves.save_game(path, {"bad":RefCounted.new()}, 1).ok and FileAccess.get_sha256(path) == before, "Rejected save changed previous file")
	check(Saves.save_game(path, {"score":20}, 1).ok, "Replacement save")
	check(Saves.load_game(path).data.score == 20, "Primary replacement did not load")
	FileAccess.open(path, FileAccess.WRITE).store_string("corrupt")
	var recovered := Saves.load_game(path)
	check(recovered.ok and recovered.recovered and recovered.data.score == 12, "Previous-good backup recovery")
	check(not Saves.load_game(path, 1, {}, false).ok, "Disabled recovery used backup")
	check(Saves.save_game(path, {"score":30}, 3).ok, "Save after recovery")
	check(not Saves.load_game(path, 2).ok, "Future save silently downgraded through backup")
	check(Saves.load_game(path, 3).data.score == 30, "New-version save not readable")
	check(not Saves.save_game(path, {"score":0}, 1).ok and Saves.load_game(path, 3).data.score == 30, "Old game overwrote a newer save schema")
	check(not Saves.load_game(fixture_dir.path_join("missing.gdbsave")).ok, "Missing save accepted")
	var truncated := fixture_dir.path_join("truncated.gdbsave")
	FileAccess.open(truncated, FileAccess.WRITE).store_string("GDBSAVE1\nwrong\n")
	check(not Saves.load_game(truncated).ok, "Truncated file accepted")

func state_preflight() -> void:
	var state := State.new()
	var captured := Saves.capture_state(state, PackedStringArray(["health", "items", "stats", "transform_value"]))
	check(captured.ok and captured.data.health == 10, "Capture explicit properties")
	captured.data.items.append(99)
	check(state.items == [1, 2], "Capture aliases original container")
	check(not Saves.restore_state(state, {"health":2, "items":["bad"]}).ok and state.health == 10, "Invalid late field partially restored earlier field")
	check(not Saves.restore_state(state, {"health":2, "missing":4}).ok and state.health == 10, "Unknown field partially applied")
	check(Saves.restore_state(state, {"health":4, "items":[3, 4], "stats":{"coins":2}}).ok, "Valid typed restore rejected")
	check(state.health == 4 and state.items == [3, 4] and state.stats == {"coins":2}, "Typed state restoration")
	check(not Saves.capture_state(state, PackedStringArray(["missing"])).ok, "Unknown capture property accepted")
	state.free()
	check(not Saves.restore_state(state, {}).ok, "Freed restore target accepted")

func generated_save_load() -> void:
	var f := Fixture.new()
	add(f, "save_event", "CustomEventSensor", {"event_name":"save_checkpoint"})
	add(f, "capture", "CaptureState", {"names":'PackedStringArray(["health"])'})
	add(f, "save", "SaveGameData", {"path":fixture_dir.path_join("graph.gdbsave"), "data_expression":'_flow.values["capture"]["data"]'})
	add(f, "saved", "CallGraphFunction", signature("record", "value: Variant", "void"))
	f.graph_edit.get_node("saved").get_meta("brick_data").brick_instance.properties.argument_value = '_flow.values["save"]["ok"]'
	wire(f, "save_event", "capture")
	wire(f, "capture", "save")
	wire(f, "save", "saved")
	add(f, "load_event", "CustomEventSensor", {"event_name":"load_checkpoint"})
	add(f, "load", "LoadGameData", {"path":fixture_dir.path_join("graph.gdbsave")})
	add(f, "restore", "RestoreState", {"data_expression":'_flow.values["load"]["data"]'})
	wire(f, "load_event", "load")
	wire(f, "load", "restore")
	var owner := compile(f, "var health: int = 7\n")
	if owner != null:
		owner.call("save_checkpoint")
		check(owner.hits == [true], "Generated Save result pin")
		owner.health = 1
		owner.call("load_checkpoint")
		check(owner.health == 7, "Generated Capture/Save/Load/Restore roundtrip")
		owner.free()
	f.dispose()

func template_roundtrip() -> void:
	var owner := Node3D.new()
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = owner
	var value: GraphNode = panel._create_graph_node("value", "GetActorTransformValue", Vector2.ZERO)
	var move: GraphNode = panel._create_graph_node("actuator", "MoveCharacter3D", Vector2(400, 0))
	panel.graph_edit.connect_node(value.name, 2, move.name, 2)
	panel._save_graph_to_metadata("Fixture", false)
	var selection: Dictionary = panel._capture_selection([value, move])
	check(selection.nodes.size() == 2 and selection.connections.size() == 1, "Selection omitted pure value node")
	var path := fixture_dir.path_join("reusable.gdbtemplate")
	var payload := {"graph":selection, "variables":[], "frames":[]}
	check(Templates.save_template(path, payload).ok, "Template save")
	var loaded := Templates.load_template(path)
	check(loaded.ok and loaded.data.graph.nodes == selection.nodes, "Template typed metadata roundtrip")
	await panel._paste_selection(loaded.data.graph)
	var count := 0
	for node in panel.graph_edit.get_children():
		if node is GraphNode and node.selected: count += 1
	check(count == 2 and panel.graph_edit.get_connection_list().size() == 2, "Template paste lost value nodes or connections")
	var call: GraphNode = panel._create_graph_node_from_data({"id":"call", "position":Vector2.ZERO, "brick_type":"actuator", "brick_class":"CallGraphFunction", "properties":signature("velocity", "", "Vector3")})
	panel.graph_edit.connect_node(call.name, 2, move.name, 2)
	var captured_call: Dictionary = panel._capture_selection([call, move])
	await panel._paste_selection(captured_call)
	var new_call_id := ""
	var new_move: GraphNode
	for node in panel.graph_edit.get_children():
		if node is GraphNode and node.selected and node.has_meta("brick_data"):
			if node.get_meta("brick_data").brick_class == "CallGraphFunction": new_call_id = str(node.name)
			else: new_move = node
	check(new_move != null and new_move.get_meta("brick_data").brick_instance.properties.velocity_expression.contains(new_call_id), "Paste retained old per-activation result ID")
	var malformed: Dictionary = payload.duplicate(true)
	malformed.graph.nodes.append(malformed.graph.nodes[0].duplicate(true))
	check(not Templates.validate(malformed).is_empty(), "Duplicate template IDs accepted")
	malformed = payload.duplicate(true)
	malformed.graph.execution_version = 99
	check(not Templates.validate(malformed).is_empty(), "Future execution format accepted")
	var legacy := fixture_dir.path_join("legacy.lbtemplate")
	FileAccess.open(legacy, FileAccess.WRITE).store_string(JSON.stringify({"format":"blueprints_for_godot_template", "version":1, "payload":var_to_str(payload)}))
	check(Templates.load_template(legacy).ok, "Legacy data-only template migration")
	await panel._clipboard_helper.load_template_from_file(path)
	check(panel.current_node.get_meta("blueprints_for_godot_graph").nodes.size() >= 8, "Template menu import did not append nodes")
	var legacy_object := fixture_dir.path_join("object.lbtemplate")
	FileAccess.open(legacy_object, FileAccess.WRITE).store_string(JSON.stringify({"format":"blueprints_for_godot_template", "version":1, "payload":'Object(Node,"name":"No")'}))
	check(not Templates.load_template(legacy_object).ok, "Legacy object constructor accepted")
	panel.free()
	owner.free()

func large_graph() -> void:
	var f := Fixture.new()
	var start := Time.get_ticks_msec()
	for event_index in 20:
		var event_id := "entry_" + str(event_index)
		add(f, event_id, "CustomEventSensor", {"event_name":event_id})
		var previous := event_id
		for index in 50:
			var id := "action_%d_%d" % [event_index, index]
			add(f, id, "CallObjectMethodActuator", {"method_name":"record", "arguments":"[%d]" % index})
			wire(f, previous, id)
			previous = id
	# Fixture's compile helper requires a version-4 graph; a disconnected function
	# entry exercises function metadata alongside the 1,000 executable actions.
	add(f, "function", "FunctionEntry", signature("noop", "", "void"))
	var owner := compile(f)
	var elapsed := Time.get_ticks_msec() - start
	if owner != null:
		for event_index in 20: owner.call("entry_" + str(event_index))
		check(owner.hits.size() == 1000, "Large graph lost runtime actions")
		for index in owner.hits.size(): check(owner.hits[index] == index % 50, "Large graph ordering changed")
		owner.free()
	f.dispose()
	print("Large graph: 1,021 nodes, 1,000 actions; build/compile fixture ms: ", elapsed)
