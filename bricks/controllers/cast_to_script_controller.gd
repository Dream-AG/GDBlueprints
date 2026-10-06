@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Unreal-familiar Cast To translated to Godot's runtime script/type check.
## In Godot the object is not converted into a different object; this node
## verifies that the same instance uses/inherits the selected script.

func _init() -> void:
	super._init()
	brick_type = BrickType.CONTROLLER
	brick_name = "Cast To Script"

func _initialize_properties() -> void:
	properties = {"target":"self", "target_expression":"", "script_path":""}

func get_property_definitions() -> Array:
	return [
		{"name":"target", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Object"},
		{"name":"script_path", "type":TYPE_STRING, "default":"", "hint":PROPERTY_HINT_FILE, "hint_string":"*.gd", "blueprint_pin":false, "required":true, "required_label":"Script"}
	]

func get_brick_info() -> Dictionary:
	return {
		"class":"CastToScriptController",
		"name":"Cast To Script",
		"type":"controller",
		"category":"References / Types",
		"description":"Checks whether Target uses or inherits the selected GDScript. The successful output is the same Godot object reference.",
		"menu_order":1,
		"aliases":["Cast To", "Cast", "Dynamic Cast", "Cast To Class", "Cast To Script", "Script Type Check"],
		"godot_term":"Godot: is_instance_of(target, load(\"res://...gd\"))"
	}


func get_exec_output_definitions() -> Array:
	return [
		{"name":"Cast Succeeded", "id":"success", "color":"7bd88f"},
		{"name":"Cast Failed", "id":"failure", "color":"e06c75"}
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Unreal: Cast To ...\nGodot: check the object's script/type with is_instance_of(). Godot keeps the same object reference; there is no separate cast object. For loose coupling, signals/groups are often preferable to casting.",
		"target":"Object to test. Connect a scene-node reference, group lookup result, or another object output.",
		"script_path":"GDScript resource to test against. Inherited scripts count as a successful match."
	}

func _target_expression() -> String:
	var expression := str(properties.get("target_expression", "")).strip_edges()
	if not expression.is_empty():
		return expression
	var target_text := str(properties.get("target", "self")).strip_edges()
	if target_text.is_empty() or target_text.to_lower() == "self":
		return "self"
	return "get_node_or_null(\"%s\")" % _gd_string(target_text)

func _script_expression() -> String:
	var path := str(properties.get("script_path", "")).strip_edges()
	return "null" if path.is_empty() else "load(\"%s\")" % _gd_string(path)

func get_value_output_definitions() -> Array:
	var target_expr := _target_expression()
	var script_expr := _script_expression()
	var success_expr := "false" if script_expr == "null" else "(is_instance_valid(%s) and is_instance_of(%s, %s))" % [target_expr, target_expr, script_expr]
	return [
		{"name":"As Script", "type":"Object", "expression":"(%s if %s else null)" % [target_expr, success_expr]},
		{"name":"Success", "type":"Bool", "expression":success_expr}
	]

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {"controller_code":""}

func get_execution_spec() -> Dictionary:
	return {"kind":"branch", "condition":str(get_value_output_definitions()[1].expression), "true_output":"success", "false_output":"failure"}
