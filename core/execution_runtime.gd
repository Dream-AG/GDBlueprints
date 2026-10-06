extends RefCounted

## Per-activation state. Never stored in scene metadata or shared across owners.
const MAX_STEPS := 10000
const MAX_DEPTH := 128

static func context(epoch: int, meter: Dictionary = {}, event_arguments: Dictionary = {}) -> Dictionary:
	if meter.is_empty(): meter = {"steps":0,"depth":0,"exhausted":false}
	return {"epoch":epoch, "meter":meter, "cancelled":false, "loops":[], "values":{}, "event_arguments":event_arguments.duplicate(), "returned":false, "result":null, "function_name":"", "function_arguments":{}, "function_locals":{}, "function_local_types":{}, "function_return_type":"void"}

static func valid(owner: Node, flow: Dictionary) -> bool:
	return not flow.cancelled and not flow.meter.exhausted and is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() and int(flow.epoch) == int(owner.get("_gdb_execution_epoch"))

static func enter(owner: Node, flow: Dictionary, node_id: String) -> bool:
	if not valid(owner, flow): return false
	flow.meter.steps += 1
	if flow.meter.steps > MAX_STEPS or flow.meter.depth >= MAX_DEPTH:
		flow.cancelled = true
		flow.meter.exhausted = true
		flow.error = "GDBlueprints execution budget exceeded at %s; activation cancelled (steps=%s, depth=%s)." % [node_id, flow.meter.steps, flow.meter.depth]
		if bool(flow.get("report_errors", flow.meter.get("report_errors", true))): push_error(flow.error)
		return false
	flow.meter.depth += 1
	return true

static func stopped(owner: Node, flow: Dictionary) -> bool:
	if bool(flow.get("returned", false)) or not valid(owner, flow): return true
	return not flow.loops.is_empty() and str(flow.loops.back().control) != ""

static func control(flow: Dictionary, operation: String) -> void:
	if flow.loops.is_empty():
		flow.cancelled = true
		push_error("GDBlueprints: %s requires an active loop body." % operation)
	else:
		flow.loops.back().control = operation
