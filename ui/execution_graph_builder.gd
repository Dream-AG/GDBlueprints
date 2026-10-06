extends RefCounted

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")

## Preserve the old multi-input condition interpretation of saved Branch/Cast
## nodes. New nodes use execution entries; replacing a compatibility node opts in.
static func migrate_graph(graph: Dictionary, saved_chains: Array = []) -> Dictionary:
	var migrated := graph.duplicate(true)
	if int(migrated.get("execution_version", 1)) >= 2: return migrated
	var native_edges := false
	for chain in saved_chains:
		if chain.has("execution_graph"): native_edges = true
	if native_edges:
		for record in migrated.get("nodes", []):
			if record.has("brick_class"):
				if not record.has("properties"): record.properties = {}
				record.properties._legacy_async_fanout = true
	if not native_edges:
		for record in migrated.get("nodes", []):
			if str(record.get("brick_class", "")) in ["BranchController", "CastToScriptController"]:
				if not record.has("properties"): record.properties = {}
				record.properties._legacy_condition_inputs = true
	migrated.execution_version = 2
	return migrated

static func is_required(_panel) -> bool:
	return true # All graphs use the same execution backend.

static func _error(message: String) -> Array:
	return [{"name":"execution_error", "sensors":[], "controllers":[], "actuators":[], "compile_error":message}]

static func _destinations(panel, connections: Dictionary, from: String, port: int, seen: Dictionary = {}) -> Array:
	if seen.has(from): return []
	seen = seen.duplicate()
	seen[from] = true
	var result: Array = []
	for connection in connections.get(from, {}).get(port, []):
		var target = panel.graph_edit.get_node_or_null(NodePath(connection.to_node))
		if target == null: continue
		if target.has_meta("is_reroute"):
			result.append_array(_destinations(panel, connections, str(target.name), 0, seen))
		elif target.has_meta("brick_data"):
			var inputs: Array = target.get_meta("brick_data").brick_instance.get_exec_input_definitions()
			var input_port := int(connection.to_port)
			if input_port >= 0 and input_port < inputs.size(): result.append({"to":str(target.name), "input":str(inputs[input_port].id)})
	return result

static func _cycle(id: String, edges: Dictionary, active: Dictionary, done: Dictionary) -> bool:
	var pending: Array = [{"id":id, "exit":false}]
	while not pending.is_empty():
		var item: Dictionary = pending.pop_back()
		var current := str(item.id)
		if bool(item.exit):
			active.erase(current)
			done[current] = true
			continue
		if done.has(current): continue
		if active.has(current): return true
		active[current] = true
		pending.append({"id":current, "exit":true})
		for edge in edges.get(current, []):
			if str(edge.input) not in ["reset", "cancel"]:
				pending.append({"id":str(edge.to), "exit":false})
	return false

static func _reachable(entries: Array, edges: Array, definitions: Dictionary) -> Dictionary:
	var outgoing := _index_edges(edges)
	var result: Dictionary = {}
	var pending: Array = []
	for entry in entries: pending.append(str(entry.to))
	var cursor := 0
	while cursor < pending.size():
		var id := str(pending[cursor])
		cursor += 1
		if result.has(id) or not definitions.has(id): continue
		result[id] = definitions[id]
		for edge in outgoing.get(id, []):
			if str(edge.input) not in ["reset", "cancel"]: pending.append(str(edge.to))
	return result

static func _index_edges(edges: Array) -> Dictionary:
	var result := {}
	for edge in edges:
		var key := str(edge.from)
		if not result.has(key): result[key] = []
		result[key].append(edge)
	return result

static func _entries(id: String, edges: Array, definitions: Dictionary) -> Array:
	var result: Array = []
	for edge in edges:
		if str(edge.from) == id and definitions.has(str(edge.to)): result.append({"to":edge.to,"input":edge.input,"legacy_async":bool(edge.get("legacy_async",false))})
	return result

