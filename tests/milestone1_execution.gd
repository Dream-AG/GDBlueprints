extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
const Runtime = preload("res://addons/GDBlueprints/core/execution_runtime.gd")

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

func add(f, id: String, type: String, properties: Dictionary = {}) -> void:
	var brick = load(Registry.get_script_path(type)).new()
	brick.properties.merge(properties,true)
	brick.properties._execution_id = id
	var visual := GraphNode.new()
	visual.name = id
	visual.set_meta("brick_data", {"brick_instance":brick,"brick_class":type,"brick_type":Registry.get_brick_info(type).type})
	for index in 6:
		visual.add_child(Label.new())
		visual.set_slot(index,true,0,Color.WHITE,true,0,Color.WHITE)
	f.graph_edit.add_child(visual)

func wire(f, from: String, to: String, output: int = 0, input: int = 0) -> void:
	f.graph_edit.connect_node(from,output,to,input)

func record(f, id: String, expression: String) -> void:
	add(f,id,"CallObjectMethodActuator",{"method_name":"record","arguments":"["+expression+"]"})

func compile(f, chains: Array = []) -> Node3D:
	if chains.is_empty(): chains = Builder.build(f)
	if chains.is_empty() or chains[0].has("compile_error"):
		check(false,"Builder: "+str(chains))
		return null
	var source := "extends Node3D\nvar hits: Array = []\nvar items = [10,20,30]\nvar enabled = false\nfunc record(value):\n\thits.append(value)\nfunc mutate(value):\n\thits.append(value)\n\titems.clear()\n" + manager._generate_code_for_chains(f.current_node,chains)
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		check(false,"Generated script failed to parse")
		FileAccess.open("res://failed_milestone1.txt",FileAccess.WRITE).store_string(source)
		return null
	var owner := Node3D.new()
	owner.set_script(script)
	root.add_child(owner)
	owner.set_process(false)
	owner.set_physics_process(false)
	return owner

func _initialize() -> void:
	_run.call_deferred()

func wait_for(owner: Node, value: Variant) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		if not owner.hits.is_empty() and typeof(owner.hits.back()) == typeof(value) and owner.hits.back() == value: return
		await process_frame

func _run() -> void:
	await structured_flow()
	await nested_and_collections()
	array_snapshot_and_default()
	await cancellation()
	await compatibility()
	await fanout_compatibility()
	legacy_conditions_and_inactive()
	budgets_and_migration()
	validation()
	print("Milestone 1 runtime failures: %s" % str(failures))
	quit(0 if failures.is_empty() else 1)

func structured_flow() -> void:
	var f := Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"seq","SequenceExecution")
	add(f,"loop","ForLoopExecution",{"last":4})
	add(f,"skip","BranchController",{"condition_expression":'_flow.values["loop"].index == 1'})
	add(f,"stop","BranchController",{"condition_expression":'_flow.values["loop"].index == 3'})
	add(f,"continue","ContinueExecution")
	add(f,"break","BreakExecution")
	add(f,"delay","DelayExecution",{"duration":0.002})
	add(f,"switch","SwitchIntExecution",{"selection":2})
	add(f,"string","SwitchStringExecution",{"selection":"quoted\"\ntext","case_1":"quoted\"\ntext"})
	record(f,"start",'"start"')
	record(f,"body",'_flow.values["loop"].index')
	record(f,"done",'"done"')
	record(f,"intcase",'"int"')
	record(f,"strcase",'"string"')
	wire(f,"event","seq")
	wire(f,"seq","start",0)
	wire(f,"seq","loop",1)
	wire(f,"seq","switch",2)
	wire(f,"seq","string",3)
	wire(f,"loop","skip")
	wire(f,"loop","done",1)
	wire(f,"skip","continue",0)
	wire(f,"skip","stop",1)
	wire(f,"stop","break",0)
	wire(f,"stop","delay",1)
	wire(f,"delay","body")
	wire(f,"switch","intcase",2)
	wire(f,"string","strcase",1)
	var chains := Builder.build(f)
	var before := var_to_str(chains)
	var owner := compile(f,chains)
	check(var_to_str(chains) == before,"Compilation mutated saved chains")
	if owner != null:
		owner.call("run_graph")
		check(owner.hits == ["start"],"Sequence did not await its delayed loop")
		await wait_for(owner,"string")
		check(owner.hits == ["start",0,2,"done","int","string"],"Sequence/Delay/Continue/Break/switch order: "+str(owner.hits))
		owner.free()
	# Disk round trip of the saved execution representation, including port IDs.
	f.current_node.set_meta(Manager.METADATA_KEY,chains)
	var packed := PackedScene.new()
	check(packed.pack(f.current_node) == OK,"Could not pack saved graph")
	check(ResourceSaver.save(packed,"res://milestone1_saved.tscn") == OK,"Could not save graph fixture")
	var saved = load("res://milestone1_saved.tscn").instantiate()
	var reopened := manager.get_chains(saved)
	check(var_to_str(reopened) == before,"Saved graph execution metadata changed on reopen")
	saved.free()
	var reopened_owner := compile(f,reopened)
	if reopened_owner != null:
		reopened_owner.call("run_graph")
		await wait_for(reopened_owner,"string")
		check(reopened_owner.hits == ["start",0,2,"done","int","string"],"Reopened graph behavior changed")
		reopened_owner.free()
	f.dispose()

