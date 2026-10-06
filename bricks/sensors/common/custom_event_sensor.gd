@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"
const Signature = preload("res://addons/GDBlueprints/core/event_signature.gd")

## A named callable entry point, equivalent to Unreal's Custom Event.

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Custom Event"

func _initialize_properties() -> void:
	properties = {"event_name":"my_event", "parameters":"", "_applied_parameters":""}

func get_property_definitions() -> Array:
	return [{"name":"event_name", "type":TYPE_STRING, "default":"my_event", "blueprint_pin":false, "required":true, "required_label":"Event Name"}, Signature.property_definition()]

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var result := super.get_configuration_warnings(node)
	result.append_array(Signature.warnings(properties))
	return result

func get_value_output_definitions() -> Array:
	var result: Array = []
	for parameter in Signature.parameters(properties):
		result.append({"name":parameter.name, "type":parameter.type, "expression":Signature.output_expression(Signature.event_identifier(str(properties.event_name)), parameter.name)})
	return result

func get_brick_info() -> Dictionary:
	return {
		"class":"CustomEventSensor",
		"name":"Custom Event",
		"type":"sensor",
		"category":"Events",
		"description":"Creates a public GDScript event method with optional typed parameters. Argument outputs belong to the current invocation, including delayed paths.",
		"menu_order":4,
		"aliases":["Custom Event", "Named Event", "Callable Event", "Public Event"],
		"godot_term":"Godot/GDScript: func my_event() -> void"
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Unreal: Custom Event\nGodot: a named method on this script. Other nodes can call target.my_event() or use Call Custom Event.",
		"event_name":"Public method name generated into GDScript. Use a unique name on this script.",
		"parameters":"Enter name: Type pairs, such as amount: Float, source: Node. Click Apply Parameters to update pins."
	}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	# This chain is called only through the generated public event method.
	return {"sensor_code":"var sensor_active = true"}
