@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"
## Shared code generation for UI actions. Saved names remain a fallback;
## a connected target pin always takes precedence, including a null reference.

func _unique_label(chain_name: String) -> String:
	return "gdb_ui_" + chain_name.to_utf8_buffer().hex_encode()

func _append_target_lookup(lines: Array[String], _label: String, target_name: String, variable: String) -> void:
	var expression := str(properties.get("target_expression", "")).strip_edges()
	if expression.is_empty(): expression = var_to_str(target_name)
	lines.append('%s = preload("res://addons/GDBlueprints/core/node_targets.gd").resolve(self, %s, "tree")' % [variable, expression])

func target_pin_definition() -> Dictionary:
	return {"name":"target", "type":TYPE_OBJECT, "default":null, "blueprint_pin":true, "pin_type":"Node"}