func nested_and_collections() -> void:
	var f := Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"outer","ForLoopExecution",{"first":2,"last":0,"step":-1})
	add(f,"inner","ForEachExecution",{"items":"items"})
	add(f,"break","BreakExecution")
	record(f,"body",'[_flow.values["outer"].index,_flow.values["inner"].item]')
	record(f,"innerdone",'"inner_done"')
	record(f,"done",'"all_done"')
	wire(f,"event","outer")
	wire(f,"outer","inner")
	wire(f,"outer","done",1)
	wire(f,"inner","body")
	wire(f,"body","break")
	wire(f,"inner","innerdone",1)
	var owner := compile(f)
	if owner != null:
		owner.call("run_graph")
		check(owner.hits == [[2,10],"inner_done",[1,10],"inner_done",[0,10],"inner_done","all_done"],"Nested Break did not target innermost loop: "+str(owner.hits))
		owner.items = []
		owner.hits = []
		owner.call("run_graph")
		check(owner.hits == ["inner_done","inner_done","inner_done","all_done"],"Empty For Each did not complete")
		owner.free()
	f.dispose()

func cancellation() -> void:
	var f := Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"cancel","CustomEventSensor",{"event_name":"cancel_wait"})
	add(f,"delay","DelayExecution",{"duration":0.025})
	record(f,"done",'"done"')
	wire(f,"event","delay")
	wire(f,"cancel","delay",0,1)
	wire(f,"delay","done")
	f.current_node.set_meta("blueprints_for_godot_states",[{"id":"a","name":"A"},{"id":"b","name":"B"}])
	var owner := compile(f)
	if owner != null:
		owner.call("run_graph")
		owner.call("cancel_wait")
		await create_timer(0.06).timeout
		check(owner.hits.is_empty(),"Cancel resumed a delayed path")
		owner.call("run_graph")
		root.remove_child(owner)
		root.add_child(owner)
		await create_timer(0.06).timeout
		check(owner.hits.is_empty(),"Removed/readded owner resumed stale work")
		owner.call("run_graph")
		owner.call("_blueprint_set_state","b")
		owner.call("_blueprint_set_state","a")
		await create_timer(0.06).timeout
		check(owner.hits.is_empty(),"State round trip resumed stale work")
		owner.call("run_graph")
		await create_timer(0.06).timeout
		check(owner.hits == ["done"],"Cancellation prevented a fresh activation")
		owner.free()
	f.dispose()

