@tool
extends RefCounted
class_name BlueprintVariableUtils

const SUPPORTED_TYPES = ["bool", "int", "float", "String", "Vector2", "Vector3", "Vector4", "Color", "Transform2D", "Transform3D", "Node", "Object", "Array", "Variant"]
const Collections = preload("res://addons/GDBlueprints/core/collection_types.gd")
const PinTypes = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")
const EXTRA_TYPES = ["StringName", "NodePath", "Dictionary", "Resource", "PackedScene", "Basis", "Quaternion", "Callable", "Signal",
	"Vector2i", "Vector3i", "Vector4i", "Rect2", "Rect2i", "AABB",
	"PackedByteArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array",
	"PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedVector4Array", "PackedColorArray"]
const DEFAULT_LOCAL_NAME = "new_variable"
const DEFAULT_GLOBAL_NAME = "new_global"

static func create_default_local_variable() -> Dictionary:
	return {
		"name": DEFAULT_LOCAL_NAME,
		"type": "int",
		"value": "0",
		"exported": false,
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100"
	}


static func create_default_global_variable(global_id: String = "") -> Dictionary:
	var var_data := {
		"name": DEFAULT_GLOBAL_NAME,
		"type": "int",
		"value": "0",
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100"
	}
	if not global_id.is_empty():
		var var_id := str(global_id)
		if not var_id.is_empty():
			var_data["id"] = var_id
	return var_data


static func get_supported_types() -> Array:
	return SUPPORTED_TYPES + EXTRA_TYPES


static func is_supported_type(type_name: String) -> bool:
	return type_name in get_supported_types() or is_reference_type(type_name) or not Collections.parse(type_name).is_empty()


static func is_reference_type(type_name: String) -> bool:
	return ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name, "Object")


static func normalize_type(type_name: String, fallback: String = "int") -> String:
	if is_supported_type(type_name):
		return type_name
	return fallback


static func get_type_index(type_name: String) -> int:
	var normalized := normalize_type(type_name)
	return get_supported_types().find(normalized)


static func export_annotation(type_name: String) -> String:
	var spec := Collections.parse(type_name)
	if spec.get("kind") == "Enum":
		var labels: Array[String] = []
		for label in spec.cases: labels.append(var_to_str("%s:%s" % [label, spec.cases[label]]))
		return "@export_enum(" + ", ".join(labels) + ") "
	return "@export "

static func can_export(type_name: String) -> bool:
	var spec := Collections.parse(type_name)
	if not spec.is_empty() and spec.kind != "Enum":
		for arg in spec.args:
			if not can_export(PinTypes.variable_type(arg)): return false
		return true
	if is_reference_type(type_name):
		return ClassDB.is_parent_class(type_name, "Node") or ClassDB.is_parent_class(type_name, "Resource")
	return is_supported_type(type_name) and type_name not in ["Object", "Variant", "Callable", "Signal"]


static func is_numeric_type(type_name: String) -> bool:
	var normalized := normalize_type(type_name)
	return normalized == "int" or normalized == "float"


## Map a Godot Variant type integer (TYPE_*) to the GDScript type name string used
## by this addon (one of "bool", "int", "float", "String").
## Returns an empty string for types that are not in SUPPORTED_TYPES (e.g. Object, Array).
static func gdscript_type_name_from_variant_type(type_int: int) -> String:
	var mapped := PinTypes.variable_type(PinTypes.type_from_variant_type(type_int))
	if mapped != "Variant" and is_supported_type(mapped):
		return mapped
	match type_int:
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR4:
			return "Vector4"
		TYPE_COLOR:
			return "Color"
		TYPE_TRANSFORM2D:
			return "Transform2D"
		TYPE_TRANSFORM3D:
			return "Transform3D"
		TYPE_OBJECT:
			return "Object"
		TYPE_ARRAY:
			return "Array"
		_:
			return ""


