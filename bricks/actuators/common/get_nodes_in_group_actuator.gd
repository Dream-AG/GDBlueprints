@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Godot's idiomatic alternative to Unreal's Get Actor(s) Of Class for gameplay
## discovery: use SceneTree groups as explicit roles/tags, then optionally Cast To
## Script when a concrete script contract is required.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Get Nodes In Group"

func _initialize_properties() -> void:
	properties = {"group_name":""}

func get_property_definitions() -> Array:
	return [
		{"name":"group_name", "type":TYPE_STRING, "default":"", "group_picker":true, "blueprint_pin":false}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"GetNodesInGroupActuator",
		"name":"Get Nodes In Group",
		"type":"actuator",
		"category":"References",
		"description":"Godot-style scene discovery. Groups are usually a better fit than searching the whole scene for every instance of a class.",
		"menu_order":3,
		"aliases":["Get Actors Of Class", "Get Actor Of Class", "Get Nodes In Group", "Find By Group", "Get Group", "Find Actors"],
		"godot_term":"Godot: get_tree().get_nodes_in_group(\"group\")"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Closest Godot-style equivalent to Get Actor(s) Of Class: put gameplay objects in a named SceneTree group (for example enemies), retrieve that group, then Cast To Script only when you need a specific script contract.",
		"group_name":"SceneTree group to query. Groups are explicit, fast to understand, and avoid tightly coupling gameplay code to a concrete scene class."
	}

func _group_literal() -> String:
	return "\"%s\"" % _gd_string(str(properties.get("group_name", "")).strip_edges())

func _nodes_expr() -> String:
	return "get_tree().get_nodes_in_group(%s)" % _group_literal()

func _first_expr() -> String:
	return "(%s[0] if not %s.is_empty() else null)" % [_nodes_expr(), _nodes_expr()]

func get_value_output_definitions() -> Array:
	return [
		{"name":"Nodes", "type":"Array", "expression":_nodes_expr()},
		{"name":"First", "type":"Node", "expression":_first_expr()},
		{"name":"Count", "type":"Int", "expression":"%s.size()" % _nodes_expr()},
		{"name":"Found", "type":"Bool", "expression":"not %s.is_empty()" % _nodes_expr()}
	]

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {"actuator_code":"pass # Get Nodes In Group"}