func array_snapshot_and_default() -> void:
	var f := Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"each","ForEachExecution",{"items":"items"})
	add(f,"mutate","CallObjectMethodActuator",{"method_name":"mutate","arguments":'[_flow.values["each"].item]'})
	add(f,"empty","ForLoopExecution",{"first":5,"last":1,"step":1})
	add(f,"switch","SwitchIntExecution",{"selection":99})
	record(f,"bad",'"must_not_run"')
	record(f,"done",'"default"')
	wire(f,"event","each")
	wire(f,"each","mutate")
	wire(f,"each","empty",1)
	wire(f,"empty","bad",0)
	wire(f,"empty","switch",1)
	wire(f,"switch","done",4)
	var owner := compile(f)
	if owner != null:
		owner.call("run_graph")
		check(owner.hits == [10,20,30,"default"] and owner.items.is_empty(),"Array snapshot, empty range, or Default routing failed")
		owner.free()
	f.dispose()

func compatibility() -> void:
	var f := Fixture.new()
	add(f,"always","AlwaysSensor")
	add(f,"gate","Controller",{"logic_mode":"and"})
	record(f,"a","1")
	record(f,"b","2")
	wire(f,"always","gate")
	wire(f,"gate","a")
	wire(f,"a","b")
	var owner := compile(f)
	if owner != null:
		owner.call("_blueprint_gate_gate",0.1)
		check(owner.hits == [1,2],"Legacy condition graph lost action ordering")
		owner.free()
	var old: Array = [{"name":"old_chain","sensors":[{"type":"AlwaysSensor","properties":{}}],"controllers":[],"actuators":[{"type":"CallObjectMethodActuator","properties":{"method_name":"record","arguments":"[3]"}},{"type":"CallObjectMethodActuator","properties":{"method_name":"record","arguments":"[4]"}}]}]
	var original := var_to_str(old)
	owner = compile(f,old)
	if owner != null:
		owner.call("_blueprint_old_chain",0.1)
		check(owner.hits == [3,4],"Chain-only save changed behavior")
		check(var_to_str(old) == original,"Legacy migration modified source metadata")
		owner.free()
	f.dispose()

func fanout_compatibility() -> void:
	for old_format in [false,true]:
		var f := Fixture.new()
		add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
		add(f,"delay","DelayExecution",{"duration":0.01})
		record(f,"first",'"first"')
		record(f,"delayed",'"delayed"')
		record(f,"tail",'"tail"')
		wire(f,"event","first")
		wire(f,"first","delay")
		wire(f,"first","tail")
		wire(f,"delay","delayed")
		var chains := Builder.build(f)
		if old_format: chains[0].execution_graph.erase("version")
		var owner := compile(f,chains)
		if owner != null:
			owner.call("run_graph")
			check(owner.hits == (["first","tail"] if old_format else ["first"]),"Fan-out did not preserve its execution format")
			await wait_for(owner,"delayed" if old_format else "tail")
			check(owner.hits == (["first","tail","delayed"] if old_format else ["first","delayed","tail"]),"Fan-out order changed")
			owner.free()
		f.dispose()

func validation() -> void:
	var f := Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"break","BreakExecution")
	wire(f,"event","break")
	check(Builder.build(f)[0].has("compile_error"),"Break outside a loop was accepted")
	f.dispose()
	f = Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"loop","ForLoopExecution")
	record(f,"outside",'_flow.values.get("loop",{}).get("index",0)')
	wire(f,"event","loop")
	wire(f,"loop","outside",1)
	check(Builder.build(f)[0].has("compile_error"),"Loop data escaped Body scope")
	f.dispose()
	f = Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"switch","SwitchIntExecution",{"case_1":0})
	wire(f,"event","switch")
	check(Builder.build(f)[0].has("compile_error"),"Duplicate switch cases were accepted")
	f.dispose()