static func get_default_value_for_variable_type(var_type: String):
	var spec := Collections.parse(var_type)
	if not spec.is_empty():
		if spec.kind == "Enum": return str(spec.cases.values()[0])
		return [] if spec.kind == "Array" else {}
	if is_reference_type(var_type):
		return null
	if var_type == "Dictionary":
		return {}
	if var_type in EXTRA_TYPES:
		return var_type + "()"
	match normalize_type(var_type):
		"bool":
			return "false"
		"int":
			return "0"
		"float":
			return "0.0"
		"String":
			return ""
		"Vector2":
			return "Vector2.ZERO"
		"Vector3":
			return "Vector3.ZERO"
		"Vector4":
			return "Vector4.ZERO"
		"Color":
			return "Color.WHITE"
		"Transform2D":
			return "Transform2D.IDENTITY"
		"Transform3D":
			return "Transform3D.IDENTITY"
		"Node", "Object", "Variant":
			return null
		"Array":
			return []
		_:
			return "0"


static func coerce_variable_value_for_type(value, var_type: String):
	var normalized_type := normalize_type(var_type)
	var text_value := str(value)
	if not Collections.parse(normalized_type).is_empty():
		return value if not value is String else _parse_stored_value(value)
	if is_reference_type(normalized_type):
		return null
	if normalized_type == "Dictionary":
		if value is Dictionary:
			return value.duplicate(true)
		var parsed: Variant = _parse_stored_value(text_value)
		return parsed if parsed is Dictionary else {}
	if normalized_type in ["Callable", "Signal"]:
		return normalized_type + "()"
	if normalized_type in EXTRA_TYPES:
		var parsed: Variant = _parse_stored_value(text_value) if value is String else value
		if PinTypes.type_from_variant_type(typeof(parsed)) == normalized_type:
			return var_to_str(parsed)
		return normalized_type + "()"
	match normalized_type:
		"bool":
			var lowered := text_value.strip_edges().to_lower()
			if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on":
				return "true"
			return "false"
		"int":
			if value is int:
				return str(value)
			if value is bool:
				if value:
					return "1"
				return "0"
			if text_value.is_valid_int():
				return text_value
			if text_value.is_valid_float():
				return str(int(text_value.to_float()))
			return "0"
		"float":
			if value is float:
				return str(value)
			if value is int:
				return str(float(value))
			if value is bool:
				if value:
					return "1.0"
				return "0.0"
			if text_value.is_valid_float():
				return text_value
			if text_value.is_valid_int():
				return str(float(text_value.to_int()))
			return "0.0"
		"String":
			return text_value
		"Vector2":
			var text := text_value.strip_edges()
			if text.begins_with("Vector2(") and text.ends_with(")"):
				return text
			var parts := text.split(",", false)
			if parts.size() == 2 and str(parts[0]).strip_edges().is_valid_float() and str(parts[1]).strip_edges().is_valid_float():
				return "Vector2(%s, %s)" % [str(parts[0]).strip_edges(), str(parts[1]).strip_edges()]
			return "Vector2.ZERO"
		"Vector3":
			var text := text_value.strip_edges()
			if text.begins_with("Vector3(") and text.ends_with(")"):
				return text
			var parts := text.split(",", false)
			if parts.size() == 3 and str(parts[0]).strip_edges().is_valid_float() and str(parts[1]).strip_edges().is_valid_float() and str(parts[2]).strip_edges().is_valid_float():
				return "Vector3(%s, %s, %s)" % [str(parts[0]).strip_edges(), str(parts[1]).strip_edges(), str(parts[2]).strip_edges()]
			return "Vector3.ZERO"
		"Vector4":
			var text := text_value.strip_edges()
			if text.begins_with("Vector4(") and text.ends_with(")"):
				return text
			return "Vector4.ZERO"
		"Color":
			var text := text_value.strip_edges()
			if text.begins_with("Color(") or text.begins_with("Color."):
				return text
			return "Color.WHITE"
		"Transform2D":
			var text := text_value.strip_edges()
			if text.begins_with("Transform2D(") or text.begins_with("Transform2D."):
				return text
			return "Transform2D.IDENTITY"
		"Transform3D":
			var text := text_value.strip_edges()
			if text.begins_with("Transform3D(") or text.begins_with("Transform3D."):
				return text
			return "Transform3D.IDENTITY"
		"Node", "Object", "Variant":
			return null
		"Array":
			if value is Array:
				return value.duplicate(true)
			return _parse_array_literal(text_value)
		_:
			return text_value


