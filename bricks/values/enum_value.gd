@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

const Types = preload("res://addons/GDBlueprints/core/collection_types.gd")

func _init() -> void:
	super._init()
	brick_type = BrickType.VALUE
	brick_name = "Enum Value"

func _initialize_properties() -> void:
	properties = {"enum_type":"Enum[Idle=0, Running=10]", "case_name":"Idle"}

func get_brick_info() -> Dictionary:
	return {"class":"EnumValue", "name":"Enum Value", "type":"value", "category":"Data", "description":"A named integer case from an explicit Enum[Name=value, ...] type. Keep assigned integers stable when saving game state.", "godot_term":"GDScript: integer enum constant"}

func get_property_definitions() -> Array:
	return [{"name":"enum_type", "type":TYPE_STRING, "default":"Enum[Idle=0, Running=10]"}, {"name":"case_name", "type":TYPE_STRING, "default":"Idle"}]

func get_value_output_definitions() -> Array:
	var spec := Types.parse(str(properties.enum_type))
	var expression := "GDBLUEPRINTS_INVALID_ENUM_CASE"
	if spec.get("kind") == "Enum" and spec.cases.has(properties.case_name): expression = str(spec.cases[properties.case_name])
	return [{"name":"Value", "type":str(properties.enum_type), "expression":expression}]