static func _tree(id: String, events: Dictionary, gates: Dictionary, edges: Array) -> Dictionary:
	var result := {"sensors":[],"controller_inputs":[],"controller":gates[id]}
	for edge in edges:
		if str(edge.to) != id: continue
		if events.has(str(edge.from)): result.sensors.append(events[str(edge.from)])
		elif gates.has(str(edge.from)): result.controller_inputs.append(_tree(str(edge.from),events,gates,edges))
	return result

static func _scope_error(id: String, input: String, scope: Array, edges: Array, specs: Dictionary, seen: Dictionary) -> String:
	var outgoing := _index_edges(edges)
	var loops: Array = []
	for candidate in specs:
		if str(specs[candidate].get("kind")) in ["for", "foreach"]: loops.append(candidate)
	var pending: Array = [{"id":id, "input":input, "scope":scope}]
	while not pending.is_empty():
		var item: Dictionary = pending.pop_back()
		var current := str(item.id)
		var current_scope: Array = item.scope
		if str(item.input) in ["reset", "cancel"] or not specs.has(current): continue
		var key := current + str(current_scope)
		if seen.has(key): continue
		seen[key] = true
		var kind := str(specs[current].get("kind", "action"))
		if kind in ["break", "continue"] and current_scope.is_empty(): return "%s must be inside a For Loop or For Each Body path." % current
		for loop_id in loops:
			if loop_id in current_scope: continue
			for value in specs[current].get("_properties", {}).values():
				if value is String and (value.contains("_flow.values.get(%s" % var_to_str(str(loop_id))) or value.contains("_flow.values[%s]" % var_to_str(str(loop_id)))):
					return "%s uses %s loop data outside its Body path. Store the value in a graph variable if it is needed later." % [current, loop_id]
		for edge in outgoing.get(current, []):
			var child_scope := current_scope.duplicate()
			if kind in ["for", "foreach"] and str(edge.output) == "body": child_scope.append(current)
			pending.append({"id":str(edge.to), "input":str(edge.input), "scope":child_scope})
	return ""

