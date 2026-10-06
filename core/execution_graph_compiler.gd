@tool
extends RefCounted

## One execution backend; the manager retains event/condition polling adapters.
const FORMAT_VERSION := 4

static func function_name(node_id: String) -> String:
	return "_gdb_exec_" + node_id.to_utf8_buffer().hex_encode()

static func _index_edges(edges: Array) -> Dictionary:
	var outgoing := {}
	for edge in edges:
		var source := str(edge.from)
		if not outgoing.has(source): outgoing[source] = []
		outgoing[source].append(edge)
	return outgoing

static func _outgoing(edges: Variant, node_id: String) -> Array:
	if edges is Dictionary: return edges.get(node_id, [])
	# Preserve the helper API for callers that still supply an edge array.
	var result: Array = []
	for edge in edges:
		if str(edge.from) == node_id: result.append(edge)
	return result

static func _output_nodes(edges: Variant, node_id: String, outputs: Array) -> Dictionary:
	var outgoing: Dictionary = edges if edges is Dictionary else _index_edges(edges)
	var result: Dictionary = {}
	var pending: Array = []
	for edge in _outgoing(outgoing, node_id):
		if str(edge.output) in outputs: pending.append(str(edge.to))
	var cursor := 0
	while cursor < pending.size():
		var id := str(pending[cursor])
		cursor += 1
		if result.has(id): continue
		result[id] = true
		for edge in _outgoing(outgoing, id):
			if str(edge.input) not in ["reset", "cancel"]: pending.append(str(edge.to))
	return result

static func inactive_calls(edges: Variant, node_id: String, rejected: Array, selected: Array, inactive_nodes: Dictionary, indent: String) -> Array[String]:
	var off := _output_nodes(edges,node_id,rejected)
	var on := _output_nodes(edges,node_id,selected)
	var lines: Array[String] = []
	for id in inactive_nodes:
		if off.has(id) and not on.has(id): lines.append(indent + "%s_inactive(_delta)" % function_name(str(id)))
	return lines

static func calls(edges: Variant, node_id: String, output: String, indent: String = "\t") -> Array[String]:
	var lines: Array[String] = []
	for edge in _outgoing(edges, node_id):
		if str(edge.output) == output:
			lines.append(indent + "if _GDBFlow.stopped(self, _flow): return")
			var call := "%s(%s, _delta, _flow)" % [function_name(str(edge.to)), var_to_str(str(edge.input))]
			if bool(edge.get("synchronous",false)):
				lines.append(indent + call)
			elif bool(edge.get("legacy_async",false)):
				lines.append(indent + "if _flow.loops.is_empty():")
				lines.append(indent + "\t" + call.replace(", _flow)", ", _GDBFlow.context(_flow.epoch, _flow.meter, _flow.event_arguments))"))
				lines.append(indent + "else:")
				lines.append(indent + "\tawait " + call)
			else: lines.append(indent + "await " + call)
	return lines

## Old chain-only saves lower to ordered edges without changing the saved data.
## Keep their code namespaces and per-chain instances for compatibility.
static func normalize(chains: Array) -> Array:
	var result: Array = chains.duplicate(true)
	var graph := {"version":FORMAT_VERSION, "nodes":{}, "edges":[]}
	var old_edges := false
	for chain in result:
		if chain.has("execution_graph") and int(chain.execution_graph.get("version",1)) < 2: old_edges = true
	for chain in result:
		if chain.has("execution_graph"):
			graph.nodes.merge(chain.execution_graph.nodes, true)
			if old_edges:
				for edge in chain.execution_graph.edges: edge.legacy_async = true
			graph.edges.append_array(chain.execution_graph.edges)
			chain.erase("execution_graph")
		if chain.has("execution_entries"):
			if old_edges:
				for entry in chain.execution_entries: entry.legacy_async = true
			continue
		chain.execution_entries = []
		var previous := ""
		var actions: Array = chain.get("actuators", [])
		for index in actions.size():
			var id := "legacy_%s_%d" % [chain.name, index]
			var record: Dictionary = actions[index]
			if not record.has("properties"): record.properties = {}
			record.properties._execution_id = id
			record.properties._execution_namespace = "%s_%d" % [chain.name, index]
			graph.nodes[id] = record
			if previous.is_empty(): chain.execution_entries.append({"to":id,"input":"in"})
			else: graph.edges.append({"from":previous,"output":"then","to":id,"input":"in"})
			previous = id
	if not result.is_empty(): result[0].execution_graph = graph
	return result