static func value_to_line_edit_text(value) -> String:
	return str(value)


static func to_gdscript_value_literal(value, var_type: String) -> String:
	var normalized_type := normalize_type(var_type)
	var coerced_value: Variant = coerce_variable_value_for_type(value, normalized_type)
	if not Collections.parse(normalized_type).is_empty():
		# Invalid defaults deliberately fail generation; never silently discard data.
		if not Collections.accepts(coerced_value, normalized_type): return "GDBLUEPRINTS_INVALID_COLLECTION_DEFAULT"
		return Collections.constructor(normalized_type, _native_value_literal(coerced_value))
	if is_reference_type(normalized_type):
		return "null"
	if normalized_type == "Dictionary":
		return _native_value_literal(coerced_value)
	if normalized_type.begins_with("Packed"):
		return 'str_to_var("%s")' % str(coerced_value).c_escape()
	if normalized_type in ["StringName", "NodePath"]:
		return "%s(%s)" % [normalized_type, var_to_str(str(_parse_stored_value(str(coerced_value))))] if not str(coerced_value).ends_with("()") else str(coerced_value)
	if normalized_type in EXTRA_TYPES:
		return str(coerced_value)
	match normalized_type:
		"String":
			return '"%s"' % coerced_value.c_escape()
		"bool":
			return coerced_value
		"int":
			return coerced_value
		"float":
			return coerced_value
		"Vector2", "Vector3", "Vector4", "Color", "Transform2D", "Transform3D":
			return coerced_value
		"Node", "Object", "Variant":
			return "null"
		"Array":
			return _array_to_gdscript_literal(coerced_value)
		_:
			return coerced_value


static func parse_gdscript_value_literal(value_literal: String, var_type: String):
	var normalized_type := normalize_type(var_type)
	var text := str(value_literal).strip_edges()
	if is_reference_type(normalized_type):
		return null
	if normalized_type in EXTRA_TYPES:
		return coerce_variable_value_for_type(text, normalized_type)
	match normalized_type:
		"String":
			if text.length() >= 2 and text.begins_with('"') and text.ends_with('"'):
				text = str_to_var(text)
			return text
		"bool":
			return coerce_variable_value_for_type(text, normalized_type)
		"int":
			return coerce_variable_value_for_type(text, normalized_type)
		"float":
			return coerce_variable_value_for_type(text, normalized_type)
		"Vector2", "Vector3", "Vector4", "Color", "Transform2D", "Transform3D":
			return coerce_variable_value_for_type(text, normalized_type)
		"Node", "Object", "Variant":
			return null
		"Array":
			return _parse_array_literal(text)
		_:
			return text


static func _array_item_to_literal(item) -> String:
	if item is Dictionary and item.has("type"):
		return to_gdscript_value_literal(item.get("value", ""), str(item.get("type", "String")))
	match typeof(item):
		TYPE_BOOL: return "true" if item else "false"
		TYPE_INT, TYPE_FLOAT: return str(item)
		TYPE_STRING: return '"%s"' % str(item).c_escape()
		TYPE_ARRAY: return _array_to_gdscript_literal(item)
		_: return _native_value_literal(item)


static func _native_value_literal(value) -> String:
	if value is Dictionary or value is Array or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return 'str_to_var("%s")' % var_to_str(value).c_escape()
	if value is String:
		return '"%s"' % value.c_escape()
	return var_to_str(value)


static func _parse_stored_value(text: String):
	var source := text.strip_edges()
	# Decode only our literal wrapper; never execute arbitrary expressions.
	if source.begins_with("str_to_var(") and source.ends_with(")"):
		var encoded: Variant = str_to_var(source.substr(11, source.length() - 12))
		return str_to_var(encoded) if encoded is String else null
	return str_to_var(source)

