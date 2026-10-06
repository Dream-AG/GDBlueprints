@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Unreal-style Branch with separate True and False execution outputs.

func _init() -> void:
	super._init()
	brick_type = BrickType.CONTROLLER
	brick_name = "Branch"

func _initialize_properties() -> void:
	properties = {"condition": true, "condition_expression": ""}

func get_property_definitions() -> Array:
	return [{"name":"condition", "type":TYPE_BOOL, "default":true}]

func get_brick_info() -> Dictionary:
	return {
		"class":"BranchController",
		"name":"Branch",
		"type":"controller",
		"category":"Flow Control",
		"description":"Unreal-style Branch. Executes either the True or False output based on Condition.",
		"menu_order":1,
		"aliases":["Branch", "If", "If Else", "Boolean Branch"],
		"godot_term":"GDScript: if condition: ... else: ..."
	}


func get_exec_output_definitions() -> Array:
	return [
		{"name":"True", "id":"true", "color":"7bd88f"},
		{"name":"False", "id":"false", "color":"e06c75"}
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Unreal: Branch\nGodot/GDScript: if condition: ... else: ...\nConnect a Bool value to Condition, then wire both True and False exec outputs.",
		"condition":"Checked = True; unchecked = False. Branch follows the True output when checked and the False output when unchecked. A connected Bool data pin overrides this checkbox."
	}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {"controller_code":""}

func get_execution_spec() -> Dictionary:
	var expression := str(properties.get("condition_expression", "")).strip_edges()
	return {"kind":"branch", "condition":expression if not expression.is_empty() else str(bool(properties.get("condition", true)))}
