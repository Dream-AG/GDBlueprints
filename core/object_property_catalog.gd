@tool
extends RefCounted

## Inspect declarations only: never run user getters or evaluate graph expressions.
static func collect(target: Object) -> Array:
	if not is_instance_valid(target):
		return []
	var entries: Dictionary = {}
	_add_properties(entries, target.get_property_list(), "Godot")
	var script = target.get_script()
	if script is Script:
		_add_properties(entries, script.get_script_property_list(), "Script")
	# Graph variables can exist before their generated script has been compiled.
	if target.has_meta("blueprints_for_godot_variables"):
		var variables = target.get_meta("blueprints_for_godot_variables")
		if variables is Array:
			for variable in variables:
				if not variable is Dictionary:
					continue
				var property_name := str(variable.get("name", ""))
				if property_name.is_empty():
					continue
				entries[property_name] = {"name":property_name, "type":str(variable.get("type", "Variant")), "source":"Blueprint (compile target to apply)", "read_only":false}
	var result: Array = entries.values()
	result.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return result

static func _add_properties(entries: Dictionary, properties: Array, origin: String) -> void:
	for property in properties:
		var usage := int(property.get("usage", 0))
		var property_name := str(property.get("name", ""))
		if usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			continue
		if not (usage & (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE)):
			continue
		if property_name.is_empty() or property_name.begins_with("_") or property_name.begins_with("metadata/") or property_name == "script":
			continue
		var type_id := int(property.get("type", TYPE_NIL))
		var type_label := preload("res://addons/GDBlueprints/core/member_catalog.gd").type_name(property)
		if type_id == TYPE_OBJECT and not str(property.get("class_name", "")).is_empty():
			type_label = str(property.class_name)
		entries[property_name] = {"name":property_name, "type":type_label, "source":origin, "read_only":bool(usage & PROPERTY_USAGE_READ_ONLY)}
