@tool
extends RefCounted

## Resolve UID settings before comparing ownership. Never replace another addon.
static func resolve_path(setting: String) -> String:
	var path := setting.trim_prefix("*")
	if path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(path)
		return ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else path
	return path

static func is_available(singleton: String, expected_path: String) -> bool:
	var key := "autoload/" + singleton
	return not ProjectSettings.has_setting(key) or resolve_path(str(ProjectSettings.get_setting(key))) == expected_path