static func compile(graph: Dictionary, manager, target: Node, has_actuator_sensor: bool = false) -> String:
	var lines: Array[String] = [
		'const _GDBFlow = preload("res://addons/GDBlueprints/core/execution_runtime.gd")',
		'const _GDBFunctions = preload("res://addons/GDBlueprints/core/function_runtime.gd")',
		'const _GDBDebugSnapshot = preload("res://addons/GDBlueprints/core/debug_snapshot.gd")',
		'var _gdb_execution_epoch: int = 0',
		'var _gdb_dispatch_meter: Dictionary = {}',
		'func _gdb_cancel_execution() -> void:',
		'\t_gdb_execution_epoch += 1',
		''
	]
	var edges := _index_edges(graph.get("edges", []))
	var inactive_nodes: Dictionary = {}
	var prepared: Dictionary = {}
	for id in graph.get("nodes", {}):
		var instance = manager._instantiate_brick(graph.nodes[id])
		var output: Dictionary = manager._generate_brick_with_bindings(instance, target, function_name(str(id)))
		prepared[id] = {"brick":instance, "generated":output}
		if not str(output.get("inactive_code", "")).is_empty(): inactive_nodes[id] = true
	for node_id in graph.get("nodes", {}):
		var data: Dictionary = graph.nodes[node_id]
		var brick = prepared[node_id].brick
		var spec: Dictionary = brick.get_execution_spec()
		var name := function_name(str(node_id))
		var kind := str(spec.get("kind", "action"))
		var generated: Dictionary = prepared[node_id].generated
		var wait_prefix := "" if graph.get("sync_nodes", {}).has(str(node_id)) else "await "
		if kind == "once": lines.append("var %s_closed: bool = %s" % [name, str(bool(spec.get("start_closed", false)))])
		if kind == "delay":
			lines.append("var %s_pending: Dictionary = {}" % name)
		lines.append("func %s(_entry: String = \"in\", _delta: float = 0.0, _flow: Dictionary = {}) -> void:" % name)
		lines.append("\tif _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)")
		lines.append("\tif not _GDBFlow.enter(self, _flow, %s): return" % var_to_str(str(node_id)))
		var breakpoint_enabled := bool(data.get("debug_enabled", false))
		if graph.get("sync_nodes", {}).has(str(node_id)):
			lines.append("\tif has_node(\"/root/GDBlueprintsDebugger\"): get_node(\"/root/GDBlueprintsDebugger\").trace_node(self, %s, _entry, _flow, %s)" % [var_to_str(str(node_id)), str(breakpoint_enabled)])
		else:
			lines.append("\tif has_node(\"/root/GDBlueprintsDebugger\"): await get_node(\"/root/GDBlueprintsDebugger\").before_node(self, %s, _entry, _flow, %s)" % [var_to_str(str(node_id)), str(breakpoint_enabled)])
		lines.append("\tif _GDBFlow.valid(self, _flow): %s%s_body(_entry, _delta, _flow)" % [wait_prefix, name])
		lines.append("\t_flow.meter.depth -= 1")
		lines.append("func %s_body(_entry: String, _delta: float, _flow: Dictionary) -> void:" % name)
		if has_actuator_sensor and not str(data.get("instance_name", "")).is_empty():
			lines.append("\t_actuator_active_flags[%s] = true" % var_to_str(str(data.instance_name)))
		var debug_code: String = brick.get_debug_code()
		if not debug_code.is_empty(): lines.append("\t" + debug_code)
		match kind:
			"function_return":
				lines.append("\t_GDBFunctions.finish(_flow, %s)" % str(spec.value))
			"set_local":
				lines.append("\t_GDBFunctions.set_local(_flow, %s, %s)" % [var_to_str(str(spec.local_name)), str(spec.value)])
				lines.append_array(calls(edges, str(node_id), "then"))
			"function_call":
				lines.append("\t_flow.values.erase(%s)" % var_to_str(str(node_id)))
				lines.append("\tvar result := _GDBFunctions.invoke(%s, %s, %s, %s, _flow.meter)" % [str(spec.target), var_to_str(str(spec.method)), str(spec.arguments), var_to_str(str(spec.return_type))])
				lines.append("\tif bool(result.get(\"ok\", false)):")
				lines.append("\t\t_flow.values[%s] = result" % var_to_str(str(node_id)))
				lines.append_array(calls(edges, str(node_id), "then", "\t\t"))
				lines.append("\telse:")
				lines.append_array(calls(edges, str(node_id), "failed", "\t\t"))
				lines.append("\t\tpass")
			"once":
				lines.append("\tif _entry == \"reset\":")
				lines.append("\t\t%s_closed = false" % name)
				lines.append("\t\treturn")
				lines.append("\tif %s_closed: return" % name)
				lines.append("\t%s_closed = true" % name)
				lines.append_array(calls(edges, str(node_id), "then"))
			"delay":
				lines.append("\tif _entry == \"cancel\":")
				lines.append("\t\tif not %s_pending.is_empty(): %s_pending.cancelled = true" % [name,name])
				lines.append("\t\t%s_pending = {}" % name)
				lines.append("\t\treturn")
				lines.append("\tif not %s_pending.is_empty() and _GDBFlow.valid(self, %s_pending): return" % [name,name])
				lines.append("\t%s_pending = _flow" % name)
				lines.append("\tvar seconds := float(%s)" % str(spec.get("duration", "0.0")))
				lines.append("\tif not is_finite(seconds):")
				lines.append("\t\t_flow.cancelled = true")
				lines.append("\t\tpush_error(\"GDBlueprints: Delay duration must be finite.\")")
				lines.append("\t\treturn")
				lines.append("\tawait get_tree().create_timer(maxf(0.0, seconds), false).timeout")
				lines.append("\tif not _GDBFlow.valid(self, _flow): return")
				lines.append("\t%s_pending = {}" % name)
				lines.append_array(calls(edges, str(node_id), "completed"))
			"branch":
				lines.append("\tif %s:" % str(spec.get("condition", "false")))
				lines.append_array(inactive_calls(edges,str(node_id),[str(spec.get("false_output","false"))],[str(spec.get("true_output","true"))],inactive_nodes,"\t\t"))
				var yes := calls(edges, str(node_id), str(spec.get("true_output", "true")), "\t\t")
				lines.append_array(yes if not yes.is_empty() else PackedStringArray(["\t\tpass"]))
				lines.append("\telse:")
				lines.append_array(inactive_calls(edges,str(node_id),[str(spec.get("true_output","true"))],[str(spec.get("false_output","false"))],inactive_nodes,"\t\t"))
				var no := calls(edges, str(node_id), str(spec.get("false_output", "false")), "\t\t")
				lines.append_array(no if not no.is_empty() else PackedStringArray(["\t\tpass"]))
			"sequence":
				for output in brick.get_exec_output_definitions(): lines.append_array(calls(edges, str(node_id), str(output.id)))
			"switch":
				lines.append("\tvar selection = %s" % str(spec.get("expression", "0")))
				var cases: Array = spec.get("cases", [])
				var outputs: Array = ["default"]
				for index in cases.size(): outputs.append("case_%d" % index)
				for index in cases.size():
					lines.append("\t%s typeof(selection) == typeof(%s) and selection == %s:" % ["if" if index == 0 else "elif", var_to_str(cases[index]), var_to_str(cases[index])])
					lines.append_array(inactive_calls(edges,str(node_id),outputs,["case_%d" % index],inactive_nodes,"\t\t"))
					lines.append_array(calls(edges, str(node_id), "case_%d" % index, "\t\t"))
					lines.append("\t\tpass")
				if not cases.is_empty(): lines.append("\telse:")
				lines.append_array(inactive_calls(edges,str(node_id),outputs,["default"],inactive_nodes,"\t\t" if not cases.is_empty() else "\t"))
				lines.append_array(calls(edges, str(node_id), "default", "\t\t" if not cases.is_empty() else "\t"))
				lines.append("\t\tpass" if not cases.is_empty() else "\tpass")
			"for", "foreach":
				var value_key := var_to_str(str(spec.get("key", node_id)))
				if kind == "for":
					lines.append("\tvar first := int(%s)" % str(spec.first))
					lines.append("\tvar last := int(%s)" % str(spec.last))
					lines.append("\tvar step := int(%s)" % str(spec.step))
					lines.append("\tif step == 0:")
					lines.append("\t\t_flow.cancelled = true")
					lines.append("\t\tpush_error(\"GDBlueprints: For Loop Step must not be zero.\")")
					lines.append("\t\treturn")
					lines.append("\tvar index := first")
				else:
					lines.append("\tvar source = %s" % str(spec.items))
					lines.append("\tif not source is Array:")
					lines.append("\t\t_flow.cancelled = true")
					lines.append("\t\tpush_error(\"GDBlueprints: For Each requires an Array.\")")
					lines.append("\t\treturn")
					lines.append("\tvar items: Array = source.duplicate()")
					lines.append("\tvar index := 0")
				lines.append("\tvar frame := {\"control\":\"\"}")
				lines.append("\t_flow.loops.append(frame)")
				lines.append("\tvar previous_value = _flow.values.get(%s)" % value_key)
				lines.append("\twhile %s:" % ("(index <= last if step > 0 else index >= last)" if kind == "for" else "index < items.size()"))
				lines.append("\t\tif not _GDBFlow.enter(self, _flow, %s): break" % var_to_str(str(node_id)))
				lines.append("\t\t_flow.meter.depth -= 1")
				lines.append("\t\tframe.control = \"\"")
				lines.append("\t\t_flow.values[%s] = %s" % [value_key, '{"index":index}' if kind == "for" else '{"index":index,"item":items[index]}'])
				# Loop body is a separate method so Break/Continue return through calls.
				lines.append("\t\t%s%s_loop_body(_delta, _flow)" % [wait_prefix, name])
				lines.append("\t\tif _flow.returned or not _GDBFlow.valid(self, _flow) or frame.control == \"break\": break")
				if kind == "for":
					lines.append("\t\tvar next_index := index + step")
					lines.append("\t\tif (step > 0 and next_index <= index) or (step < 0 and next_index >= index): break")
					lines.append("\t\tindex = next_index")
				else: lines.append("\t\tindex += 1")
				lines.append("\t_flow.loops.pop_back()")
				lines.append("\tif previous_value == null: _flow.values.erase(%s)" % value_key)
				lines.append("\telse: _flow.values[%s] = previous_value" % value_key)
				lines.append_array(calls(edges, str(node_id), "completed"))
				lines.append("func %s_loop_body(_delta: float, _flow: Dictionary) -> void:" % name)
				lines.append_array(calls(edges, str(node_id), "body"))
			"break", "continue": lines.append("\t_GDBFlow.control(_flow, %s)" % var_to_str(kind))
			_:
				for line in str(generated.get("actuator_code", "pass")).split("\n"): lines.append("\t" + line)
				lines.append_array(calls(edges, str(node_id), "then"))
		lines.append("\tpass")
		lines.append("")
		if not str(generated.get("inactive_code", "")).is_empty():
			lines.append("func %s_inactive(_delta: float) -> void:" % name)
			for line in str(generated.inactive_code).split("\n"): lines.append("\t" + line)
	return "\n".join(lines)
