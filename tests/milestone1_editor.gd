extends SceneTree

const PanelScript = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const Builder = preload("res://addons/GDBlueprints/ui/execution_graph_builder.gd")

var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var panel := PanelScript.new()
	root.add_child(panel)
	panel.current_node = target
	var event = panel._create_graph_node("sensor","CustomEventSensor",Vector2.ZERO)
	var loop = panel._create_graph_node("actuator","ForLoopExecution",Vector2(250,0))
	var action = panel._create_graph_node("actuator","PrintStringActuator",Vector2(550,0))
	var stop = panel._create_graph_node("actuator","BreakExecution",Vector2(800,0))
	var delay = panel._create_graph_node("actuator","DelayExecution",Vector2(300,400))
	await process_frame
	check(loop.get_meta("exec_output_ports").size() == 2,"Loop Body/Completed UI outputs missing")
	check(stop.get_meta("exec_output_ports").is_empty() and not stop.is_slot_enabled_right(0),"Break has a phantom Then output")
	check(delay.get_meta("exec_input_ports").get(1) == "cancel","Delay Cancel input missing")
	var output: Dictionary = panel._get_value_output_info(loop,2)
	check(str(output.get("expression", "")).contains(str(loop.name)),"Loop Index binding does not use its stable graph ID")
	panel.graph_edit.connect_node(event.name,0,loop.name,0)
	panel.graph_edit.connect_node(loop.name,0,action.name,0)
	panel.graph_edit.connect_node(action.name,0,stop.name,0)
	panel._save_graph_to_metadata("Test save",false)
	var saved: Dictionary = target.get_meta("blueprints_for_godot_graph").duplicate(true)
	check(int(saved.execution_version) == 2,"Execution format version was not saved")
	var before := Builder.build(panel)
	await panel._load_graph_from_metadata()
	await process_frame
	var after := Builder.build(panel)
	check(var_to_str(before) == var_to_str(after),"Execution graph changed after editor save/reload")
	check(saved.connections.size() == 3,"Saved graph lost connections")
	panel.free()
	target.free()
	print("Milestone 1 editor failures: %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
