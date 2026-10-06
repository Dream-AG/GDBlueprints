@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Godot-native explicit scene reference lookup.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Get Node By Path"

func _initialize_properties() -> void:
	properties = {"node_path":""}

func get_property_definitions() -> Array:
	return [
		{"name":"node_path", "type":TYPE_STRING, "default":"", "blueprint_pin":false}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"GetNodeByPathActuator",
		"name":"Get Node By Path",
		"type":"actuator",
		"category":"References",
		"description":"Gets a node by a path relative to the current node. This is the direct Godot equivalent of keeping an explicit scene reference.",
		"menu_order":2,
		"aliases":["Get Node", "Get Node By Path", "NodePath", "Scene Reference", "Find Node"],
		"godot_term":"Godot: get_node_or_null(NodePath(\"path\"))"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Godot-native explicit reference lookup. Prefer dragging a Scene Tree node directly into the graph when the target is known at edit time; use this node when the path must be configured as text.",
		"node_path":"Path relative to this scripted node, for example ../Player or UI/HealthBar. Hover the field to see long paths in full."
	}

func _expr() -> String:
	var path := str(properties.get("node_path", "")).strip_edges()
	if path.is_empty():
		return "null"
	return "get_node_or_null(NodePath(\"%s\"))" % _gd_string(path)

func get_value_output_definitions() -> Array:
	return [
		{"name":"Node", "type":"Node", "expression":_expr()},
		{"name":"Found", "type":"Bool", "expression":"is_instance_valid(%s)" % _expr()}
	]

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	# Getter outputs are expressions; this no-op keeps the node legal in an exec chain.
	return {"actuator_code":"pass # Get Node By Path"}
