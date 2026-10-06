@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Open Level"

func _initialize_properties() -> void:
	properties = {"scene_path": ""}

func get_property_definitions() -> Array:
	return [{"name": "scene_path", "required": true, "required_label": "a Godot scene", "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.tscn,*.scn", "default": ""}]

func get_brick_info() -> Dictionary:
	return {
		"class": "OpenLevelActuator",
		"name": "Open Level",
		"type": "actuator",
		"category": "Gameplay / Scene",
		"description": "Loads another Godot scene. Unreal: Open Level. Godot: SceneTree.change_scene_to_file().",
		"menu_order": 10,
		"aliases": ["Open Level", "Load Level", "Change Level", "Change Scene"],
		"godot_term": "Godot: get_tree().change_scene_to_file(path)"
	}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	var path = str(properties.get("scene_path", "")).strip_edges()
	if path.is_empty():
		return {"actuator_code": "push_warning(\"Open Level: choose a .tscn scene first\")"}
	return {"actuator_code": "get_tree().change_scene_to_file(\"%s\")" % _gd_string(path)}