func legacy_conditions_and_inactive() -> void:
	var f := Fixture.new()
	add(f,"always","AlwaysSensor")
	add(f,"flag","VariableSensor",{"variable_name":"enabled","value":"true"})
	add(f,"branch","BranchController",{"_legacy_condition_inputs":true})
	record(f,"yes","1")
	record(f,"no","2")
	wire(f,"always","branch")
	wire(f,"flag","branch")
	wire(f,"branch","yes",0)
	wire(f,"branch","no",1)
	var owner := compile(f)
	if owner != null:
		owner.call("_blueprint_gate_branchtrue",0.1)
		owner.call("_blueprint_gate_branchfalse",0.1)
		check(owner.hits.is_empty(),"Old Branch lost AND input semantics")
		owner.enabled = true
		owner.call("_blueprint_gate_branchtrue",0.1)
		owner.call("_blueprint_gate_branchfalse",0.1)
		check(owner.hits == [1],"Old Branch selected the wrong output")
		owner.free()
	f.dispose()
	# Register this test-only definition without installing a project extension.
	Registry._bricks_by_class["TestInactiveAction"] = {"class":"TestInactiveAction","type":"actuator","script_path":"res://addons/GDBlueprints/tests/fixtures/inactive_action.gd"}
	f = Fixture.new()
	add(f,"event","AlwaysSensor")
	add(f,"branch","BranchController",{"condition_expression":"enabled"})
	add(f,"action","TestInactiveAction")
	wire(f,"event","branch")
	wire(f,"branch","action",0)
	owner = compile(f)
	if owner != null:
		owner.call("_blueprint_exec_event",0.1)
		owner.enabled = true
		owner.call("_blueprint_exec_event",0.1)
		owner.enabled = false
		owner.call("_blueprint_exec_event",0.1)
		check(owner.hits == ["inactive","active","inactive"],"Continuous inactive updates were dropped")
		owner.free()
	f.dispose()
	Registry._bricks_by_class.erase("TestInactiveAction")

func budgets_and_migration() -> void:
	var f := Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"loop","ForLoopExecution",{"last":1000000000})
	record(f,"done",'"must_not_complete"')
	wire(f,"event","loop")
	wire(f,"loop","done",1)
	var owner := compile(f)
	if owner != null:
		var flow := Runtime.context(owner.get("_gdb_execution_epoch"))
		flow.report_errors = false
		owner.call("_gdb_exec_"+"loop".to_utf8_buffer().hex_encode(),"in",0.0,flow)
		check(flow.cancelled and flow.meter.steps > Runtime.MAX_STEPS,"Runaway loop did not exhaust its budget")
		check(owner.hits.is_empty(),"Budget cancellation incorrectly ran Completed")
		owner.free()
	f.dispose()
	f = Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"recurse","CallObjectMethodActuator",{"method_name":"run_graph","arguments":"[]"})
	wire(f,"event","recurse")
	owner = compile(f)
	if owner != null:
		var meter := {"steps":0,"depth":0,"exhausted":false,"report_errors":false}
		owner.set("_gdb_dispatch_meter",meter)
		owner.call("run_graph")
		check(meter.exhausted and meter.depth == 0,"Recursive custom events bypassed budget or failed to unwind")
		owner.free()
	f.dispose()
	var old := {"schema_version":2,"nodes":[{"id":"branch","brick_class":"BranchController","properties":{"condition":true}}],"connections":[]}
	var original := var_to_str(old)
	var migrated := Builder.migrate_graph(old)
	check(bool(migrated.nodes[0].properties.get("_legacy_condition_inputs",false)),"Old Branch condition semantics were not marked for preservation")
	check(var_to_str(old) == original,"Migration modified original saved graph")
	check(Builder.migrate_graph(migrated) == migrated,"Graph migration is not idempotent")
	var native := Builder.migrate_graph(old,[{"execution_graph":{"nodes":{},"edges":[]}}])
	check(not native.nodes[0].properties.has("_legacy_condition_inputs"),"Existing explicit-edge graph became a legacy condition graph")
	f = Fixture.new()
	add(f,"event","CustomEventSensor",{"event_name":"run_graph"})
	add(f,"loop","ForLoopExecution",{"step":0})
	wire(f,"event","loop")
	check(Builder.build(f)[0].has("compile_error"),"Zero-step loop accepted")
	f.graph_edit.get_node("loop").get_meta("brick_data").brick_instance.properties.step = 1
	wire(f,"loop","loop")
	check(Builder.build(f)[0].has("compile_error"),"Back-wire loop accepted")
	f.dispose()