static func _array_to_gdscript_literal(value) -> String:
	if not (value is Array):
		return "[]"
	var parts: Array[String] = []
	for item in value:
		parts.append(_array_item_to_literal(item))
	return "[%s]" % ", ".join(parts)

static func _parse_array_literal(text: String) -> Array:
	# Disk fallback parser. Metadata is the authoritative source for typed array items.
	# Preserve common scalar literals when globals are reconstructed from global_vars.gd.
	var result: Array = []
	var body := text.strip_edges()
	if not body.begins_with("[") or not body.ends_with("]"):
		return result
	body = body.substr(1, body.length() - 2).strip_edges()
	if body.is_empty():
		return result
	var current := ""
	var depth := 0
	var quoted := false
	var escaped := false
	for ch in body:
		if escaped:
			current += ch
			escaped = false
			continue
		if ch == "\\" and quoted:
			current += ch
			escaped = true
			continue
		if ch == '"':
			quoted = not quoted
			current += ch
			continue
		if not quoted:
			if ch in ["(", "[", "{"]:
				depth += 1
			elif ch in [")", "]", "}"]:
				depth -= 1
			elif ch == "," and depth == 0:
				result.append(_literal_to_typed_item(current.strip_edges()))
				current = ""
				continue
		current += ch
	if not current.strip_edges().is_empty():
		result.append(_literal_to_typed_item(current.strip_edges()))
	return result

static func _literal_to_typed_item(text: String) -> Dictionary:
	if text.begins_with("str_to_var("):
		var value: Variant = _parse_stored_value(text)
		return {"type":gdscript_type_name_from_variant_type(typeof(value)), "value":value}
	if text.begins_with("["):
		return {"type":"Array", "value":_parse_array_literal(text)}
	for type_name in EXTRA_TYPES:
		if text.begins_with(type_name + "(") or (type_name == "Dictionary" and text.begins_with("{")):
			return {"type":type_name, "value":coerce_variable_value_for_type(text, type_name)}
	if text == "null":
		return {"type":"Variant", "value":null}
	for type_name in ["Vector4", "Color", "Transform2D", "Transform3D"]:
		if text.begins_with(type_name + "("):
			return {"type":type_name, "value":text}
	if text.to_lower() in ["true", "false"]:
		return {"type":"bool", "value":text.to_lower()}
	if text.is_valid_int():
		return {"type":"int", "value":text}
	if text.is_valid_float():
		return {"type":"float", "value":text}
	if text.begins_with("Vector2("):
		return {"type":"Vector2", "value":text}
	if text.begins_with("Vector3("):
		return {"type":"Vector3", "value":text}
	if text.length() >= 2 and text.begins_with('"') and text.ends_with('"'):
		return {"type":"String", "value":parse_gdscript_value_literal(text, "String")}
	return {"type":"String", "value":text}


## Recover owned global declarations without constructing or executing a user script.
static func read_global_declarations(source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var inside := false
	var recorded := false
	for raw in source.split("\n"):
		var line := raw.strip_edges()
		if line in ["# === GDBLUEPRINTS GLOBALS START ===", "# === LOGIC BRICKS GLOBALS START ==="]:
			inside = true
			continue
		if line in ["# === GDBLUEPRINTS GLOBALS END ===", "# === LOGIC BRICKS GLOBALS END ==="]: break
		if not inside: continue
		if line.begins_with("# GDBlueprints variable: "):
			var encoded: Variant = str_to_var(line.trim_prefix("# GDBlueprints variable: "))
			var record: Variant = str_to_var(encoded) if encoded is String else null
			if record is Dictionary and record.has("name") and record.has("type"):
				result.append(record)
				recorded = true
			continue
		if not line.begins_with("var "): continue
		if recorded:
			recorded = false
			continue
		var colon := line.find(":")
		var equals := line.find("=")
		if colon < 0 or equals < colon: continue
		var name := line.substr(4, colon - 4).strip_edges()
		var type_name := line.substr(colon + 1, equals - colon - 1).strip_edges()
		if not is_supported_type(type_name): continue
		result.append({"name":name, "type":type_name, "value":parse_gdscript_value_literal(line.substr(equals + 1), type_name)})
	return result
