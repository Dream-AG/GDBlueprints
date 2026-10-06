extends RefCounted

const Dispatch = preload("res://addons/GDBlueprints/core/event_dispatch.gd")

static func get_checked(target: Variant, name: String) -> Variant:
	if not target is Object or not is_instance_valid(target): return null
	for property in target.get_property_list():
		if str(property.name) == name: return target.get(name)
	push_warning("Get Object Property: property no longer exists: " + name)
	return null

static func set_checked(target: Variant, name: String, value: Variant) -> bool:
	if not target is Object or not is_instance_valid(target): return false
	for property in target.get_property_list():
		if str(property.name) != name: continue
		if int(property.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY or not Dispatch._accepts(value, property):
			push_warning("Set Object Property: read-only property or incompatible value: " + name)
			return false
		value = Dispatch.Members.Pins.Collections.converted(value, Dispatch.Members.type_name(property))
		target.set(name, value)
		return true
	push_warning("Set Object Property: property no longer exists: " + name)
	return false
