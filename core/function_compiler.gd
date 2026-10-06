@tool
extends RefCounted

const Signature = preload("res://addons/GDBlueprints/core/event_signature.gd")

static func entry(chain: Dictionary) -> Dictionary:
	for sensor in chain.get("sensors", []):
		if str(sensor.get("type", "")) == "FunctionEntry": return sensor.get("properties", {})
	return {}

static func name_of(properties: Dictionary) -> String:
	return Signature.event_identifier(str(properties.get("function_name", "my_function")))

static func internal_name(name: String) -> String:
	return "_gdb_function_" + name.to_utf8_buffer().hex_encode()

static func configure(chains: Array) -> void:
	if chains.is_empty(): return
	var graph: Dictionary = chains[0].get("execution_graph", {})
	graph.sync_nodes = {}
	for chain in chains:
		if entry(chain).is_empty(): continue
		chain.synchronous = true
		for record in chain.get("actuators", []):
			graph.sync_nodes[str(record.get("properties", {}).get("_execution_id", ""))] = true
	for edge in graph.get("edges", []):
		if graph.sync_nodes.has(str(edge.from)): edge.synchronous = true

static func _any_return(id: String, output: String, edges: Array, specs: Dictionary, visiting: Dictionary) -> bool:
	for edge in edges:
		if str(edge.from) == id and str(edge.output) == output and _returns(str(edge.to), edges, specs, visiting): return true
	return false

static func _returns(id: String, edges: Array, specs: Dictionary, visiting: Dictionary) -> bool:
	if visiting.has(id) or not specs.has(id): return false
	visiting = visiting.duplicate()
	visiting[id] = true
	var kind := str(specs[id].get("kind", "action"))
	if kind == "function_return": return true
	if kind in ["break", "continue", "once"]: return false
	if kind == "branch": return _any_return(id,"true",edges,specs,visiting) and _any_return(id,"false",edges,specs,visiting)
	if kind == "function_call": return _any_return(id,"then",edges,specs,visiting) and _any_return(id,"failed",edges,specs,visiting)
	if kind == "switch":
		if not _any_return(id,"default",edges,specs,visiting): return false
		for index in specs[id].get("cases", []).size():
			if not _any_return(id,"case_%d" % index,edges,specs,visiting): return false
		return true
	if kind in ["for", "foreach"]: return _any_return(id,"completed",edges,specs,visiting)
	for edge in edges:
		if str(edge.from) == id and _returns(str(edge.to),edges,specs,visiting): return true
	return false

static func _result_scope(id: String, available: Array, edges: Array, records: Dictionary, specs: Dictionary, seen: Dictionary) -> String:
	if not records.has(id): return ""
	var key := id + str(available)
	if seen.has(key): return ""
	seen[key] = true
	var reference := RegEx.new()
	reference.compile('_flow\\.values\\["([^"]+)"\\]\\["result"\\]')
	for value in records[id].get("properties", {}).values():
		if not value is String: continue
		for found in reference.search_all(value):
			if found.get_string(1) not in available: return "Function Result from %s is used before its successful Then path at %s." % [found.get_string(1), id]
	var kind := str(specs.get(id, {}).get("kind", "action"))
	if kind in ["function_return", "break", "continue"]: return ""
	for edge in edges:
		if str(edge.from) != id: continue
		var next := available.duplicate()
		if kind == "function_call":
			next.erase(id)
			if str(edge.output) == "then": next.append(id)
		var error := _result_scope(str(edge.to), next, edges, records, specs, seen)
		if not error.is_empty(): return error
	return ""

