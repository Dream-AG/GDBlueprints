extends SceneTree

const ExtendedPrint = preload("res://addons/GDBlueprints/tests/fixtures/extended_print_string.gd")

func _init() -> void:
	var failures: Array[String] = []
	var node = ExtendedPrint.new()
	var info: Dictionary = node.get_brick_info()
	if info.get("class") != "TestExtendedPrintStringActuator":
		failures.append("extension did not replace the stable ID")
	if node.properties.get("text") == null or node.properties.get("prefix") != "[Test]":
		failures.append("extension did not preserve base properties and add its own")
	var names: Array[String] = []
	for definition in node.get_property_definitions():
		names.append(str(definition.get("name", "")))
	if not names.has("text") or not names.has("prefix"):
		failures.append("extension did not preserve base pins and add its own")
	var generated: Dictionary = node.generate_code(null, "test")
	var code := str(generated.get("actuator_code", ""))
	if not code.contains("extension") or not code.contains("Hello from GDBlueprints!"):
		failures.append("extension did not compose with base code generation")
	var template = load("res://addons/GDBlueprints/templates/extend_existing_node_template.gd").new()
	template.properties.text = "hello"
	template.properties.prefix = "[Game] "
	var template_code: String = str(template.generate_code(null, "test").get("actuator_code", ""))
	if template_code != 'print("[Game] " + str("hello"))' or template.properties.text_expression != "":
		failures.append("extension template did not prefix text or mutated its saved expression")
	print("Node extension failures: %d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)
