@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Emits a native Godot signal dynamically.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Emit Signal"

func _initialize_properties() -> void:
	properties = {
		"target":"self",
		"target_expression":"",
		"signal_name":"changed",
		"arguments":"[]",
		"arguments_expression":""
	}

func get_property_definitions() -> Array:
	return [
		{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object", "pin_label":"Target"},
		{"name":"signal_name", "type":TYPE_STRING, "default":"changed", "blueprint_pin":false, "required":true, "required_label":"Signal Name"},
		{"name":"arguments", "type":TYPE_STRING, "default":"[]", "blueprint_pin":true, "pin_type":"Array", "pin_label":"Arguments"}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"EmitSignalActuator",
		"name":"Emit Signal",
		"type":"actuator",
		"category":"Signals",
		"description":"Emits a signal on a Godot Object using its native signal system.",
		"menu_order":2,
		"aliases":["Broadcast", "Call Event Dispatcher", "Emit Event", "Emit Signal"],
		"godot_term":"Godot/GDScript: target.emit_signal(\"signal_name\", ...)"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Godot equivalent of broadcasting an Event Dispatcher. Target must declare the signal. Supply signal arguments as an Array in the same order as the signal declaration.",
		"target":"Object that owns the signal. Self is common for signals declared on the current script.",
		"signal_name":"Signal name declared by the target.",
		"arguments":"Signal arguments in declaration order. Leave [] for a no-argument signal."
	}

func _target_expression() -> String:
	var expression := str(properties.get("target_expression", "")).strip_edges()
	if not expression.is_empty():
		return expression
	var target_text := str(properties.get("target", "self")).strip_edges()
	if target_text.is_empty() or target_text.to_lower() == "self":
		return "self"
	return "get_node_or_null(\"%s\")" % _gd_string(target_text)

func _arguments_expression() -> String:
	var expression := str(properties.get("arguments_expression", "")).strip_edges()
	if not expression.is_empty():
		return expression
	var manual := str(properties.get("arguments", "[]")).strip_edges()
	return "[]" if manual.is_empty() else manual

func generate_ir(_node: Node, chain_name: String) -> Dictionary:
	var args := "_gdb_signal_args_%s" % _unique_label(chain_name)
	var code := 'var %s = %s\nif not %s is Array or not preload("res://addons/GDBlueprints/core/signal_dispatch.gd").emit_checked(%s, %s, %s):\n\tpush_warning("Emit Signal: target or arguments do not match the signal.")' % [args, _arguments_expression(), args, _target_expression(), var_to_str(str(properties.signal_name)), args]
	return {"actuator":[{"op":"statement", "code":code}]}
