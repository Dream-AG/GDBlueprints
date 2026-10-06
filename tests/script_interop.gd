extends SceneTree

const Manager = preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var manager := Manager.new()
	var handwritten_before := "extends Node\n\nconst PLAYER_SPEED := 12.0\nsignal requested\nvar score := 4\n\n"
	var handwritten_after := "\nfunc calculate_bonus(value: int) -> int:\n\treturn value * 2\n"
	var old_generated := "var old_visual_value := 1\nfunc _blueprint_old(_delta: float) -> void:\n\tpass\n"
	var source := handwritten_before + manager.CODE_START_MARKER + "\n" + old_generated + manager.CODE_END_MARKER + handwritten_after
	var new_generated := "var new_visual_value := 2\nfunc _blueprint_new(_delta: float) -> void:\n\tpass\n"
	var fixture_node := Node.new()
	var combined := manager._replace_generated_code(source, new_generated, fixture_node)
	fixture_node.free()
	check(combined.begins_with(handwritten_before), "Handwritten declarations before the generated region changed")
	check(combined.ends_with(handwritten_after), "Handwritten functions after the generated region changed")
	check(not combined.contains("old_visual_value"), "Old generated code was retained")
	check(combined.contains("new_visual_value"), "New generated code was not inserted")
	check(manager._validate_generated_markers(source).is_empty(), "Valid markers rejected")
	var old_source := source.replace(manager.CODE_START_MARKER, manager.GeneratedRegion.OLD_START).replace(manager.CODE_END_MARKER, manager.GeneratedRegion.OLD_END)
	var migration_node := Node.new()
	var migrated := manager._replace_generated_code(old_source, new_generated, migration_node)
	migration_node.free()
	check(migrated == combined, "Old generated region was not migrated without changing handwritten code")
	check(not manager._validate_generated_markers(source + manager.GeneratedRegion.OLD_START).is_empty(), "Mixed old/new duplicate markers accepted")
	check(not manager._validate_generated_markers(handwritten_before + manager.CODE_START_MARKER).is_empty(), "Unpaired marker accepted")
	check(not manager._validate_generated_markers(source + manager.CODE_START_MARKER).is_empty(), "Duplicate marker accepted")
	var collisions := manager._find_manual_symbol_collisions("extends Node\nfunc _process(delta):\n\tpass\nvar health = 2\n", "func _process(delta):\n\tpass\nvar score = 0\n")
	check(collisions == ["_process"], "Function collision was not reported exactly")
	var variable_collision := manager._find_manual_symbol_collisions("extends Node\n@export var health: int = 2\n", "var health: int = 1\n")
	check(variable_collision == ["health"], "Annotated variable collision was not detected")
	var insertion_fixture := Node.new()
	var annotated := "extends Node\n\n@warning_ignore(\"unused_parameter\")\nfunc custom(value):\n\tpass\n"
	var inserted := manager._replace_generated_code(annotated, new_generated, insertion_fixture)
	insertion_fixture.free()
	check(inserted.find(manager.CODE_END_MARKER) < inserted.find("@warning_ignore"), "Generated region split a handwritten function annotation")
	var parsed := GDScript.new()
	parsed.source_code = combined
	check(parsed.reload() == OK, "Combined handwritten/generated script did not parse")
	print("Script interoperability: %d failures." % failures.size())
	quit(0 if failures.is_empty() else 1)
