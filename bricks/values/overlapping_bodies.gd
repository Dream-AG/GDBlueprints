@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.VALUE
	brick_name = "Get Overlapping Bodies"

func _initialize_properties() -> void:
	properties = {"area":"self"}

func get_brick_info() -> Dictionary:
	return {"class":"OverlappingBodies", "name":"Get Overlapping Bodies", "type":"value", "category":"Collision", "description":"Returns an Area2D/Area3D's latest physics overlap snapshot as Array[Node]. Invalid targets return an empty array. Enable monitoring and configure collision masks; moving an Area does not update overlaps immediately.", "godot_term":"Area2D / Area3D.get_overlapping_bodies()", "aliases":["Overlap Actors"]}

func get_property_definitions() -> Array:
	return [{"name":"area", "type":TYPE_STRING, "default":"self", "blueprint_pin":true, "pin_type":"Node"}]

func get_value_output_definitions() -> Array:
	var area := str(properties.get("area_expression", "")).strip_edges()
	if area.is_empty(): area = str(properties.area)
	return [{"name":"Bodies", "type":"Array[Node]", "expression":'preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").overlapping_bodies(%s)' % area}]
