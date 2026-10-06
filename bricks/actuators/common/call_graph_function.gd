@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/call_custom_event_actuator.gd"

func _init() -> void:
	super._init()
	brick_name = "Call Function"

func _initialize_properties() -> void:
	super._initialize_properties()
	properties.erase("event_name")
	properties.function_name = "my_function"
	properties.return_type = "Variant"
	properties._applied_return_type = "Variant"

func get_brick_info() -> Dictionary:
	return {"class":"CallGraphFunction", "name":"Call Function", "type":"actuator", "category":"Functions", "description":"Calls a synchronous function on Self or another Object. Then receives a per-activation Result; Failed runs if dispatch or return-type validation fails. Function calls share execution budgets.", "godot_term":"GDScript: result = target.method(arguments)", "aliases":["Call Graph Function", "Invoke Function"]}

func get_property_definitions() -> Array:
	var result := super.get_property_definitions()
	for definition in result:
		if definition.name == "event_name":
			definition.name = "function_name"
			definition.default = "my_function"
			definition.required_label = "Function Name"
	result.append({"name":"return_type", "type":TYPE_STRING, "default":"Variant", "blueprint_pin":false})
	return result

func get_exec_output_definitions() -> Array:
	return [{"id":"then", "name":"Then"}, {"id":"failed", "name":"Failed"}]

func get_tooltip_definitions() -> Dictionary:
	return {"parameters":"Match the function's name: Type parameter pairs. Click Apply Signature to create typed argument pins. Unconnected fields accept GDScript expressions.", "return_type":"Match the function's return type; use void for no result. Click Apply Signature to update Result."}

func get_execution_spec() -> Dictionary:
	var args: Array[String] = []
	for parameter in Signature.parameters(properties):
		var key := "argument_" + str(parameter.name)
		var initial := Signature.Variables.to_gdscript_value_literal(Signature.Variables.get_default_value_for_variable_type(parameter.type), parameter.type)
		var expression := str(properties.get(key + "_expression", "")).strip_edges()
		if expression.is_empty(): expression = str(properties.get(key, initial)).strip_edges()
		args.append(expression if not expression.is_empty() else initial)
	var target := str(properties.get("target_expression", "")).strip_edges()
	if target.is_empty():
		var path := str(properties.get("target", "self")).strip_edges()
		target = "self" if path.to_lower() in ["", "self"] else 'get_node_or_null("%s")' % path.c_escape()
	return {"kind":"function_call", "method":Signature.event_identifier(str(properties.function_name)), "target":target, "arguments":"[" + ", ".join(args) + "]", "return_type":str(properties.get("_applied_return_type", "Variant"))}

func get_value_output_definitions() -> Array:
	if str(properties.get("_applied_return_type", "Variant")) == "void": return []
	return [{"name":"Result", "type":str(properties.get("_applied_return_type", "Variant")), "expression":'_flow.values["%s"]["result"]' % str(properties.get("_execution_id", "")).c_escape()}]

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {}