static func validate(chains: Array, target: Node, manager) -> String:
	var functions: Dictionary = {}
	var events: Dictionary = {}
	var records: Dictionary = {}
	var edges: Array = []
	for chain in chains:
		var graph: Dictionary = chain.get("execution_graph", {})
		records.merge(graph.get("nodes", {}), true)
		edges.append_array(graph.get("edges", []))
		for sensor in chain.get("sensors", []):
			if str(sensor.get("type", "")) == "CustomEventSensor": events[Signature.event_identifier(str(sensor.get("properties", {}).get("event_name", "custom_event")))] = true
		var properties := entry(chain)
		if properties.is_empty(): continue
		if str(properties.get("function_name", "")).strip_edges().is_empty(): return "Enter a Function Name before compiling."
		var errors := Signature.warnings(properties)
		if not errors.is_empty(): return "; ".join(errors)
		var name := name_of(properties)
		if functions.has(name): return "Function %s has more than one entry. Each function needs one definition." % name
		if chain.get("sensors", []).size() != 1 or not chain.get("controllers", []).is_empty(): return "Function Entry must connect directly to its execution body, without legacy condition gates."
		functions[name] = properties
	for name in functions:
		if events.has(name): return "Function and Custom Event share the public method name: " + str(name)
	var specs: Dictionary = {}
	for id in records:
		var brick = manager._instantiate_brick(records[id])
		if brick == null: return "Unknown node definition in function graph: " + str(records[id].get("type", ""))
		specs[id] = brick.get_execution_spec()
	for chain in chains:
		var properties := entry(chain)
		var function_name := name_of(properties) if not properties.is_empty() else ""
		var locals: Array = Signature.parse(str(properties.get("_applied_locals", ""))).parameters
		var parameters: Array = Signature.parameters(properties)
		for record in chain.get("actuators", []):
			var type := str(record.get("type", ""))
			var props: Dictionary = record.get("properties", {})
			var node_spec: Dictionary = specs.get(str(props.get("_execution_id", "")), {})
			var kind := str(node_spec.get("kind", "action"))
			if kind in ["function_return", "set_local"] and function_name.is_empty(): return "%s requires a Function Entry execution path." % type
			if kind == "set_local" and str(node_spec.get("local_name", "")) not in locals.map(func(p): return p.name): return "Set Local refers to an undeclared local in " + function_name
			if kind == "function_call":
				var errors := Signature.warnings(props)
				if not errors.is_empty(): return "; ".join(errors)
				var called := name_of(props)
				if str(props.get("target", "self")).strip_edges().to_lower() in ["", "self"] and str(props.get("target_expression", "")).strip_edges() in ["", "self"]:
					if events.has(called): return "Call Function cannot await a Custom Event. Use Call Custom Event."
					if functions.has(called) and (Signature.identity(props) != Signature.identity(functions[called]) or str(props.get("_applied_return_type", "Variant")) != str(functions[called].get("_applied_return_type", "Variant"))): return "Call Function %s must match its definition's parameters and return type." % called
			if not function_name.is_empty():
				var brick = manager._instantiate_brick(record)
				var generated: Dictionary = manager._generate_brick_with_bindings(brick, target, "function_validation")
				if str(brick.get_execution_spec().get("kind")) == "delay" or str(generated.get("actuator_code", "")).contains("await ") or str(generated.get("inactive_code", "")).contains("await "):
					return "Function %s contains a waiting operation (%s). Move waiting work into an event graph." % [function_name, type]
			for value in props.values():
				if not value is String: continue
				var reference := RegEx.new()
				reference.compile('_flow\\.(function_arguments|function_locals)\\["([^"]+)"\\]\\["([^"]+)"\\]')
				for found in reference.search_all(value):
					var names: Array = parameters if found.get_string(1) == "function_arguments" else locals
					if function_name.is_empty() or found.get_string(2) != function_name or found.get_string(3) not in names.map(func(p): return p.name): return "Function argument/local is used outside its declared function scope."
		if not properties.is_empty() and str(properties.get("_applied_return_type", "Variant")) != "void":
			var returns := false
			for start in chain.get("execution_entries", []): returns = returns or _returns(str(start.to), edges, specs, {})
			if not returns: return "Function %s needs Return on every path, including loop Completed and call Failed paths." % function_name
		for start in chain.get("execution_entries", []):
			var error := _result_scope(str(start.to), [], edges, records, specs, {})
			if not error.is_empty(): return error
	return ""

