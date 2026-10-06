@tool
extends RefCounted

## Native container declarations and explicit, stable integer enum cases.
## No expressions are evaluated while parsing a type or an initial value.
static func split_top(text: String) -> Array[String]:
	var parts: Array[String] = []
	var depth := 0
	var start := 0
	for i in text.length():
		if text[i] == "[": depth += 1
		elif text[i] == "]": depth -= 1
		elif text[i] == "," and depth == 0:
			parts.append(text.substr(start, i - start).strip_edges())
			start = i + 1
	parts.append(text.substr(start).strip_edges())
	return parts

static func parse(text: String) -> Dictionary:
	var open := text.find("[")
	if open < 0 or not text.ends_with("]"): return {}
	var kind := text.left(open).strip_edges()
	var args := split_top(text.substr(open + 1, text.length() - open - 2))
	if kind == "Enum":
		var cases: Dictionary = {}
		var values: Array[int] = []
		for arg in args:
			var pair := arg.split("=")
			if pair.size() != 2: return {}
			var label := pair[0].strip_edges()
			var value := pair[1].strip_edges()
			if not label.is_valid_identifier() or not value.is_valid_int() or cases.has(label) or int(value) in values: return {}
			cases[label] = int(value)
			values.append(int(value))
		return {"kind":kind, "cases":cases, "args":args} if not cases.is_empty() else {}
	if (kind == "Array" and args.size() == 1) or (kind == "Dictionary" and args.size() == 2):
		# GDScript does not support nested typed container declarations.
		for arg in args:
			if arg.contains("[") or builtin(arg) < 0: return {}
		return {"kind":kind, "args":args}
	return {}

static func builtin(name: String) -> int:
	if name == "RID": return -1
	if name == "Variant": return TYPE_NIL
	if ClassDB.class_exists(name): return TYPE_OBJECT
	for kind in range(1, TYPE_MAX):
		if type_string(kind).to_lower() == name.to_lower(): return kind
	return -1

static func accepts(value: Variant, name: String) -> bool:
	var spec := parse(name)
	if not spec.is_empty():
		if spec.kind == "Enum": return value is int and value in spec.cases.values()
		if spec.kind == "Array":
			if not value is Array: return false
			for item in value:
				if not accepts(item, spec.args[0]): return false
			return true
		if not value is Dictionary: return false
		for key in value:
			if not accepts(key, spec.args[0]) or not accepts(value[key], spec.args[1]): return false
		return true
	var kind := builtin(name)
	if kind == TYPE_NIL: return true
	if kind == TYPE_OBJECT: return value == null or (value is Object and is_instance_valid(value) and value.is_class(name))
	return typeof(value) == kind or (kind == TYPE_FLOAT and value is int)

static func constructor(name: String, literal: String) -> String:
	var spec := parse(name)
	if spec.is_empty() or spec.kind == "Enum": return literal
	var parts: Array[String] = [literal]
	for arg in spec.args:
		parts.append(str(builtin(arg)))
		parts.append(var_to_str(arg if builtin(arg) == TYPE_OBJECT else ""))
		parts.append("null")
	return "%s(%s)" % [spec.kind, ", ".join(parts)]

static func converted(value: Variant, name: String) -> Variant:
	var spec := parse(name)
	if spec.is_empty() or spec.kind == "Enum": return value
	var a: String = spec.args[0]
	var a_class := a if builtin(a) == TYPE_OBJECT else ""
	if spec.kind == "Array":
		if value.get_typed_builtin() == builtin(a) and str(value.get_typed_class_name()) == a_class and value.get_typed_script() == null: return value
		var base: Array = []
		base.append_array(value)
		return Array(base, builtin(a), a_class, null)
	var b: String = spec.args[1]
	var b_class := b if builtin(b) == TYPE_OBJECT else ""
	if value.get_typed_key_builtin() == builtin(a) and value.get_typed_value_builtin() == builtin(b) and str(value.get_typed_key_class_name()) == a_class and str(value.get_typed_value_class_name()) == b_class and value.get_typed_key_script() == null and value.get_typed_value_script() == null: return value
	var base: Dictionary = {}
	for key in value: base[key] = value[key]
	return Dictionary(base, builtin(a), a_class, null, builtin(b), b_class, null)
