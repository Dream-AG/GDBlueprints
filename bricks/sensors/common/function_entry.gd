@tool
extends "res://addons/GDBlueprints/bricks/sensors/common/custom_event_sensor.gd"

func _init() -> void:
	super._init()
	brick_name = "Function Entry"

func _initialize_properties() -> void:
	properties = {"function_name":"my_function", "parameters":"", "_applied_parameters":"", "locals":"", "_applied_locals":"", "return_type":"Variant", "_applied_return_type":"Variant"}

func get_brick_info() -> Dictionary:
	return {"class":"FunctionEntry", "name":"Function Entry", "type":"sensor", "category":"Functions", "description":"Defines a synchronous public function with typed parameters, a return type, and per-call locals. Apply Signature commits its declarations. Waiting operations belong in event graphs.", "godot_term":"GDScript: func name(arguments) -> ReturnType", "aliases":["Function", "Define Function"]}

func get_property_definitions() -> Array:
	return [
		{"name":"function_name", "type":TYPE_STRING, "default":"my_function", "blueprint_pin":false, "required":true},
		Signature.property_definition(),
		{"name":"return_type", "type":TYPE_STRING, "default":"Variant", "blueprint_pin":false},
		{"name":"locals", "type":TYPE_STRING, "default":"", "blueprint_pin":false}
	]

func get_value_output_definitions() -> Array:
	var result: Array = []
	var name := Signature.event_identifier(str(properties.function_name))
	for parameter in Signature.parameters(properties):
		result.append({"name":parameter.name, "type":parameter.type, "expression":'_flow.function_arguments["%s"]["%s"]' % [name.c_escape(), parameter.name]})
	for local in Signature.parse(str(properties.get("_applied_locals", ""))).parameters:
		result.append({"name":"Local: " + str(local.name), "type":local.type, "expression":'_flow.function_locals["%s"]["%s"]' % [name.c_escape(), local.name]})
	return result

func get_tooltip_definitions() -> Dictionary:
	return {"parameters":"name: Type pairs, separated by commas. Click Apply Signature to commit.", "locals":"Per-call local declarations, for example total: Int, items: Array. Locals start at their type's default. Use Set Local to change them.", "return_type":"A supported Godot type or void. Click Apply Signature after editing."}
