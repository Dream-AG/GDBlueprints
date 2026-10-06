@tool
extends RefCounted

const Variables = preload("res://addons/GDBlueprints/core/blueprint_variable_utils.gd")
const Pins = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")

## Reflection reads declarations only; it never calls a user method or getter.
static func type_name(info: Dictionary, returning: bool = false) -> String:
	var kind := int(info.get("type", TYPE_NIL))
	if kind == TYPE_NIL:
		return "void" if returning and not (int(info.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT) else "Variant"
	var hint := str(info.get("hint_string", ""))
	if kind == TYPE_ARRAY and int(info.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE:
		var typed := "Array[" + hint + "]"
		if not Pins.Collections.parse(typed).is_empty(): return Pins.variable_type(typed)
	if kind == TYPE_DICTIONARY and int(info.get("hint", 0)) == PROPERTY_HINT_DICTIONARY_TYPE:
		var typed := "Dictionary[" + hint.replace(";", ", ") + "]"
		if not Pins.Collections.parse(typed).is_empty(): return Pins.variable_type(typed)
	if kind == TYPE_OBJECT:
		var class_type := str(info.get("class_name", ""))
		return class_type if ClassDB.class_exists(class_type) else "Object"
	# Preserve StringName and NodePath in call signatures, rather than coercing to String.
	return type_string(kind)

static func collect(target: Object, signals: bool = false) -> Array:
	if not is_instance_valid(target): return []
	var declarations: Dictionary = {}
	for info in target.get_signal_list() if signals else target.get_method_list(): declarations[str(info.name)] = info
	# Editor placeholder instances may omit handwritten methods. Read the script too.
	var script: Script = target.get_script()
	while script != null:
		for info in script.get_script_signal_list() if signals else script.get_script_method_list():
			if not declarations.has(str(info.name)): declarations[str(info.name)] = info
		script = script.get_base_script()
	var result: Array = []
	for name in declarations:
		if str(name).begins_with("_"): continue
		var info: Dictionary = declarations[name]
		var parts: Array[String] = []
		var unsupported := bool(int(info.get("flags", 0)) & METHOD_FLAG_VARARG)
		var defaults: Dictionary = {}
		var args: Array = info.get("args", [])
		var default_args: Array = info.get("default_args", [])
		for index in args.size():
			var arg_name := str(args[index].name)
			parts.append("%s: %s" % [arg_name, type_name(args[index])])
			if index >= args.size() - default_args.size():
				var default_value: Variant = default_args[index - args.size() + default_args.size()]
				var type := type_name(args[index])
				defaults["argument_" + arg_name] = Variables._native_value_literal(default_value) if type == "Variant" else Variables.to_gdscript_value_literal(default_value, type)
		result.append({"name":str(name), "parameters":", ".join(parts), "return_type":type_name(info.get("return", {}), true), "defaults":defaults, "unsupported":unsupported, "info":info})
	result.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return result

static func script_instance_matches(value: Object, expected: String) -> bool:
	if value.is_class(expected): return true
	var script: Script = value.get_script()
	while script != null:
		if script.get_global_name() == expected: return true
		script = script.get_base_script()
	return false
