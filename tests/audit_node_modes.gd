extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
var report: Array = []
var failed := 0
var checked := 0
const FIXTURE_ROOT := "res://addons/GDBlueprints/tests/fixtures/"
const CONFIGURED := {
	"Audio2DActuator": {"sound_file":FIXTURE_ROOT + "audit_audio.tres"},
	"UIAudio2DActuator": {"sound_file":FIXTURE_ROOT + "audit_audio.tres"},
	"SoundActuator": {"sound_file":FIXTURE_ROOT + "audit_audio.tres"},
	"ActuatorSensor": {"actuator_name":"audit"},
	"AnimationActuator": {"animation_name":"idle"},
	"AnimationTreeSensor": {"state_name":"idle", "condition_name":"active", "parameter_path":"parameters/blend_amount"},
	"CastToScriptController": {"script_path":FIXTURE_ROOT + "audit_behavior.gd"},
	"ScriptController": {"script_path":FIXTURE_ROOT + "audit_behavior.gd"},
	"Collision2DSensor": {"area_node_name":"Area2D"},
	"CollisionSensor": {"area_node_name":"Area3D"},
	"CollisionActuator": {"target_node_name":"CollisionShape3D"},
	"ForceActuator": {"x":"1.0"},
	"GetTransformsActuator": {"target_name":"self", "position_variable":"audit_position", "rotation_variable":"audit_rotation", "scale_variable":"audit_scale"},
	"GetVariableActuator": {"source_node_name":"self", "variable_name":"audit_value", "store_as":"audit_result"},
	"Impulse2DActuator": {"x":"1.0"},
	"ImpulseActuator": {"x":"1.0"},
	"LinearVelocity2DActuator": {"x":"1.0"},
	"LinearVelocityActuator": {"velocity_x":"1.0"},
	"LookAtInputActuator": {"forward_action":"ui_up", "backward_action":"ui_down"},
	"MessageActuator": {"subject":"audit\"quoted", "body":"line one\nline two"},
	"UIMessageSensor": {"subject":"audit\"quoted"},
	"ModulateActuator": {"target_node_name":"Target"},
	"UIModulateActuator": {"target_node_name":"Target"},
	"MusicActuator": {"tracks":[FIXTURE_ROOT + "audit_audio.tres"]},
	"OpenLevelActuator": {"scene_path":FIXTURE_ROOT + "audit_scene.tscn"},
	"PreloadActuator": {"resources":[FIXTURE_ROOT + "audit_audio.tres"]},
	"Position2DActuator": {"x":"1.0"},
	"PositionActuator": {"x":"1.0"},
	"RandomActuator": {"variable_name":"audit_value"},
	"RotateTowards2DActuator": {"target_name":"Target"},
	"RotateTowardsActuator": {"target_name":"Target"},
	"Rotation2DActuator": {"degrees":"1.0"},
	"RotationActuator": {"x":"1.0"},
	"StateActuator": {"state_id":"audit"},
	"TorqueActuator": {"x":"1.0"},
	"VariableActuator": {"variable_name":"audit_value", "source_variable":"audit_result", "value":"1"},
	"VariableSensor": {"variable_name":"audit_value", "value":"1", "min_value":"0", "max_value":"2"},
	"UIVariableSensor": {"variable_name":"audit_value", "value":"1", "min_value":"0", "max_value":"2"},
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager := Manager.new()
	for info in Registry.get_registered_bricks():
		var definition = load(info.script_path).new()
		var cases: Array = [{"case": "defaults", "values": {}}]
		if CONFIGURED.has(info["class"]): cases.append({"case":"configured", "values":CONFIGURED[info["class"]]})
		for property in definition.get_property_definitions():
			if property.get("type") == TYPE_BOOL:
				cases.append({"case": str(property.name) + "=toggled", "values": {str(property.name): not bool(definition.properties.get(property.name, false))}})
			if property.get("hint", -1) == PROPERTY_HINT_ENUM and property.get("type") == TYPE_INT:
				var choices := str(property.get("hint_string", "")).split(",", false)
				for index in choices.size():
					var pieces := choices[index].split(":")
					var value := int(pieces[1]) if pieces.size() > 1 else index
					cases.append({"case": str(property.name) + "=" + choices[index], "values": {str(property.name): value}})
			if property.get("hint", -1) == PROPERTY_HINT_ENUM and property.get("type") == TYPE_STRING:
				var choices := str(property.get("hint_string", ""))
				if choices.begins_with("__"): continue
				for choice in choices.split(",", false):
					cases.append({"case": str(property.name) + "=" + choice, "values": {str(property.name): choice.to_lower().replace(" ", "_")}})
		for sample in cases:
			var brick = load(info.script_path).new()
			if sample.case != "defaults": brick.properties.merge(CONFIGURED.get(info["class"], {}), true)
			brick.properties.merge(sample.values, true)
			var target: Node = null
			var candidates := ["CharacterBody2D", "RigidBody2D", "Node2D"] if info.domain == "2d" else ["Control"] if info.domain == "ui" else ["CharacterBody3D", "RigidBody3D", "Node3D"]
			for candidate in candidates:
				target = ClassDB.instantiate(candidate)
				if not brick.has_method("get_compatibility_error") or brick.get_compatibility_error(target).is_empty(): break
				target.free()
				target = null
			if target == null:
				report.append({"id": info["class"], "case": sample.case, "status": "needs scene fixture"})
				continue
			root.add_child(target)
			var companions: Array = []
			if info["class"] == "MusicActuator" and brick.properties.get("music_mode") != "tracks":
				companions.append({"name":"music_setup", "sensors":[{"type":"AlwaysSensor", "properties":{}}], "controllers":[], "actuators":[{"type":"MusicActuator", "properties":CONFIGURED.MusicActuator}]})
			target.set_meta("blueprints_for_godot", companions)
			if brick.has_method("apply_context_defaults"): brick.apply_context_defaults(target)
			var warnings: Array = brick.get_configuration_warnings(target)
			if not warnings.is_empty():
				report.append({"id": info["class"], "case": sample.case, "status": "needs configuration", "details": warnings})
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
			var code := "extends %s\nvar audit_value = 0\nvar Target = \"Target\"\n" % target.get_class()
			if info["class"] != "GetVariableActuator": code += "var audit_result = 0\n"
			if info.type == "value":
				code += "func _audit_values():\n"
				for output in brick.get_value_output_definitions(): code += "\tvar _v%d = %s\n" % [code.length(), str(output.get("expression", "null"))]
				code += "\tpass\n"
			else:
				code += manager._generate_code_for_chains(target, companions + [chain])
			var script := GDScript.new()
			script.source_code = code
			var ok := script.reload() == OK
			checked += 1
			if not ok:
				failed += 1
				var file := FileAccess.open("user://gdb_audit_%s_%d.txt" % [info["class"], checked], FileAccess.WRITE)
				if file: file.store_string(code)
			report.append({"id": info["class"], "case": sample.case, "status": "parse passed" if ok else "parse failed", "target": target.get_class()})
			target.free()
	var output := FileAccess.open("res://addons/GDBlueprints/documentation/node_audit.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "checked": checked, "failed": failed, "cases": report}, "  ") + "\n")
	print("Node mode audit: %d parsed, %d failed, %d require configuration/fixtures" % [checked, failed, report.size() - checked])
	quit(1 if failed else 0)
