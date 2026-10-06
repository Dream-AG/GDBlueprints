extends RefCounted

const MAX_DEPTH := 3
const MAX_ITEMS := 24
const MAX_TEXT := 1024

static func capture(owner: Node, flow: Dictionary, node_id: String, entry: String) -> Dictionary:
	var scene := owner.get_tree().current_scene if owner.get_tree() else null
	var watched: Dictionary = {}
	var property_names: Dictionary = {}
	for property in owner.get_property_list(): property_names[str(property.get("name", ""))] = true
	for item in owner.get_meta("blueprints_for_godot_variables", []):
		if watched.size() >= MAX_ITEMS: break
		if item is Dictionary and bool(item.get("debug_watch", false)):
			var name := str(item.get("name", ""))
			if not name.is_empty(): watched[name] = _safe(owner.get(name), 0) if property_names.has(name) else "<not found>"
	return {
		"scene": str(scene.scene_file_path) if scene else "",
		"owner_path": str(scene.get_path_to(owner)) if scene else str(owner.get_path()),
		"owner_name": str(owner.name),
		"node_id": node_id,
		"entry": entry,
		"depth": int(flow.get("meter", {}).get("depth", 0)),
		"step": int(flow.get("meter", {}).get("steps", 0)),
		"event_arguments": _safe(flow.get("event_arguments", {}), 0),
		"function_name": str(flow.get("function_name", "")),
		"function_arguments": _safe(flow.get("function_arguments", {}), 0),
		"function_locals": _safe(flow.get("function_locals", {}), 0),
		"values": _safe(flow.get("values", {}), 0),
		"loops": _safe(flow.get("loops", []), 0),
		"watched": watched
	}

static func _safe(value: Variant, depth: int) -> Variant:
	if depth >= MAX_DEPTH: return "<max depth>"
	if typeof(value) == TYPE_OBJECT:
		return "<freed>" if not is_instance_valid(value) else "%s:%s" % [value.get_class(), str(value.get_path()) if value is Node and value.is_inside_tree() else str(value.get_instance_id())]
	if value is String or value is StringName: return str(value).left(MAX_TEXT)
	if value is Callable or value is Signal or value is RID: return "<%s>" % type_string(typeof(value))
	if value is Array or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		var result: Array = []
		for index in mini(value.size(), MAX_ITEMS): result.append(_safe(value[index], depth + 1))
		if value.size() > MAX_ITEMS: result.append("<%d more>" % (value.size() - MAX_ITEMS))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		var count := 0
		for key in value:
			if count >= MAX_ITEMS:
				result["<more>"] = value.size() - MAX_ITEMS
				break
			result[str(_safe(key, depth + 1)).left(MAX_TEXT)] = _safe(value[key], depth + 1)
			count += 1
		return result
	return value
