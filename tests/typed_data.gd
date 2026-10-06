extends SceneTree

const Variables = preload("res://addons/GDBlueprints/core/blueprint_variable_utils.gd")
const Pins = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")
const BlueprintPanel = preload("res://addons/GDBlueprints/ui/gdblueprints_panel.gd")
const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func evaluate(value, type_name: String):
	var script := GDScript.new()
	var literal := Variables.to_gdscript_value_literal(value, type_name)
	script.source_code = "extends Node\nvar result: %s = %s\n" % [type_name, literal]
	var error := script.reload()
	check(error == OK, "Declaration failed for %s: %s" % [type_name, literal])
	if error != OK:
		return null
	var instance = script.new()
	var result = instance.result
	instance.free()
	return result

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for type_name in Variables.get_supported_types() + ["Button", "Texture2D", "CharacterBody3D"]:
		var value = Variables.get_default_value_for_variable_type(type_name)
		evaluate(value, type_name)
		if Variables.can_export(type_name):
			var script := GDScript.new()
			script.source_code = "extends Node\n@export var result: %s = %s\n" % [type_name, Variables.to_gdscript_value_literal(value, type_name)]
			check(script.reload() == OK, "Inspector export failed: " + type_name)
	for type_name in ["Button", "Texture2D", "Basis", "Quaternion", "Signal", "PackedVector3Array"]:
		check(Pins.variable_type(type_name) == type_name, "Pin promotion lost " + type_name)
	check(Pins.type_from_variant_type(TYPE_PACKED_VECTOR3_ARRAY) == "PackedVector3Array", "Packed array reflection")
	check(not Pins.compatible("PackedVector3Array", "Array"), "Packed arrays must not masquerade as Array")
	check(Pins.compatible("Texture2D", "Resource"), "Resource inheritance")
	check(not Pins.compatible("Node", "Button"), "Unsafe reference narrowing")
	var payload := {"coins":12, "nested":{"type":"weapon", "value":3}, "spawn":Vector3(1, 2, 3), "list":[null, "a,b", Vector4(1, 2, 3, 4)]}
	check(evaluate(payload, "Dictionary") == payload, "Dictionary values changed during compilation")
	var literal := Variables.to_gdscript_value_literal(payload, "Dictionary")
	check(evaluate(Variables.parse_gdscript_value_literal(literal, "Dictionary"), "Dictionary") == payload, "Dictionary reload changed values")
	var array: Array = [Vector2(2, 3), null, [1, "comma, quote\" slash\\n"], {"type":"Dictionary", "value":payload}, Color(0.1, 0.2, 0.3)]
	var expected = evaluate(array, "Array")
	var restored = Variables.parse_gdscript_value_literal(Variables.to_gdscript_value_literal(array, "Array"), "Array")
	check(evaluate(restored, "Array") == expected, "Nested array reload changed values")
	var packed := PackedVector3Array([Vector3(2, 3, 4), Vector3(-1, 0, 5)])
	check(evaluate(packed, "PackedVector3Array") == packed, "Packed vector data changed")
	check(evaluate(Variables.parse_gdscript_value_literal(Variables.to_gdscript_value_literal(packed, "PackedVector3Array"), "PackedVector3Array"), "PackedVector3Array") == packed, "Packed vector reload changed values")
	for text in ["literal\\n", "line\nnext", "quote\"slash\\end", "tab\tvalue"]:
		check(Variables.parse_gdscript_value_literal(Variables.to_gdscript_value_literal(text, "String"), "String") == text, "String escaping roundtrip")
	var target := Node.new()
	root.add_child(target)
	var panel := BlueprintPanel.new()
	root.add_child(panel)
	panel.current_node = target
	var variables: Array[Dictionary] = []
	for type_name in ["Button", "Dictionary", "Callable", "PackedVector3Array", "Resource"]:
		var record := Variables.create_default_local_variable()
		record.merge({"name":"value_" + str(variables.size()), "type":type_name, "value":Variables.get_default_value_for_variable_type(type_name), "exported":true}, true)
		variables.append(record)
	panel.variables_data = variables
	for i in variables.size():
		panel._create_variable_ui(i, variables[i])
	var selectors := panel.variables_list.find_children("TypeOption", "OptionButton", true, false)
	check(selectors.size() == variables.size(), "Variable editor omitted type selectors")
	for i in mini(selectors.size(), variables.size()):
		check(selectors[i].get_item_text(selectors[i].selected) == variables[i].type, "Editor lost variable type")
	panel._save_variables_to_metadata()
	check(target.get_meta("blueprints_for_godot_variables") == variables, "Variable metadata changed")
	var manager := Manager.new()
	var script := GDScript.new()
	script.source_code = "extends Node\n" + manager._get_variables_code_from_metadata(target)
	check(script.reload() == OK, "Manager generated invalid typed exports")
	panel.free()
	target.free()
	if failures.is_empty():
		print("Typed data regressions passed.")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
