extends SceneTree
const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")

func _initialize() -> void:
	var nodes: Array = []
	for info in Registry.get_registered_bricks():
		var brick = load(info.script_path).new()
		var record: Dictionary = info.duplicate(true)
		record.erase("menu_id")
		record["inputs"] = brick.get_property_definitions()
		record["outputs"] = brick.get_value_output_definitions() if brick.has_method("get_value_output_definitions") else []
		record["tooltips"] = brick.get_tooltip_definitions()
		record["defaults"] = brick.properties.duplicate(true)
		record["exec_inputs"] = brick.get_exec_input_definitions()
		record["exec_outputs"] = brick.get_exec_output_definitions()
		record["configuration_warnings"] = brick.get_configuration_warnings(null)
		record["compatibility"] = {}
		for target_class in ["Node", "Node2D", "CharacterBody2D", "RigidBody2D", "Node3D", "CharacterBody3D", "RigidBody3D", "Control"]:
			var target = ClassDB.instantiate(target_class)
			record.compatibility[target_class] = brick.get_compatibility_error(target) if brick.has_method("get_compatibility_error") else ""
			target.free()
		record["menu_domains"] = []
		for domain in ["2d", "3d", "ui"]:
			if Registry.get_all_bricks(domain).any(func(candidate): return candidate["class"] == info["class"]):
				record.menu_domains.append(domain)
		nodes.append(record)
	nodes.sort_custom(func(a, b): return str(a["class"]) < str(b["class"]))
	var path := "res://addons/GDBlueprints/documentation/addon_inventory.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(nodes, "  ") + "\n")
	print("Exported %d node definitions." % nodes.size())
	quit()
