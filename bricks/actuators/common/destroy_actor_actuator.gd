@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Destroy Actor"

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "target_node_name_expression": ""}

func get_property_definitions() -> Array:
	return [{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "self or node name"}]

func get_brick_info() -> Dictionary:
	return {
		"class": "DestroyActorActuator",
		"name": "Destroy Actor",
		"type": "actuator",
		"category": "Actor / Node",
		"description": "Queues a Godot node for deletion. Unreal: Destroy Actor. Godot/GDScript: queue_free().",
		"menu_order": 20,
		"aliases": ["Destroy Actor", "Destroy", "Delete Actor", "Queue Free", "Free Node"],
		"godot_term": "Godot/GDScript: Node.queue_free()"
	}

func generate_code(_node: Node, chain_name: String) -> Dictionary:
	var target_expression := str(properties.get("target_node_name_expression", "")).strip_edges()
	if not target_expression.is_empty():
		var expression_label := _unique_label(chain_name)
		var expression_var := "_bfg_destroy_target_%s" % expression_label
		var expression_code = "var %s = %s\nif is_instance_valid(%s):\n\t%s.queue_free()\nelse:\n\tpush_warning(\"Destroy Actor: target pin is not a valid Node\")" % [expression_var, target_expression, expression_var, expression_var]
		return {"actuator_code": expression_code}

	var target = str(properties.get("target_node_name", "self")).strip_edges()
	if target.to_lower() == "self" or target.is_empty():
		return {"actuator_code": "queue_free()"}
	var label = _unique_label(chain_name)
	var member_vars: Array[String] = []
	_append_find_node_helpers(member_vars)
	var code = "var _bfg_destroy_target_%s = _lb_find_node_in_current_scene(\"%s\")\nif _bfg_destroy_target_%s:\n\t_bfg_destroy_target_%s.queue_free()\nelse:\n\tpush_warning(\"Destroy Actor: node not found: %s\")" % [label, _gd_string(target), label, label, _gd_string(target)]
	return {"actuator_code": code, "member_vars": member_vars}
