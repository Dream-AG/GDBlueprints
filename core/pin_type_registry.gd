@tool
extends RefCounted

## Central source of truth for GDBlueprints data-pin types.
##
## Node authors should use the public names returned by normalize():
## Bool, Int, Float, String, Vector2, Vector3, Vector4, Color,
## Transform2D, Transform3D, Node, Object, Array, Dictionary, Resource,
## PackedScene, Callable, Signal and Variant.
##
## Keeping colors, compatibility, struct splitting and conversion guidance here
## prevents the editor UI and compiler from growing separate type systems.

const Collections = preload("res://addons/GDBlueprints/core/collection_types.gd")
const DEFAULT_PIN_COLOR := Color("8bd5ff")
const VALUE_TYPES := {
	TYPE_VECTOR2I: "Vector2i", TYPE_VECTOR3I: "Vector3i", TYPE_VECTOR4I: "Vector4i",
	TYPE_RECT2: "Rect2", TYPE_RECT2I: "Rect2i", TYPE_AABB: "AABB",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray", TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array", TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array", TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array", TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_VECTOR4_ARRAY: "PackedVector4Array", TYPE_PACKED_COLOR_ARRAY: "PackedColorArray"
}

static func normalize(type_name: String) -> String:
	var raw := type_name.strip_edges()
	var spec := Collections.parse(raw)
	if not spec.is_empty():
		if spec.kind == "Enum": return "Enum[" + ", ".join(spec.args) + "]"
		var args: Array[String] = []
		for arg in spec.args: args.append(normalize(arg))
		return str(spec.kind) + "[" + ", ".join(args) + "]"
	var lower := raw.to_lower()
	for value_type in VALUE_TYPES.values():
		if str(value_type).to_lower() == lower:
			return value_type
	match lower:
		"boolean": return "Bool"
		"integer": return "Int"
		"double": return "Float"
		"stringname": return "StringName"
		"nodepath": return "NodePath"
		"bool": return "Bool"
		"int": return "Int"
		"float": return "Float"
		"string": return "String"
		"vector2": return "Vector2"
		"vector3": return "Vector3"
		"vector4": return "Vector4"
		"color": return "Color"
		"transform2d": return "Transform2D"
		"transform3d": return "Transform3D"
		"basis": return "Basis"
		"quaternion": return "Quaternion"
		"node": return "Node"
		"node2d": return "Node2D"
		"node3d": return "Node3D"
		"control": return "Control"
		"object": return "Object"
		"array": return "Array"
		"dictionary": return "Dictionary"
		"resource": return "Resource"
		"packedscene", "packed_scene": return "PackedScene"
		"callable": return "Callable"
		"signal": return "Signal"
		"variant", "": return "Variant"
		_: return raw


static func color(type_name: String) -> Color:
	var normalized := normalize(type_name)
	if not Collections.parse(normalized).is_empty(): return Color("78d6d0")
	if normalized.begins_with("Packed") and normalized.ends_with("Array"):
		return Color("78d6d0")
	match normalized:
		"Bool": return Color("d65c5c")
		"Int": return Color("5ad1a6")
		"Float": return Color("8adba8")
		"String": return Color("e78ac3")
		"Vector2", "Vector3", "Vector4", "Vector2i", "Vector3i", "Vector4i": return Color("e7d77b")
		"Color": return Color("f2b36d")
		"Transform2D", "Transform3D", "Basis", "Quaternion": return Color("d49bea")
		"Node", "Node2D", "Node3D", "Control", "Object": return Color("78a9ff")
		"Array", "Dictionary": return Color("78d6d0")
		"Resource", "PackedScene": return Color("ba8cff")
		"Callable", "Signal": return Color("ff9b72")
	# Concrete built-in Node/Object classes (Button, Label, CharacterBody3D, etc.)
	# keep the reference color instead of falling back to an unrelated generic pin.
	if ClassDB.class_exists(normalized) and ClassDB.is_parent_class(normalized, "Object"):
		return Color("78a9ff")
	return DEFAULT_PIN_COLOR


static func type_from_variant_type(variant_type: int) -> String:
	if VALUE_TYPES.has(variant_type):
		return VALUE_TYPES[variant_type]
	match variant_type:
		TYPE_BOOL: return "Bool"
		TYPE_INT: return "Int"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR4: return "Vector4"
		TYPE_COLOR: return "Color"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_BASIS: return "Basis"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_OBJECT: return "Object"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		_: return "Variant"


