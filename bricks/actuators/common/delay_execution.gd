@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Delay"

func _initialize_properties() -> void:
	properties = {"duration":1.0, "duration_expression":""}

func get_brick_info() -> Dictionary:
	return {"class":"DelayExecution", "name":"Delay", "type":"actuator", "category":"Flow", "domain":"common", "description":"Pauses this execution path, then runs Completed. Re-entry while waiting is ignored. Cancel stops the waiting activation without Completed. Owner tree exit or a Blueprint state change cancels pending work; other event activations remain independent.", "godot_term":"await SceneTree.create_timer().timeout", "aliases":["Wait", "Latent Delay"]}

func get_property_definitions() -> Array:
	return [{"name":"duration", "type":TYPE_FLOAT, "default":1.0, "blueprint_pin":true, "pin_type":"Float", "tooltip":"Seconds of game time to wait. Negative durations clamp to zero. Pauses with the SceneTree."}]

func get_exec_output_definitions() -> Array:
	return [{"name":"Completed", "id":"completed"}]

func get_exec_input_definitions() -> Array:
	return [{"name":"In", "id":"in"}, {"name":"Cancel", "id":"cancel"}]

func get_execution_spec() -> Dictionary:
	var expression := str(properties.get("duration_expression", "")).strip_edges()
	return {"kind":"delay", "duration":expression if not expression.is_empty() else str(float(properties.get("duration", 1.0)))}

func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	return {"actuator_code":"pass # Delay is compiled by the execution graph backend"}
