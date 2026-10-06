extends SceneTree
var checked := 0
var failures: Array[String] = []

func _initialize() -> void:
	_scan("res://addons/GDBlueprints")
	if checked == 0: failures.append("No addon scripts found")
	print("Source validation: %d scripts, %d failures." % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _scan(path: String) -> void:
	if FileAccess.file_exists(path.path_join(".gdignore")):
		return
	var directory := DirAccess.open(path)
	if directory == null: return
	for file in directory.get_files():
		if file.ends_with(".gd"):
			var script = load(path.path_join(file))
			checked += 1
			if script == null or not script.can_instantiate():
				failures.append(path.path_join(file))
	for child in directory.get_directories():
		if not child.begins_with("."):
			_scan(path.path_join(child))
