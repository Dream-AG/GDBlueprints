extends SceneTree
const Compiler = preload("res://addons/GDBlueprints/core/execution_graph_compiler.gd")
var failures: Array[String] = []
class Definition extends RefCounted:
	func get_execution_spec() -> Dictionary: return {"kind":"action"}
	func get_debug_code() -> String: return ""
class CountingManager extends RefCounted:
	var generations := 0
	func _instantiate_brick(_data): return Definition.new()
	func _generate_brick_with_bindings(_brick, _target, _name):
		generations += 1
		return {"actuator_code":"pass"}
func _initialize() -> void:
	var manager := CountingManager.new()
	var target := Node.new()
	var graph := {"nodes":{}, "edges":[]}
	for index in 200:
		graph.nodes[str(index)] = {}
		if index > 0: graph.edges.append({"from":str(index-1), "to":str(index), "output":"then", "input":"in"})
	var code := Compiler.compile(graph, manager, target)
	if manager.generations != 200: failures.append("Compiler generated an action more than once")
	var script := GDScript.new()
	script.source_code = "extends Node\n" + code
	if script.reload() != OK: failures.append("Indexed compiler output did not parse")
	var reachable := Compiler._output_nodes(graph.edges, "0", ["then"])
	if reachable.size() != 199: failures.append("Indexed traversal lost reachable nodes")
	graph.edges.append({"from":"199", "to":"0", "output":"then", "input":"reset"})
	if Compiler._output_nodes(graph.edges, "0", ["then"]).size() != 199: failures.append("Reset edge changed inactive reachability")
	target.free()
	print("Compiler maintenance failures: ", failures)
	quit(0 if failures.is_empty() else 1)
