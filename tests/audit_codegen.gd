extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager := Manager.new()
	var failed: Array = []
	var checked := 0
	for info in Registry.get_registered_bricks():
		var brick = load(info.script_path).new()
		var target: Node
		match str(info.domain):
			"ui": target = Control.new()
			"2d": target = CharacterBody2D.new()
			_: target = CharacterBody3D.new()
		if brick.has_method("get_compatibility_error") and not str(brick.get_compatibility_error(target)).is_empty():
			target.free()
			target = RigidBody2D.new() if str(info.domain) == "2d" else RigidBody3D.new()
			if not str(brick.get_compatibility_error(target)).is_empty():
				target.free()
				continue
		root.add_child(target)
		if brick.has_method("apply_context_defaults"):
			brick.apply_context_defaults(target)
		var warnings: Array = brick.get_configuration_warnings(target)
		if not warnings.is_empty():
			target.free()
			continue
		var chain := {"name":"audit", "sensors":[], "controllers":[], "actuators":[]}
		match str(info.type):
			"sensor":
				chain.sensors.append(brick.serialize())
				chain.actuators.append({"type":"PrintStringActuator", "properties":{"text":"audit"}})
			"actuator":
				chain.sensors.append({"type":"AlwaysSensor", "properties":{}})
				chain.actuators.append(brick.serialize())
			"controller":
				chain.sensors.append({"type":"AlwaysSensor", "properties":{}})
				chain.controllers.append(brick.serialize())
				chain.actuators.append({"type":"PrintStringActuator", "properties":{"text":"audit"}})
			_:
				target.free()
				continue
		var code := "extends %s\n" % target.get_class() + manager._generate_code_for_chains(target, [chain])
		var script := GDScript.new()
		script.source_code = code
		checked += 1
		if script.reload() != OK:
			failed.append(info["class"])
			var file := FileAccess.open("user://audit_%s.gd.txt" % info["class"], FileAccess.WRITE)
			if file: file.store_string(code)
		target.free()
	print("Codegen audit: %d defaults checked; failed: %s" % [checked, str(failed)])
	quit(0 if failed.is_empty() else 1)
