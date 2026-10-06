@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Calls a method on any live Godot Object using Object.callv().

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Call Object Method"

func _initialize_properties() -> void:
	properties = {
		"target":"self",
		"target_expression":"",
		"method_name":"grab_focus",
		"arguments":"[]",
		"arguments_expression":""
	}

func get_property_definitions() -> Array:
	return [
		{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object", "pin_label":"Target"},
		{"name":"method_name", "type":TYPE_STRING, "default":"grab_focus", "blueprint_pin":false, "required":true, "required_label":"Method Name"},
		{"name":"arguments", "type":TYPE_STRING, "default":"[]", "blueprint_pin":true, "pin_type":"Array", "pin_label":"Arguments"}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"CallObjectMethodActuator",
		"name":"Call Object Method",
		"type":"actuator",
		"category":"References / Methods",
		"description":"Calls a native or script method on another Godot Object. Arguments are supplied as an Array.",
		"menu_order":20,
		"aliases":["Call Function", "Call Method", "Invoke Method", "Run Function On Object"],
		"godot_term":"Godot/GDScript: target.callv(\"method\", args)"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Call functionality on another Godot Object without inventing a Blueprint-only dispatch system. Use a direct typed node reference when possible. Use Custom Events/Signals for looser coupling.",
		"target":"Live Object/Node that owns the method.",
		"method_name":"GDScript method name. Example: grab_focus, show, hide, queue_free, or a method declared in your own script.",
		"arguments":"Array of arguments passed to the method. Leave [] for a no-argument method, or connect an Array data pin."
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
	var args_local := "_gdb_method_args_%s" % _unique_label(chain_name)
	var code := 'var %s = %s\nif %s is Array:\n\tpreload("res://addons/GDBlueprints/core/event_dispatch.gd").dispatch(%s, %s, %s)\nelse:\n\tpush_warning("Call Object Method: Arguments must be an Array.")' % [args_local, _arguments_expression(), args_local, _target_expression(), var_to_str(str(properties.method_name)), args_local]
	return {"actuator":[{"op":"statement", "code":code}]}
