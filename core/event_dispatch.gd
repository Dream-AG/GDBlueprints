extends RefCounted

const Members = preload("res://addons/GDBlueprints/core/member_catalog.gd")

## Validate calls before invoking GDScript; argument expressions are evaluated once
## by the caller when building the arguments Array.
static func dispatch(target: Variant, method: String, arguments: Array, report_errors: bool = true) -> bool:
	var error := validation_error(target, method, arguments)
	if not error.is_empty():
		if report_errors: push_warning("Call Custom Event %s: %s; call skipped." % [method, error])
		return false
	prepare_arguments(target, method, arguments)
	target.callv(method, arguments)
	return true

static func validation_error(target: Variant, method: String, arguments: Array) -> String:
	var error := ""
	if not target is Object or not is_instance_valid(target):
		error = "target is not a live Object"
	else:
		var found := false
		for info in target.get_method_list():
			if str(info.name) != method: continue
			found = true
			var parameters: Array = info.get("args", [])
			var required: int = parameters.size() - info.get("default_args", []).size()
			if arguments.size() < required or (arguments.size() > parameters.size() and not (int(info.get("flags", 0)) & METHOD_FLAG_VARARG)):
				error = "argument count does not match the target method"
				break
			for index in mini(arguments.size(), parameters.size()):
				if not _accepts(arguments[index], parameters[index]):
					error = "argument %d (%s) has an incompatible type" % [index + 1, parameters[index].name]
					break
			break
		if not found: error = "target does not implement the method"
	return error

static func _accepts(value: Variant, parameter: Dictionary) -> bool:
	var expected := int(parameter.get("type", TYPE_NIL))
	if expected == TYPE_NIL: return true
	if expected == TYPE_OBJECT:
		if value == null: return true
		if not value is Object or not is_instance_valid(value): return false
		var class_name_text := str(parameter.get("class_name", ""))
		return class_name_text.is_empty() or Members.script_instance_matches(value, class_name_text)
	if expected in [TYPE_ARRAY, TYPE_DICTIONARY]:
		var schema := Members.type_name(parameter)
		if str(parameter.get("hint_string", "")) != "" and schema in ["Array", "Dictionary"]:
			# An unsupported reflected element/script type must never reach callv unchecked.
			return false
		return Members.Pins.Collections.accepts(value, schema)
	if expected == TYPE_FLOAT and value is int: return true
	return typeof(value) == expected


static func prepare_arguments(target: Object, method: String, arguments: Array) -> void:
	for info in target.get_method_list():
		if str(info.name) != method: continue
		var args: Array = info.get("args", [])
		for i in mini(args.size(), arguments.size()):
			arguments[i] = Members.Pins.Collections.converted(arguments[i], Members.type_name(args[i]))
		return
