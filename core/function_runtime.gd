extends RefCounted

const Dispatch = preload("res://addons/GDBlueprints/core/event_dispatch.gd")
const Pins = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")

static func descriptor(type_name: String) -> Dictionary:
	if type_name == "void": return {"type":TYPE_NIL}
	if ClassDB.class_exists(type_name): return {"type":TYPE_OBJECT, "class_name":type_name}
	for kind in TYPE_MAX:
		if Pins.variable_type(Pins.type_from_variant_type(kind)) == type_name:
			return {"type":kind}
	return {"type":TYPE_NIL}

static func accepts(value: Variant, type_name: String) -> bool:
	if type_name == "void": return value == null
	return Pins.Collections.accepts(value, type_name)

static func finish(flow: Dictionary, value: Variant) -> void:
	if not accepts(value, str(flow.function_return_type)):
		flow.cancelled = true
		push_error("GDBlueprints: Return value has the wrong type for " + str(flow.function_name))
		return
	value = Pins.Collections.converted(value, str(flow.function_return_type))
	flow.result = float(value) if str(flow.function_return_type) == "float" and value is int else value
	flow.returned = true

static func set_local(flow: Dictionary, name: String, value: Variant) -> void:
	var types: Dictionary = flow.function_local_types
	if not types.has(name) or not accepts(value, str(types[name])):
		flow.cancelled = true
		push_error("GDBlueprints: Invalid local assignment: " + name)
		return
	value = Pins.Collections.converted(value, str(types[name]))
	flow.function_locals[flow.function_name][name] = float(value) if str(types[name]) == "float" and value is int else value

static func invoke(target: Variant, method: String, arguments: Array, return_type: String, meter: Dictionary) -> Dictionary:
	var error := Dispatch.validation_error(target, method, arguments)
	if not error.is_empty():
		push_warning("Call Function %s: %s; Failed output selected." % [method, error])
		return {"ok":false}
	Dispatch.prepare_arguments(target, method, arguments)
	var result: Dictionary
	if target.has_method("_gdb_function_dispatch"):
		result = target.call("_gdb_function_dispatch", method, arguments, meter)
	else:
		result = {"ok":true, "result":target.callv(method, arguments)}
	if bool(result.get("ok", false)) and not accepts(result.get("result"), return_type):
		push_warning("Call Function %s: incompatible return type; Failed output selected." % method)
		return {"ok":false}
	if bool(result.get("ok", false)) and return_type == "float" and result.get("result") is int:
		result.result = float(result.result)
	return result