static func build(panel) -> Array:
	var connections: Dictionary = {}
	for connection in panel.graph_edit.get_connection_list():
		var key := str(connection.from_node)
		var port := int(connection.from_port)
		if not connections.has(key): connections[key] = {}
		if not connections[key].has(port): connections[key][port] = []
		connections[key][port].append(connection)
	var events: Dictionary = {}
	var gates: Dictionary = {}
	var definitions: Dictionary = {}
	var specs: Dictionary = {}
	var edges: Array = []
	for child in panel.graph_edit.get_children():
		if not (child is GraphNode) or not child.has_meta("brick_data"): continue
		var data: Dictionary = child.get_meta("brick_data")
		var brick = data.brick_instance
		var id := str(child.name)
		var record: Dictionary = brick.serialize()
		var spec: Dictionary = brick.get_execution_spec()
		if str(data.brick_type) == "sensor":
			record.properties.erase("_execution_id")
			events[id] = record
		elif str(data.brick_type) == "controller" and (str(spec.get("kind")) == "action" or bool(record.properties.get("_legacy_condition_inputs",false))):
			record.properties.erase("_execution_id")
			gates[id] = record
		else:
			record.properties._execution_id = id
			definitions[id] = record
			spec._properties = record.properties
			specs[id] = spec
		for port in brick.get_exec_output_definitions().size():
			for endpoint in _destinations(panel, connections, id, port):
				edges.append({"from":id,"output":str(brick.get_exec_output_definitions()[port].id),"to":endpoint.to,"input":endpoint.input,"legacy_async":bool(record.properties.get("_legacy_async_fanout",false))})
	var done: Dictionary = {}
	var outgoing := _index_edges(edges)
	for id in events.keys() + gates.keys():
		if _cycle(str(id),outgoing,{},done): return _error("Execution cycle detected. Use structured For Loop/For Each with Break or Continue instead of back-wires.")
	for edge in edges:
		if gates.has(str(edge.to)) and definitions.has(str(edge.from)):
			return _error("Combine Conditions and Script Controller accept event/condition inputs. Use Branch for a condition in an action path.")
	var chains: Array = []
	for id in events:
		var entries := _entries(id,edges,definitions)
		if entries.is_empty() and str(events[id].type) != "FunctionEntry": continue
		chains.append({"name":"exec_"+str(id),"sensors":[events[id]],"controllers":[],"actuators":_reachable(entries,edges,definitions).values(),"execution_entries":entries})
	for id in gates:
		var tree := _tree(id,events,gates,edges)
		if tree.sensors.is_empty() and tree.controller_inputs.is_empty(): continue
		var sides: Array = [""]
		if str(gates[id].type) == "BranchController": sides = ["true","false"]
		if str(gates[id].type) == "CastToScriptController": sides = ["success","failure"]
		for side in sides:
			var selected: Array = edges.filter(func(edge): return side == "" or str(edge.output) == side)
			var entries := _entries(id,selected,definitions)
			var chain := {"name":"gate_"+str(id)+str(side),"sensors":tree.sensors,"controller_inputs":tree.controller_inputs,"controllers":[gates[id]],"actuators":_reachable(entries,edges,definitions).values(),"execution_entries":entries}
			if str(gates[id].type) == "BranchController": chain.branch_output = side
			if str(gates[id].type) == "CastToScriptController": chain.cast_output = side
			chains.append(chain)
	var used: Dictionary = {}
	for chain in chains:
		for entry in chain.execution_entries:
			var error := _scope_error(str(entry.to),str(entry.input),[],edges,specs,{})
			if not error.is_empty(): return _error(error)
		used.merge(_reachable(chain.execution_entries,edges,definitions),true)
	# Configuration errors are fatal only for reachable nodes; disconnected drafts
	# remain serializable in the editor's original graph metadata.
	for id in used:
		var brick = load(Registry.get_script_path(str(used[id].type))).new()
		brick.deserialize(used[id])
		if str(specs[id].get("kind")) not in ["action","branch","delay","once","for","foreach","sequence","switch","break","continue","function_call","function_return","set_local"]:
			return _error("%s declares an unsupported execution operation." % id)
		if str(specs[id].get("kind")) in ["for","foreach","sequence","switch"]:
			var warnings: Array = brick.get_configuration_warnings(panel.current_node)
			if not warnings.is_empty(): return _error("%s: %s" % [id,"; ".join(warnings)])
	var runtime_edges: Array = []
	for edge in edges:
		if used.has(str(edge.from)) and used.has(str(edge.to)): runtime_edges.append(edge)
	if not chains.is_empty(): chains[0].execution_graph = {"version":2,"nodes":used,"edges":runtime_edges}
	var signature_error := preload("res://addons/GDBlueprints/core/event_signature.gd").validate_chains(chains)
	if not signature_error.is_empty(): return _error(signature_error)
	var function_error: String = preload("res://addons/GDBlueprints/core/function_compiler.gd").validate(chains, panel.current_node, load("res://addons/GDBlueprints/core/gdblueprints_manager.gd").new())
	if not function_error.is_empty(): return _error(function_error)
	for chain in chains:
		for record in chain.get("sensors", []) + chain.get("actuators", []):
			if str(record.get("type", "")) in ["CustomEventSensor", "CallCustomEventActuator"] and not str(record.get("properties", {}).get("_applied_parameters", "")).strip_edges().is_empty():
				chains[0].execution_graph.version = maxi(int(chains[0].execution_graph.version), 3)
			if str(record.get("type", "")) in ["FunctionEntry", "CallGraphFunction", "FunctionReturn", "SetFunctionLocal"]:
				chains[0].execution_graph.version = 4
	return chains
