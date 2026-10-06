extends RefCounted

const Members = preload("res://addons/GDBlueprints/core/member_catalog.gd")
const Dispatch = preload("res://addons/GDBlueprints/core/event_dispatch.gd")

static func callback(source: Variant, signal_name: String, receiver: Variant, method: String, forward: bool) -> Dictionary:
	if not source is Object or not is_instance_valid(source) or not source.has_signal(signal_name) or not receiver is Object or not is_instance_valid(receiver) or not receiver.has_method(method):
		return {"error":"Signal or receiver method was not found."}
	var signal_args: Array = []
	for info in source.get_signal_list():
		if str(info.name) == signal_name: signal_args = info.get("args", [])
	var expected: Array = []
	var defaults := 0
	for info in receiver.get_method_list():
		if str(info.name) == method:
			expected = info.get("args", [])
			defaults = info.get("default_args", []).size()
	if forward:
		if signal_args.size() < expected.size() - defaults or signal_args.size() > expected.size(): return {"error":"Signal and receiver argument counts differ."}
		for i in signal_args.size():
			var source_type := int(signal_args[i].get("type", TYPE_NIL))
			var target_type := int(expected[i].get("type", TYPE_NIL))
			if source_type == TYPE_NIL and target_type != TYPE_NIL: return {"error":"A Variant signal cannot guarantee the receiver's specific type. Use a Variant event parameter and validate inside the graph."}
			var source_class := str(signal_args[i].get("class_name", ""))
			var target_class := str(expected[i].get("class_name", ""))
			if not target_class.is_empty() and not ClassDB.class_exists(target_class) and source_class != target_class:
				return {"error":"Script-class signal parameters must match the receiver's declared class."}
			if not Members.Pins.compatible(Members.type_name(signal_args[i]), Members.type_name(expected[i])):
				return {"error":"Signal and receiver argument types differ."}
	elif expected.size() > defaults:
		return {"error":"Receiver requires arguments. Enable Forward Arguments and match the signal signature."}
	var callable := Callable(receiver, method)
	if not forward: callable = callable.unbind(signal_args.size())
	return {"error":"", "callable":callable}

static func connect_event(source: Variant, signal_name: String, receiver: Variant, method: String, forward: bool, disconnecting: bool = false) -> bool:
	var result := callback(source, signal_name, receiver, method, forward)
	if not str(result.error).is_empty():
		push_warning("GDBlueprints signal: " + str(result.error))
		return false
	var callable: Callable = result.callable
	if disconnecting:
		if source.is_connected(signal_name, callable): source.disconnect(signal_name, callable)
		return true
	return true if source.is_connected(signal_name, callable) else source.connect(signal_name, callable) == OK

static func emit_checked(source: Variant, signal_name: String, arguments: Array) -> bool:
	if not source is Object or not is_instance_valid(source) or not source.has_signal(signal_name): return false
	for info in source.get_signal_list():
		if str(info.name) != signal_name: continue
		var args: Array = info.get("args", [])
		if args.size() != arguments.size(): return false
		for i in args.size():
			if not Dispatch._accepts(arguments[i], args[i]): return false
			arguments[i] = Members.Pins.Collections.converted(arguments[i], Members.type_name(args[i]))
		var call_args: Array = [signal_name]
		call_args.append_array(arguments)
		return source.callv("emit_signal", call_args) == OK
	return false