static func wrappers(chains: Array) -> String:
	var lines: Array[String] = []
	var dispatch: Array[String] = []
	for chain in chains:
		var props := entry(chain)
		if props.is_empty(): continue
		var name := name_of(props)
		var internal := internal_name(name)
		var return_type := str(props.get("_applied_return_type", "Variant"))
		var params := Signature.parameters(props)
		var args: Array[String] = []
		var values: Array[String] = []
		for index in params.size():
			args.append(params[index].name)
			values.append('"%s": _gdb_args[%d]' % [params[index].name, index])
		var locals: Array[String] = []
		var local_types: Array[String] = []
		for local in Signature.parse(str(props.get("_applied_locals", ""))).parameters:
			locals.append('"%s": %s' % [local.name, Signature.Variables.to_gdscript_value_literal(Signature.Variables.get_default_value_for_variable_type(local.type), local.type)])
			local_types.append('"%s": "%s"' % [local.name, local.type])
		lines.append("func %s(_gdb_args: Array, _gdb_meter: Dictionary) -> Dictionary:" % internal)
		lines.append("\tif _gdb_args.size() != %d: return {\"ok\":false}" % params.size())
		for index in params.size():
			lines.append("\tif not _GDBFunctions.accepts(_gdb_args[%d], %s): return {\"ok\":false}" % [index, var_to_str(params[index].type)])
			lines.append("\t_gdb_args[%d] = _GDBFunctions.Pins.Collections.converted(_gdb_args[%d], %s)" % [index, index, var_to_str(params[index].type)])
		lines.append("\tvar _flow := _GDBFlow.context(_gdb_execution_epoch, _gdb_meter)")
		lines.append('\t_flow.function_name = %s' % var_to_str(name))
		lines.append('\t_flow.function_return_type = %s' % var_to_str(return_type))
		lines.append('\t_flow.function_arguments = {%s: {%s}}' % [var_to_str(name), ", ".join(values)])
		lines.append('\t_flow.function_locals = {%s: {%s}}' % [var_to_str(name), ", ".join(locals)])
		lines.append('\t_flow.function_local_types = {%s}' % ", ".join(local_types))
		lines.append("\tvar _gdb_previous_meter := _gdb_dispatch_meter")
		lines.append("\t_gdb_dispatch_meter = _flow.meter")
		if not chain.get("execution_entries", []).is_empty():
			lines.append("\t_blueprint_%s(0.0, _flow)" % chain.name)
		lines.append("\t_gdb_dispatch_meter = _gdb_previous_meter")
		lines.append('\treturn {"ok": _GDBFlow.valid(self, _flow) and (_flow.returned or %s), "result": _flow.result}' % str(return_type == "void"))
		lines.append("func %s(%s) -> %s:" % [name, Signature.declaration(props), "void" if return_type == "void" else Signature.Pins.variable_type(return_type)])
		lines.append("\tvar _gdb_result := %s([%s], _gdb_dispatch_meter)" % [internal, ", ".join(args)])
		lines.append('\tif not _gdb_result.ok: push_error("GDBlueprints: function %s was cancelled or did not return.")' % name)
		if return_type != "void":
			var fallback := Signature.Variables.to_gdscript_value_literal(Signature.Variables.get_default_value_for_variable_type(return_type), return_type)
			lines.append("\treturn _gdb_result.result if _gdb_result.ok else %s" % fallback)
		else: lines.append("\treturn")
		dispatch.append('\t\t%s: return %s(arguments, meter)' % [var_to_str(name), internal])
	if not dispatch.is_empty():
		lines.append("func _gdb_function_dispatch(method: String, arguments: Array, meter: Dictionary) -> Dictionary:")
		lines.append("\tmatch method:")
		lines.append_array(dispatch)
		lines.append('\treturn {"ok": true, "result": callv(method, arguments)}')
	return "\n".join(lines)
