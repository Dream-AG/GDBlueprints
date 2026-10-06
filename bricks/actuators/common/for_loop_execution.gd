@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "For Loop"

func _initialize_properties() -> void:
	properties = {"first":0,"last":9,"step":1,"first_expression":"","last_expression":"","step_expression":""}

func get_brick_info() -> Dictionary:
	return {"class":"ForLoopExecution","name":"For Loop","type":"actuator","category":"Flow","domain":"common","description":"Visits inclusive First..Last using Step. Awaits each Body, then runs Completed, including after Break or an empty range. Index is valid only inside Body. Step zero cancels execution.","godot_term":"Structured GDScript iteration with bounded execution","aliases":["For Loop With Break"]}

func get_property_definitions() -> Array:
	return [{"name":"first","type":TYPE_INT,"default":0,"blueprint_pin":true,"pin_type":"Int"},{"name":"last","type":TYPE_INT,"default":9,"blueprint_pin":true,"pin_type":"Int"},{"name":"step","type":TYPE_INT,"default":1,"blueprint_pin":true,"pin_type":"Int"}]

func get_exec_output_definitions() -> Array:
	return [{"name":"Body","id":"body"},{"name":"Completed","id":"completed"}]

func get_value_output_definitions() -> Array:
	return [{"name":"Index","type":"Int","expression":'_flow.values.get(%s, {}).get("index", 0)' % var_to_str(str(properties.get("_execution_id","unplaced_loop")))}]

func _expression(key: String) -> String:
	var bound := str(properties.get(key+"_expression", "")).strip_edges()
	return bound if not bound.is_empty() else str(int(properties[key]))

func get_execution_spec() -> Dictionary:
	return {"kind":"for","key":str(properties.get("_execution_id","unplaced_loop")),"first":_expression("first"),"last":_expression("last"),"step":_expression("step")}

func get_configuration_warnings(_node: Node = null) -> Array[String]:
	return ["Step must not be zero."] if _expression("step") == "0" else []
