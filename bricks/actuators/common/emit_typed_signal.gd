@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/call_custom_event_actuator.gd"

func _init() -> void:
	super._init()
	brick_name = "Emit Typed Signal"

func _initialize_properties() -> void:
	super._initialize_properties()
	properties.erase("event_name")
	properties.signal_name = "changed"

func get_brick_info() -> Dictionary:
	return {"class":"EmitTypedSignal", "name":"Emit Typed Signal", "type":"actuator", "category":"Signals", "description":"Emits an existing native or handwritten signal with named typed arguments. Browse Signals to populate its signature. Invalid targets or arguments are skipped with a warning.", "godot_term":"Godot: Object.emit_signal"}

func get_property_definitions() -> Array:
	var definitions := super.get_property_definitions()
	for definition in definitions:
		if definition.name == "event_name":
			definition.name = "signal_name"
			definition.default = "changed"
			definition.required_label = "Signal Name"
	return definitions

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	var args: Array[String] = []
	for parameter in Signature.parameters(properties):
		var key := "argument_" + str(parameter.name)
		var initial := Signature.Variables.to_gdscript_value_literal(Signature.Variables.get_default_value_for_variable_type(parameter.type), parameter.type)
		var value := str(properties.get(key + "_expression", "")).strip_edges()
		if value.is_empty(): value = str(properties.get(key, initial)).strip_edges()
		args.append(value if not value.is_empty() else initial)
	var target := str(properties.get("target_expression", "")).strip_edges()
	if target.is_empty():
		var path := str(properties.get("target", "self"))
		target = "self" if path.to_lower() in ["", "self"] else "get_node_or_null(%s)" % var_to_str(path)
	return {"actuator_code":'if not preload("res://addons/GDBlueprints/core/signal_dispatch.gd").emit_checked(%s, %s, [%s]):\n\tpush_warning("Emit Typed Signal: target or arguments did not match the signal.")' % [target, var_to_str(str(properties.signal_name)), ", ".join(args)]}
