@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Switch on Int"

func _initialize_properties() -> void:
	properties = {"selection":0,"selection_expression":"","case_0":0,"case_1":1,"case_2":2,"case_3":3}

func get_brick_info() -> Dictionary:
	return {"class":"SwitchIntExecution","name":"Switch on Int","type":"actuator","category":"Flow","domain":"common","description":"Evaluates Selection once and runs its matching Case 0..3 output, or Default. Case values must be unique. Godot enum values are integers and can use this node.","godot_term":"GDScript match / integer enum comparison"}

func get_property_definitions() -> Array:
	var result: Array = [{"name":"selection","type":TYPE_INT,"default":0,"blueprint_pin":true,"pin_type":"Int"}]
	for index in 4: result.append({"name":"case_%d" % index,"type":TYPE_INT,"default":index,"blueprint_pin":false})
	return result

func get_exec_output_definitions() -> Array:
	return [{"name":"Case 0","id":"case_0"},{"name":"Case 1","id":"case_1"},{"name":"Case 2","id":"case_2"},{"name":"Case 3","id":"case_3"},{"name":"Default","id":"default"}]

func get_execution_spec() -> Dictionary:
	var expression := str(properties.get("selection_expression", "")).strip_edges()
	var cases: Array = []
	for index in 4: cases.append(properties["case_%d" % index])
	return {"kind":"switch","expression":expression if not expression.is_empty() else var_to_str(properties.selection),"cases":cases}

func get_configuration_warnings(_node: Node = null) -> Array[String]:
	var cases: Array = get_execution_spec().cases
	var seen: Array = []
	for value in cases:
		if value in seen: return ["Switch case values must be unique."]
		seen.append(value)
	return []
