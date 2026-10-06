extends SceneTree

const Validator = preload("res://addons/GDBlueprints/core/node_definition_validator.gd")

func _initialize() -> void:
	var report := Validator.validate_all()
	print("GDBlueprints validator: checked %d registered nodes." % int(report.get("checked", 0)))
	for warning in report.get("warnings", []):
		push_warning("BFG validator: " + str(warning))
	var errors: Array = report.get("errors", [])
	for error in errors:
		push_error("BFG validator: " + str(error))
	quit(0 if errors.is_empty() else 1)
