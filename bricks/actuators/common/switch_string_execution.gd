@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/switch_int_execution.gd"

func _init() -> void:
	super._init()
	brick_name = "Switch on String"

func _initialize_properties() -> void:
	properties = {"selection":"","selection_expression":"","case_0":"idle","case_1":"walk","case_2":"run","case_3":"jump"}

func get_brick_info() -> Dictionary:
	return {"class":"SwitchStringExecution","name":"Switch on String","type":"actuator","category":"Flow","domain":"common","description":"Evaluates Selection once and routes an exact, case-sensitive string match to Case 0..3, otherwise Default. Case values must be unique.","godot_term":"GDScript match / exact String comparison"}

func get_property_definitions() -> Array:
	var result: Array = [{"name":"selection","type":TYPE_STRING,"default":"","blueprint_pin":true,"pin_type":"String"}]
	for index in 4: result.append({"name":"case_%d" % index,"type":TYPE_STRING,"default":["idle","walk","run","jump"][index],"blueprint_pin":false})
	return result
