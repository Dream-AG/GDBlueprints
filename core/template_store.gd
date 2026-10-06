@tool
extends RefCounted
const Codec = preload("res://addons/GDBlueprints/core/data_codec.gd")
const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Schema = preload("res://addons/GDBlueprints/core/graph_schema.gd")

static func validate(payload: Dictionary) -> String:
	var issue := Codec.validate(payload)
	if not issue.is_empty(): return issue
	var graph = payload.get("graph")
	if not graph is Dictionary or not graph.get("nodes") is Array or not graph.get("connections") is Array: return "Template graph must contain node and connection arrays."
	if int(graph.get("schema_version", 1)) not in [1, 2] or int(graph.get("execution_version", 2)) not in [1, 2, 3, 4]: return "Unsupported graph version."
	if graph.nodes.size() > 10000 or graph.connections.size() > 50000: return "Template exceeds graph size limits."
	var ids := {}
	for node in graph.nodes:
		if not node is Dictionary or not node.get("id") is String and not node.get("id") is StringName: return "Invalid template node ID."
		var id := str(node.id)
		if id.is_empty() or id in [".", ".."] or id.validate_node_name() != id or ids.has(id): return "Duplicate or invalid template node ID."
		ids[id] = true
		if not node.get("position") is Vector2: return "Invalid node position."
		if not node.position.is_finite(): return "Non-finite node position."
		if bool(node.get("is_value_node", false)):
			if not node.get("value_node") is Dictionary: return "Invalid value-node record."
		elif not bool(node.get("is_reroute", false)):
			if Registry.get_script_path(str(node.get("brick_class", ""))).is_empty(): return "Missing node definition: " + str(node.get("brick_class", ""))
			if node.get("brick_type") != Registry.get_brick_info(str(node.brick_class)).type: return "Incorrect node kind."
			if not node.get("properties", {}) is Dictionary: return "Invalid node properties."
	for edge in graph.connections:
		if not edge is Dictionary: return "Invalid connection record."
		if not ids.has(str(edge.get("from_node", ""))) or not ids.has(str(edge.get("to_node", ""))): return "Connection references a missing node."
		for key in ["from_port", "to_port"]:
			if not edge.get(key) is int or int(edge[key]) < 0 or int(edge[key]) > 1024: return "Invalid connection port."
	for key in ["variables", "frames"]:
		if not payload.get(key, []) is Array: return "Invalid " + key + " collection."
		for item in payload.get(key, []):
			if not item is Dictionary: return "Invalid " + key + " record."
	for variable in payload.get("variables", []):
		if not variable.get("name") is String or not str(variable.name).is_valid_identifier() or not variable.get("type") is String: return "Invalid variable definition."
	for frame in payload.get("frames", []):
		if not frame.get("nodes", []) is Array or not frame.get("position", Vector2.ZERO) is Vector2 or not frame.get("size", Vector2.ZERO) is Vector2: return "Invalid frame layout."
	return ""

static func save_template(path: String, payload: Dictionary) -> Dictionary:
	var issue := validate(payload)
	if not issue.is_empty(): return Codec.error(issue)
	var encoded := Codec.encode(payload)
	if not encoded.ok: return encoded
	var envelope := {"format":"gdblueprints_template", "version":2, "checksum":Codec.checksum(encoded.bytes), "payload":Marshalls.raw_to_base64(encoded.bytes)}
	var temporary := path + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return Codec.error("Cannot create template: " + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK: result = DirAccess.rename_absolute(temporary, path)
	if result != OK:
		DirAccess.remove_absolute(temporary)
		return Codec.error("Cannot save template: " + error_string(result))
	return {"ok":true, "error":""}

static func load_template(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return Codec.error("Cannot read template.")
	if file.get_length() > Codec.MAX_BYTES * 2: return Codec.error("Template is too large.")
	var envelope = JSON.parse_string(file.get_as_text())
	if not envelope is Dictionary: return Codec.error("Invalid template envelope.")
	var payload: Variant
	if envelope.get("format") == "gdblueprints_template" and envelope.get("version") == 2:
		if not envelope.get("payload") is String: return Codec.error("Invalid template payload.")
		var bytes := Marshalls.base64_to_raw(envelope.payload)
		if Codec.checksum(bytes) != envelope.get("checksum"): return Codec.error("Template checksum mismatch.")
		var decoded := Codec.decode(bytes)
		if not decoded.ok: return decoded
		payload = decoded.data
	elif envelope.get("format") == "blueprints_for_godot_template" and envelope.get("version") == 1:
		var text := str(envelope.get("payload", ""))
		# Old templates use Variant text. Reject resource/object constructors before
		# parsing; quoted user strings are ignored by this token scan.
		var tokens := ""
		var quoted := false
		var escaped := false
		for character in text:
			if quoted:
				if escaped: escaped = false
				elif character == "\\": escaped = true
				elif character == '"': quoted = false
			elif character == '"': quoted = true
			else: tokens += character
		var forbidden := RegEx.new()
		forbidden.compile("\\b(Object|Resource|SubResource|ExtResource)\\s*\\(")
		if forbidden.search(tokens): return Codec.error("Legacy template contains live object/resource data; export a data-only template from its original project.")
		payload = str_to_var(text)
	else: return Codec.error("Unknown or newer template format.")
	if not payload is Dictionary: return Codec.error("Invalid template payload.")
	var issue := validate(payload)
	if not issue.is_empty(): return Codec.error(issue)
	payload.graph = Schema.migrate(payload.graph)
	return {"ok":true, "error":"", "data":payload}
