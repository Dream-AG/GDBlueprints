@tool
extends RefCounted

const BrickRegistry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const PinTypeRegistry = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")

## Contributor-facing static validation. Returns human-readable errors/warnings.
static func validate_all(domain: String = "") -> Dictionary:
	BrickRegistry.refresh()
	var errors: Array[String] = []
	errors.append_array(BrickRegistry.get_discovery_errors())
	var warnings: Array[String] = []
	var seen_ids: Dictionary = {}
	var checked := 0
	for info in BrickRegistry.get_registered_bricks():
		if not domain.is_empty() and not BrickRegistry._is_domain_compatible(str(info.domain), domain):
			continue
		var script_path := str(info.get("script_path", ""))
		if script_path.is_empty():
			errors.append("Registry entry has no script_path: %s" % str(info))
			continue
		var script = load(script_path)
		if script == null or not script.can_instantiate():
			errors.append("Cannot instantiate node script: %s" % script_path)
			continue
		var node = script.new()
		if node == null:
			errors.append("Node script returned null instance: %s" % script_path)
			continue
		checked += 1
		var definition: Dictionary = node.call("get_blueprint_definition") if node.has_method("get_blueprint_definition") else {}
		var node_id := str(definition.get("id", info.get("class", ""))).strip_edges()
		if node_id.is_empty():
			errors.append("Missing stable node id: %s" % script_path)
		elif seen_ids.has(node_id):
			errors.append("Duplicate node id '%s': %s and %s" % [node_id, str(seen_ids[node_id]), script_path])
		else:
			seen_ids[node_id] = script_path
		var display_name := str(definition.get("display_name", info.get("name", ""))).strip_edges()
		if display_name.is_empty():
			errors.append("Missing display name: %s" % script_path)
		if str(info.get("godot_term", "")).strip_edges().is_empty():
			warnings.append("No Godot/GDScript teaching term: %s" % display_name)
		_validate_pin_list(definition.get("inputs", []), "%s inputs" % display_name, errors, warnings)
		_validate_pin_list(definition.get("data_outputs", []), "%s outputs" % display_name, errors, warnings)
		_validate_named_list(definition.get("exec_inputs", []), "%s exec inputs" % display_name, errors)
		_validate_named_list(definition.get("exec_outputs", []), "%s exec outputs" % display_name, errors)
		if BrickRegistry.get_script_path(str(node.serialize().get("type", ""))) != script_path:
			errors.append("Serialized ID does not resolve back to %s" % script_path)
	return {"checked":checked, "errors":errors, "warnings":warnings}


static func _validate_pin_list(pins: Variant, context: String, errors: Array[String], warnings: Array[String]) -> void:
	if not (pins is Array):
		errors.append("%s must be an Array." % context)
		return
	var seen: Dictionary = {}
	for pin in pins:
		if not (pin is Dictionary):
			errors.append("%s contains a non-Dictionary pin." % context)
			continue
		var name := str(pin.get("pin_label", pin.get("label", pin.get("name", pin.get("property", ""))))).strip_edges()
		if name.is_empty():
			continue
		if seen.has(name):
			errors.append("%s contains duplicate pin '%s'." % [context, name])
		seen[name] = true
		var type_name := str(pin.get("pin_type", ""))
		if type_name.is_empty() and pin.has("type") and typeof(pin.get("type")) == TYPE_INT:
			type_name = PinTypeRegistry.type_from_variant_type(int(pin.get("type")))
		if type_name.is_empty():
			type_name = str(pin.get("type", "Variant"))
		var normalized := PinTypeRegistry.normalize(type_name)
		if normalized.is_empty():
			warnings.append("%s pin '%s' has no type; it will behave as Variant." % [context, name])


static func _validate_named_list(items: Variant, context: String, errors: Array[String]) -> void:
	if not (items is Array):
		errors.append("%s must be an Array." % context)
		return
	var seen: Dictionary = {}
	for item in items:
		var item_id := ""
		if item is Dictionary:
			item_id = str(item.get("id", item.get("name", ""))).strip_edges()
		else:
			item_id = str(item).strip_edges()
		if item_id.is_empty():
			errors.append("%s contains an unnamed entry." % context)
		elif seen.has(item_id):
			errors.append("%s contains duplicate id '%s'." % [context, item_id])
		else:
			seen[item_id] = true
