@tool
extends RefCounted

const Pins = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")
const Variables = preload("res://addons/GDBlueprints/core/blueprint_variable_utils.gd")
const RESERVED = ["self", "super", "true", "false", "null", "func", "var", "const", "class", "class_name", "extends", "signal", "enum", "static", "return", "if", "elif", "else", "for", "while", "in", "is", "as", "and", "or", "not", "match", "break", "continue", "pass", "await", "assert", "breakpoint", "preload", "void", "set", "get"]

static func event_identifier(value: String) -> String:
	var raw := value.strip_edges().replace(" ", "_")
	if raw.is_empty(): raw = "custom_event"
	# Preserve the historical public method spelling for handwritten callers.
	var out := ""
	for index in raw.length():
		var character := raw[index]
		out += character if character.is_valid_identifier() or (index > 0 and character.is_valid_int()) else "_"
	return out

static func parse(text: String) -> Dictionary:
	var result := {"parameters":[], "error":""}
	if text.strip_edges().is_empty():
		return result
	var names: Dictionary = {}
	var identifier := RegEx.new()
	identifier.compile("^[A-Za-z][A-Za-z0-9_]*$")
	for entry in Pins.Collections.split_top(text):
		var parts := entry.strip_edges().split(":", true, 1)
		if parts.size() != 2:
			result.error = "Use name: Type pairs, separated by commas (for example amount: Float, source: Node)."
			return result
		var name := parts[0].strip_edges()
		var schema := parts[1].strip_edges()
		var type_name := schema if Pins.Collections.parse(schema).get("kind") == "Enum" else Pins.variable_type(schema)
		if identifier.search(name) == null or name in RESERVED or names.has(name) or Variables.is_supported_type(name):
			result.error = "Parameter names must be unique identifiers beginning with a letter, without GDScript keywords: " + name
			return result
		if type_name.is_empty() or not Variables.is_supported_type(type_name):
			result.error = "Unsupported parameter type: " + parts[1].strip_edges()
			return result
		names[name] = true
		result.parameters.append({"name":name, "type":type_name})
	return result

static func parameters(properties: Dictionary) -> Array:
	return parse(str(properties.get("_applied_parameters", ""))).parameters

static func warnings(properties: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var apply_label := "Apply Signature" if properties.has("return_type") else "Apply Parameters"
	var parsed := parse(str(properties.get("parameters", "")))
	if not str(parsed.error).is_empty():
		result.append(parsed.error)
	elif str(properties.get("parameters", "")) != str(properties.get("_applied_parameters", "")):
		result.append("Click %s to update this node's typed pins before compiling." % apply_label)
	if properties.has("return_type"):
		var declared := return_type(str(properties.return_type))
		if declared.is_empty(): result.append("Return Type must be a supported Godot type or void.")
		elif declared != str(properties.get("_applied_return_type", "Variant")): result.append("Click Apply Signature to update the return type.")
	if properties.has("locals"):
		var local_signature := parse(str(properties.locals))
		if not str(local_signature.error).is_empty(): result.append("Locals: " + str(local_signature.error))
		elif str(properties.locals) != str(properties.get("_applied_locals", "")): result.append("Click Apply Signature to update local declarations.")
	return result

static func return_type(text: String) -> String:
	if text.strip_edges() == "void": return "void"
	var name := text.strip_edges() if Pins.Collections.parse(text.strip_edges()).get("kind") == "Enum" else Pins.variable_type(text)
	return name if Variables.is_supported_type(name) else ""

static func property_definition() -> Dictionary:
	return {"name":"parameters", "type":TYPE_STRING, "default":"", "blueprint_pin":false}

static func declaration(properties: Dictionary) -> String:
	var parts: Array[String] = []
	for parameter in parameters(properties):
		parts.append("%s: %s" % [parameter.name, Pins.variable_type(parameter.type)])
	return ", ".join(parts)

static func identity(properties: Dictionary) -> String:
	var parts: Array[String] = []
	for parameter in parameters(properties): parts.append("%s: %s" % [parameter.name, Pins.normalize(parameter.type)])
	return ", ".join(parts)

static func argument_map(properties: Dictionary) -> String:
	var parts: Array[String] = []
	for parameter in parameters(properties):
		parts.append('"%s": %s' % [parameter.name, parameter.name])
	return "{" + ", ".join(parts) + "}"

static func output_expression(event_name: String, parameter_name: String) -> String:
	return '_flow.event_arguments["%s"]["%s"]' % [event_name.c_escape(), parameter_name]

static func validate_chains(chains: Array) -> String:
	var events: Dictionary = {}
	for chain in chains:
		var chain_events: Array[String] = []
		var has_parameters := false
		for sensor in chain.get("sensors", []):
			if str(sensor.get("type", "")) != "CustomEventSensor": continue
			var props: Dictionary = sensor.get("properties", {})
			var errors := warnings(props)
			if not errors.is_empty(): return "; ".join(errors)
			var event_name := event_identifier(str(props.get("event_name", "custom_event")))
			var signature := identity(props)
			if event_name not in chain_events: chain_events.append(event_name)
			has_parameters = has_parameters or not signature.is_empty()
			if events.has(event_name) and events[event_name] != signature:
				return "Custom Event %s has conflicting parameter signatures." % event_name
			events[event_name] = signature
		if has_parameters and chain_events.size() > 1:
			return "Parameterized Custom Events need separate execution paths; do not combine distinct events through a legacy condition gate."
	var reference := RegEx.new()
	reference.compile('_flow\\.event_arguments\\["([^"]+)"\\]\\["([^"]+)"\\]')
	for chain in chains:
		var allowed: Dictionary = {}
		for sensor in chain.get("sensors", []):
			if str(sensor.get("type", "")) != "CustomEventSensor": continue
			var props: Dictionary = sensor.get("properties", {})
			allowed[event_identifier(str(props.get("event_name", "custom_event")))] = parameters(props).map(func(p): return p.name)
		for record in chain.get("sensors", []) + chain.get("controllers", []) + chain.get("actuators", []):
			var props: Dictionary = record.get("properties", {})
			if str(record.get("type", "")) == "EmitTypedSignal":
				var signal_errors := warnings(props)
				if not signal_errors.is_empty(): return "; ".join(signal_errors)
			if str(record.get("type", "")) == "CallCustomEventActuator":
				var errors := warnings(props)
				if not errors.is_empty(): return "; ".join(errors)
				var event_name := event_identifier(str(props.get("event_name", "custom_event")))
				if str(props.get("target", "self")).strip_edges().to_lower() in ["", "self"] and str(props.get("target_expression", "")).strip_edges() in ["", "self"] and events.has(event_name) and identity(props) != events[event_name]:
					return "Call Custom Event %s must use the event's parameter names, order, and types." % event_name
			for value in props.values():
				if not value is String: continue
				for match_result in reference.search_all(value):
					var event_name := match_result.get_string(1)
					if not allowed.has(event_name) or match_result.get_string(2) not in allowed[event_name]:
						return "Event argument %s.%s is used outside its event's execution path." % [event_name, match_result.get_string(2)]
	return ""
