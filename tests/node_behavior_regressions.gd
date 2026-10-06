extends SceneTree

const TabAction = preload("res://addons/GDBlueprints/bricks/actuators/ui/tab_actuator.gd")
const Transforms = preload("res://addons/GDBlueprints/bricks/actuators/common/get_transforms_actuator.gd")
const SendMessage = preload("res://addons/GDBlueprints/bricks/actuators/common/message_actuator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func action_script(action, node: Node) -> GDScript:
	var generated: Dictionary = action.generate_code(node, "behavior")
	var code := "extends %s\n" % node.get_class()
	for member in generated.get("member_vars", []): code += str(member) + "\n"
	code += "func execute():\n"
	for line in str(generated.get("actuator_code", "pass")).split("\n"): code += "\t" + line + "\n"
	var script := GDScript.new()
	script.source_code = code
	check(script.reload() == OK, "Generated behavior script failed to parse")
	return script

func _run() -> void:
	for mode in ["next", "previous"]:
		var action := TabAction.new()
		action.properties.action = mode
		var tabs := TabContainer.new()
		tabs.set_script(action_script(action, tabs))
		root.add_child(tabs)
		for i in 3:
			var page := Control.new()
			page.name = "Page%d" % i
			tabs.add_child(page)
		tabs.current_tab = 2 if mode == "next" else 0
		tabs.call("execute")
		check(tabs.current_tab == (0 if mode == "next" else 2), "Tab did not wrap: " + mode)
		tabs.free()
	for dimension in [2, 3]:
		var owner: Node = Node2D.new() if dimension == 2 else Node3D.new()
		var near: Node = Node2D.new() if dimension == 2 else Node3D.new()
		var far: Node = Node2D.new() if dimension == 2 else Node3D.new()
		var action := Transforms.new()
		action.properties.merge({"target_mode":"group", "target_name":"audit_targets", "position_variable":"result"}, true)
		owner.set_script(action_script(action, owner))
		root.add_child(owner)
		root.add_child(near)
		root.add_child(far)
		near.set("position", Vector2(2, 0) if dimension == 2 else Vector3(2, 0, 0))
		far.set("position", Vector2(9, 0) if dimension == 2 else Vector3(9, 0, 0))
		near.add_to_group("audit_targets")
		far.add_to_group("audit_targets")
		owner.call("execute")
		check(owner.get("result") == near.get("global_position"), "Get Transforms did not choose the nearest %dD group member" % dimension)
		owner.free()
		near.free()
		far.free()
	var receiver := Node.new()
	var receiver_script := GDScript.new()
	receiver_script.source_code = "extends Node\nvar received: Array = []\nfunc _on_message_received(subject, body, _sender):\n\treceived = [subject, body]\n"
	check(receiver_script.reload() == OK, "Receiver fixture failed")
	receiver.set_script(receiver_script)
	root.add_child(receiver)
	receiver.add_to_group("_blueprints_for_godot_message_listeners")
	var sender := Node.new()
	var message := SendMessage.new()
	message.properties.subject = "quoted \"subject\""
	message.properties.body = "first\nsecond\\third"
	sender.set_script(action_script(message, sender))
	root.add_child(sender)
	sender.call("execute")
	check(receiver.get("received") == [message.properties.subject, message.properties.body], "Message literals changed during generation")
	sender.free()
	receiver.free()
	print("Node behavior regressions: %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
