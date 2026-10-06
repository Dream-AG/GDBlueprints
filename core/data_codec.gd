@tool
extends RefCounted
## Bounded, data-only Variant encoding. Never use *_with_objects for save files.
const MAX_BYTES := 16 * 1024 * 1024
const MAX_ITEMS := 100000
const MAX_DEPTH := 32

static func error(message: String) -> Dictionary:
	return {"ok":false, "error":message, "data":{}, "recovered":false}

static func validate(value: Variant, depth: int = 0, budget: Dictionary = {}) -> String:
	if budget.is_empty(): budget.count = 0
	budget.count += 1
	if depth > MAX_DEPTH: return "Data is cyclic or exceeds 32 nested levels."
	if budget.count > MAX_ITEMS: return "Data exceeds 100000 entries."
	var kind := typeof(value)
	if kind in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]: return "Live Objects, Resources, Callables, Signals and RIDs are not save data. Use stable IDs or paths."
	if value is Array:
		if value.get_typed_builtin() == TYPE_OBJECT: return "Object-typed containers are not save data."
		for item in value:
			var issue := validate(item, depth + 1, budget)
			if not issue.is_empty(): return issue
	elif value is Dictionary:
		if value.get_typed_key_builtin() == TYPE_OBJECT or value.get_typed_value_builtin() == TYPE_OBJECT: return "Object-typed containers are not save data."
		for key in value:
			var issue := validate(key, depth + 1, budget)
			if issue.is_empty(): issue = validate(value[key], depth + 1, budget)
			if not issue.is_empty(): return issue
	elif kind >= TYPE_PACKED_BYTE_ARRAY:
		budget.count += value.size()
		if budget.count > MAX_ITEMS: return "Packed data exceeds 100000 entries."
	return ""

static func encode(data: Dictionary) -> Dictionary:
	var issue := validate(data)
	if not issue.is_empty(): return error(issue)
	var bytes := var_to_bytes(data)
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return error("Encoded data exceeds 16 MiB or cannot be encoded.")
	return {"ok":true, "error":"", "bytes":bytes}

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return error("Invalid encoded data size.")
	var data = bytes_to_var(bytes)
	if not data is Dictionary: return error("Save payload is not a Dictionary.")
	var issue := validate(data)
	if not issue.is_empty(): return error(issue)
	return {"ok":true, "error":"", "data":data}

static func checksum(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()
