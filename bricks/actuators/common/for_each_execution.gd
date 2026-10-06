@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "For Each"

func _initialize_properties() -> void:
	properties = {"items":"[]","items_expression":""}

func get_brick_info() -> Dictionary:
	return {"class":"ForEachExecution","name":"For Each","type":"actuator","category":"Flow","domain":"common","description":"Iterates a shallow snapshot of an Array in order, awaiting Body before the next item. Index and Item are scoped to Body. Completed also runs for empty arrays or Break. Non-Array input cancels execution.","godot_term":"Array.duplicate() and structured GDScript iteration","aliases":["For Each Loop","ForEachLoop"]}

func get_property_definitions() -> Array:
	return [{"name":"items","type":TYPE_STRING,"default":"[]","blueprint_pin":true,"pin_type":"Array","tooltip":"An Array expression or connected Array value. The list is copied; contained Objects remain references."}]

func get_exec_output_definitions() -> Array:
	return [{"name":"Body","id":"body"},{"name":"Completed","id":"completed"}]

func get_value_output_definitions() -> Array:
	var key := var_to_str(str(properties.get("_execution_id","unplaced_loop")))
	return [{"name":"Index","type":"Int","expression":'_flow.values.get(%s, {}).get("index", 0)' % key},{"name":"Item","type":"Variant","expression":'_flow.values.get(%s, {}).get("item")' % key}]

func get_execution_spec() -> Dictionary:
	var expression := str(properties.get("items_expression", "")).strip_edges()
	return {"kind":"foreach","key":str(properties.get("_execution_id","unplaced_loop")),"items":expression if not expression.is_empty() else str(properties.items)}
