@tool
extends "res://addons/GDBlueprints/bricks/actuators/common/print_string_actuator.gd"

func _initialize_properties() -> void:
	super._initialize_properties()
	properties["prefix"] = "[Test]"

func get_brick_info() -> Dictionary:
	var info: Dictionary = super.get_brick_info().duplicate(true)
	info.merge({"class": "TestExtendedPrintStringActuator", "name": "Test Extended Print String"}, true)
	return info

func get_property_definitions() -> Array:
	var definitions: Array = super.get_property_definitions().duplicate(true)
	definitions.append({"name": "prefix", "type": TYPE_STRING, "default": "[Test]"})
	return definitions

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var generated: Dictionary = super.generate_code(node, chain_name)
	generated["actuator_code"] = "print(\"extension\")\n" + str(generated.get("actuator_code", ""))
	return generated
