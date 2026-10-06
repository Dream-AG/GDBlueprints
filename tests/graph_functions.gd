extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")
const FunctionCompiler = preload("res://addons/GDBlueprints/core/function_compiler.gd")
const Signature = preload("res://addons/GDBlueprints/core/event_signature.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const SignatureEditor = preload("res://addons/GDBlueprints/ui/event_signature_editor.gd")

class Fixture:
	extends RefCounted
	var graph_edit := GraphEdit.new()
	var current_node := Node3D.new()
	func dispose() -> void:
		graph_edit.free()
		current_node.free()

var failures: Array[String] = []
var manager := Manager.new()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func add(f, id: String, type: String, props: Dictionary = {}) -> void:
	var brick = load(Registry.get_script_path(type)).new()
	brick.properties.merge(props, true)
	brick.properties._execution_id = id
	var node := GraphNode.new()
	node.name = id
	node.set_meta("brick_data", {"brick_instance":brick, "brick_class":type, "brick_type":Registry.get_brick_info(type).type})
	for index in 6:
		node.add_child(Label.new())
		node.set_slot(index, true, 0, Color.WHITE, true, 0, Color.WHITE)
	f.graph_edit.add_child(node)

func wire(f, from: String, to: String, output: int = 0) -> void:
	f.graph_edit.connect_node(from, output, to, 0)

func signature(name: String, params: String, returns: String, locals: String = "") -> Dictionary:
	return {"function_name":name,"parameters":params,"_applied_parameters":params,"return_type":returns,"_applied_return_type":Signature.return_type(returns),"locals":locals,"_applied_locals":locals}

func compile(f, extra_source: String = "") -> Node3D:
	var chains := Builder.build(f)
	if chains.is_empty() or chains[0].has("compile_error"):
		check(false, "Builder failed: " + str(chains))
		return null
	check(int(chains[0].execution_graph.version) == 4, "Function graph lacks format version 4")
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar hits: Array = []\nfunc record(value):\n\thits.append(value)\nfunc manual_double(value: int) -> int:\n\treturn value * 2\n" + extra_source + manager._generate_code_for_chains(f.current_node, chains)
	if script.reload() != OK:
		FileAccess.open("res://failed_functions.gd.txt", FileAccess.WRITE).store_string(script.source_code)
		check(false, "Function graph failed to parse")
		return null
	var owner := Node3D.new()
	owner.set_script(script)
	root.add_child(owner)
	owner.set_process(false)
	owner.set_physics_process(false)
	return owner

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	basic_functions()
	recursive_locals()
	loops_and_early_return()
	recursion_budget()
	rejections()
	await delayed_event_call()
	await editor_roundtrip()
	print("Graph function failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func basic_functions() -> void:
	var f := Fixture.new()
	add(f, "sum_entry", "FunctionEntry", signature("add_health", "amount: Int", "Int", "total: Int"))
	add(f, "store", "SetFunctionLocal", {"local_name":"total", "value":'_flow.function_arguments["add_health"]["amount"] + 10'})
	add(f, "return_sum", "FunctionReturn", {"value":'_flow.function_locals["add_health"]["total"]'})
	wire(f, "sum_entry", "store")
	wire(f, "store", "return_sum")
	add(f, "caller_entry", "FunctionEntry", signature("calculate", "amount: Int", "Int", "saved: Int"))
	add(f, "save", "SetFunctionLocal", {"local_name":"saved", "value":'_flow.function_arguments["calculate"]["amount"]'})
	var call_props := signature("add_health", "amount: Int", "Int")
	call_props.argument_amount = '_flow.function_locals["calculate"]["saved"]'
	add(f, "call", "CallGraphFunction", call_props)
	add(f, "return_call", "FunctionReturn", {"value":'_flow.values["call"]["result"] + _flow.function_locals["calculate"]["saved"]'})
	add(f, "failed", "FunctionReturn", {"value":"-1"})
	wire(f, "caller_entry", "save")
	wire(f, "save", "call")
	wire(f, "call", "return_call")
	wire(f, "call", "failed", 1)
	add(f, "empty", "FunctionEntry", signature("do_nothing", "", "void"))
	add(f, "list_entry", "FunctionEntry", signature("new_list", "", "Array", "items: Array"))
	add(f, "list_return", "FunctionReturn", {"value":'_flow.function_locals["new_list"]["items"]'})
	wire(f, "list_entry", "list_return")
	var owner := compile(f, "func handwritten_caller() -> int:\n\treturn calculate(5)\n")
	if owner != null:
		check(owner.call("handwritten_caller") == 20, "Static GDScript caller requires await or returns incorrectly")
		check(owner.call("add_health", 5) == 15, "Direct typed GDScript call returned wrong value")
		check(owner.call("calculate", 7) == 24, "Nested call lost caller locals or result")
		check(owner.call("calculate", 2) == 14, "Locals leaked between calls")
		owner.call("do_nothing")
		var first_list: Array = owner.call("new_list")
		first_list.append(1)
		check(owner.call("new_list").is_empty(), "Mutable local defaults are shared between calls")
		var function_runtime = load("res://addons/GDBlueprints/core/function_runtime.gd")
		var native_result: Dictionary = function_runtime.invoke(owner, "manual_double", [4], "int", {})
		check(native_result.ok and native_result.result == 8, "Handwritten synchronous function interoperability failed")
		var other := Node3D.new()
		other.set_script(owner.get_script())
		root.add_child(other)
		var meter := {"steps":0,"depth":0,"exhausted":false}
		var external: Dictionary = function_runtime.invoke(other, "calculate", [4], "int", meter)
		check(external.ok and external.result == 18 and meter.steps > 0 and meter.depth == 0, "Cross-node function call lost arguments or execution meter")
		other.free()
		owner.free()
	f.dispose()

func recursive_locals() -> void:
	var f := Fixture.new()
	add(f, "entry", "FunctionEntry", signature("factorial", "amount: Int", "Int", "saved: Int"))
	add(f, "store", "SetFunctionLocal", {"local_name":"saved", "value":'_flow.function_arguments["factorial"]["amount"]'})
	add(f, "branch", "BranchController", {"condition_expression":'_flow.function_locals["factorial"]["saved"] <= 1'})
	var call_props := signature("factorial", "amount: Int", "Int")
	call_props.argument_amount = '_flow.function_locals["factorial"]["saved"] - 1'
	add(f, "call", "CallGraphFunction", call_props)
	add(f, "base", "FunctionReturn", {"value":"1"})
	add(f, "multiply", "FunctionReturn", {"value":'_flow.values["call"]["result"] * _flow.function_locals["factorial"]["saved"]'})
	add(f, "failure", "FunctionReturn", {"value":"0"})
	wire(f, "entry", "store")
	wire(f, "store", "branch")
	wire(f, "branch", "base", 0)
	wire(f, "branch", "call", 1)
	wire(f, "call", "multiply")
	wire(f, "call", "failure", 1)
	var owner := compile(f)
	if owner != null:
		check(owner.call("factorial", 6) == 720, "Recursive function locals were overwritten")
		check(owner.call("factorial", 3) == 6, "Recursive results leaked between invocations")
		owner.free()
	f.dispose()

func loops_and_early_return() -> void:
	var f := Fixture.new()
	add(f, "entry", "FunctionEntry", signature("find_first", "", "Int"))
	add(f, "loop", "ForLoopExecution", {"first":0,"last":100,"step":1})
	add(f, "body_return", "FunctionReturn", {"value":"42"})
	add(f, "fallback", "FunctionReturn", {"value":"-1"})
	wire(f, "entry", "loop")
	wire(f, "loop", "body_return")
	wire(f, "loop", "fallback", 1)
	var owner := compile(f)
	if owner != null:
		check(owner.call("find_first") == 42, "Return failed to exit a loop")
		owner.free()
	f.dispose()

func recursion_budget() -> void:
	var f := Fixture.new()
	add(f, "entry", "FunctionEntry", signature("recurse", "", "Int"))
	add(f, "call", "CallGraphFunction", signature("recurse", "", "Int"))
	add(f, "success", "FunctionReturn", {"value":"1"})
	add(f, "failure", "FunctionReturn", {"value":"0"})
	wire(f, "entry", "call")
	wire(f, "call", "success")
	wire(f, "call", "failure", 1)
	var owner := compile(f)
	if owner != null:
		var meter := {"steps":0,"depth":0,"exhausted":false,"report_errors":false}
		var result: Dictionary = owner.call("_gdb_function_dispatch", "recurse", [], meter)
		check(not result.ok and meter.exhausted and meter.depth == 0, "Recursive calls escaped budget or leaked active depth")
		owner.free()
	f.dispose()

func rejections() -> void:
	var f := Fixture.new()
	add(f, "entry", "FunctionEntry", signature("bad", "", "Int"))
	add(f, "delay", "DelayExecution")
	add(f, "ret", "FunctionReturn", {"value":"1"})
	wire(f, "entry", "delay")
	wire(f, "delay", "ret")
	check(Builder.build(f)[0].has("compile_error"), "Latent function accepted")
	f.dispose()
	f = Fixture.new()
	add(f, "entry", "FunctionEntry", signature("bad", "", "void"))
	add(f, "store", "SetFunctionLocal", {"local_name":"missing"})
	wire(f, "entry", "store")
	check(Builder.build(f)[0].has("compile_error"), "Undeclared local accepted")
	f.dispose()

func delayed_event_call() -> void:
	var f := Fixture.new()
	add(f, "function", "FunctionEntry", signature("double_value", "amount: Int", "Int"))
	add(f, "return", "FunctionReturn", {"value":'_flow.function_arguments["double_value"]["amount"] * 2'})
	wire(f, "function", "return")
	add(f, "event", "CustomEventSensor", {"event_name":"run"})
	add(f, "delay", "DelayExecution", {"duration":0.02})
	var props := signature("double_value", "amount: Int", "Int")
	props.argument_amount = "9"
	add(f, "call", "CallGraphFunction", props)
	add(f, "record", "CallObjectMethodActuator", {"method_name":"record", "arguments":'[_flow.values["call"]["result"]]'})
	wire(f, "event", "delay")
	wire(f, "delay", "call")
	wire(f, "call", "record")
	var owner := compile(f)
	if owner != null:
		owner.call("run")
		var deadline := Time.get_ticks_msec() + 2000
		while owner.hits.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		check(owner.hits == [18], "Function call after Delay lost its Result")
		owner.free()
	f.dispose()
	f = Fixture.new()
	add(f, "entry", "FunctionEntry", signature("bad", "", "Int"))
	check(Builder.build(f)[0].has("compile_error"), "Non-void function without Return accepted")
	f.dispose()
	f = Fixture.new()
	add(f, "entry", "CustomEventSensor")
	add(f, "ret", "FunctionReturn")
	wire(f, "entry", "ret")
	check(Builder.build(f)[0].has("compile_error"), "Return outside a function accepted")
	f.dispose()
	f = Fixture.new()
	add(f, "entry", "FunctionEntry", signature("bad", "", "Int"))
	add(f, "ret", "FunctionReturn", {"value":'_flow.values["not_called"]["result"]'})
	wire(f, "entry", "ret")
	check(Builder.build(f)[0].has("compile_error"), "Result before call accepted")
	f.dispose()

func editor_roundtrip() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = target
	var visual = panel._create_graph_node("sensor", "FunctionEntry", Vector2.ZERO)
	var id := str(visual.name)
	var brick = visual.get_meta("brick_data").brick_instance
	brick.properties.merge({"parameters":"amount: Int", "return_type":"Int", "locals":"total: Int"}, true)
	check(SignatureEditor.apply(panel, visual).is_empty(), "Function signature application failed")
	await process_frame
	await process_frame
	await process_frame
	visual = panel.graph_edit.get_node(NodePath(id))
	check(panel._get_value_output_info(visual, 1).get("name") == "amount", "Function parameter output missing")
	check(panel._get_value_output_info(visual, 2).get("name") == "Local: total", "Function local output missing")
	check(int(target.get_meta("blueprints_for_godot_graph").execution_version) == 4, "Editor omitted function version guard")
	var call = panel._create_graph_node("actuator", "CallGraphFunction", Vector2(400, 0))
	var call_id := str(call.name)
	check(SignatureEditor.use_local_definition(panel, call).is_empty(), "Local function signature copy failed")
	await process_frame
	await process_frame
	await process_frame
	call = panel.graph_edit.get_node(NodePath(call_id))
	check(Signature.Pins.normalize(str(panel._get_value_output_info(call, 2).get("type"))) == "Int", "Call Result did not get the declared return type")
	check(str(panel._get_value_output_info(call, 2).get("expression", "")).contains(call_id), "Call Result lost its stable graph ID")
	var store = panel._create_graph_node("actuator", "SetFunctionLocal", Vector2(250, 150))
	var returned = panel._create_graph_node("actuator", "FunctionReturn", Vector2(650, 150))
	store.get_meta("brick_data").brick_instance.properties.local_name = "total"
	panel._find_property_control(store, "local_name").text = "total"
	panel.graph_edit.connect_node(id, 0, store.name, 0)
	panel.graph_edit.connect_node(store.name, 0, returned.name, 0)
	panel.graph_edit.connect_node(id, 1, store.name, 1)
	panel.graph_edit.connect_node(id, 2, returned.name, 1)
	panel._sync_value_bindings_from_connections()
	panel._save_graph_to_metadata("Function tutorial fixture", false)
	var saved: Dictionary = target.get_meta("blueprints_for_godot_graph").duplicate(true)
	var scene := PackedScene.new()
	check(scene.pack(target) == OK, "Packing function scene failed")
	check(ResourceSaver.save(scene, "res://graph_functions_fixture.tscn") == OK, "Saving function scene failed")
	var restored = load("res://graph_functions_fixture.tscn").instantiate()
	check(restored.get_meta("blueprints_for_godot_graph") == saved, "Function declarations changed on disk reload")
	restored.free()
	await panel._load_graph_from_metadata()
	check(target.get_meta("blueprints_for_godot_graph") == saved, "Function metadata changed on reload")
	var owner := compile(panel)
	if owner != null:
		check(owner.call("my_function", 11) == 11, "Editor-authored function wiring did not compile to working GDScript")
		owner.free()
	panel.free()
	target.free()