static func compatible(source_type: String, target_type: String) -> bool:
	var source := normalize(source_type)
	var target := normalize(target_type)
	if source == target or source == "Variant" or target == "Variant":
		return true
	var source_spec := Collections.parse(source)
	var target_spec := Collections.parse(target)
	if not source_spec.is_empty() and target == source_spec.kind: return true
	if source_spec.get("kind") == "Enum" and target == "Int": return true
	if not source_spec.is_empty() or not target_spec.is_empty(): return false
	# Safe numeric widening.
	if source == "Int" and target == "Float":
		return true
	# All Nodes are Objects.
	if _is_node_type(source) and target == "Object":
		return true
	# Concrete Godot Object inheritance, e.g. Button -> Control -> Node -> Object.
	if ClassDB.class_exists(source) and ClassDB.class_exists(target):
		return ClassDB.is_parent_class(source, target)
	return false


static func conversion_suggestion(source_type: String, target_type: String) -> String:
	var source := normalize(source_type)
	var target := normalize(target_type)
	if source in ["Vector2", "Vector3", "Vector4"] and target == "Float":
		return "Split the vector struct and connect X/Y/Z/W (Float), or add an explicit vector conversion node."
	if source == "Color" and target == "Float":
		return "Split the Color struct and connect R/G/B/A (Float)."
	if source == "Float" and target == "Int":
		return "Insert an explicit Float → Int conversion (round, floor, or ceil) before this pin."
	if target == "String":
		return "Insert an explicit To String conversion before this pin."
	if source == "String" and target in ["Int", "Float", "Bool"]:
		return "Insert an explicit String → %s conversion before this pin." % target
	if _is_node_type(source) and _is_node_type(target):
		return "Use Cast To Script or a more specific typed reference before this pin."
	return "Insert an explicit %s → %s conversion node before this pin." % [source, target]


static func variable_type(type_name: String) -> String:
	var normalized := normalize(type_name)
	var spec := Collections.parse(normalized)
	if not spec.is_empty():
		if spec.kind == "Enum": return "int"
		var args: Array[String] = []
		for arg in spec.args: args.append(variable_type(arg))
		return str(spec.kind) + "[" + ", ".join(args) + "]"
	if normalized in VALUE_TYPES.values() or normalized in ["Basis", "Quaternion", "Callable", "Signal", "StringName", "NodePath"]:
		return normalized
	if ClassDB.class_exists(normalized) and ClassDB.is_parent_class(normalized, "Object"):
		return normalized
	match normalized:
		"Bool": return "bool"
		"Int": return "int"
		"Float": return "float"
		"String": return "String"
		"Vector2": return "Vector2"
		"Vector3": return "Vector3"
		"Vector4": return "Vector4"
		"Color": return "Color"
		"Transform2D": return "Transform2D"
		"Transform3D": return "Transform3D"
		"Array": return "Array"
		"Dictionary": return "Dictionary"
		"Variant": return "Variant"
		"Object": return "Object"
		"Resource": return "Resource"
		"PackedScene": return "PackedScene"
		_:
			if _is_node_type(normalized):
				return "Node"
	return ""


static func is_splittable(type_name: String) -> bool:
	return normalize(type_name) in ["Vector2", "Vector3", "Vector4", "Vector2i", "Vector3i", "Vector4i", "Color"]


static func split_outputs(type_name: String, expression: String) -> Array:
	var normalized := normalize(type_name)
	var components: Array[String] = []
	match normalized:
		"Vector2", "Vector2i": components = ["x", "y"]
		"Vector3", "Vector3i": components = ["x", "y", "z"]
		"Vector4", "Vector4i": components = ["x", "y", "z", "w"]
		"Color": components = ["r", "g", "b", "a"]
		_: return []
	var result: Array = []
	for component in components:
		result.append({
			"name": component.to_upper(),
			"type": "Int" if normalized.ends_with("i") else "Float",
			"expression": "(%s).%s" % [expression, component]
		})
	return result


static func display_help(type_name: String) -> String:
	var normalized := normalize(type_name)
	match normalized:
		"Bool": return "Boolean: checked/unchecked, true/false."
		"Int": return "Whole number."
		"Float": return "Decimal number."
		"String": return "Text."
		"Node", "Node2D", "Node3D", "Control": return "Live scene-tree node reference."
		"Object": return "Any Godot Object reference."
		"Array": return "Ordered collection of values."
		"Dictionary": return "Key/value collection."
		"Resource": return "Godot Resource reference."
		"PackedScene": return "Scene resource that can be instantiated."
		"Variant": return "Any Godot Variant value; use a more specific type when possible."
	if ClassDB.class_exists(normalized) and ClassDB.is_parent_class(normalized, "Node"):
		return "%s: live scene-tree node reference." % normalized
	if ClassDB.class_exists(normalized) and ClassDB.is_parent_class(normalized, "Object"):
		return "%s: Godot Object reference." % normalized
	return normalized


static func _is_node_type(type_name: String) -> bool:
	var normalized := normalize(type_name)
	if normalized in ["Node", "Node2D", "Node3D", "Control"]:
		return true
	return ClassDB.class_exists(normalized) and ClassDB.is_parent_class(normalized, "Node")
