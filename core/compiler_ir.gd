@tool
extends RefCounted

## Small, backwards-compatible compiler intermediate representation (IR).
##
## Existing nodes may keep returning raw strings from generate_code(). New nodes
## can optionally return a structured dictionary from generate_ir(). The manager
## renders this IR into the same code dictionary used by the legacy compiler.
## This is intentionally small in 0.4.7; it gives contributors a stable path that
## can grow without adding string-rewrite special cases to the central compiler.
##
## Example:
## {
##   "actuator": [
##     {"op":"assign", "target":"health", "value":"health - damage"},
##     {"op":"statement", "code":"print(health)"}
##   ]
## }

const STAGE_TO_CODE_KEY := {
	"sensor": "sensor_code",
	"controller": "controller_code",
	"actuator": "actuator_code",
	"ready": "ready_code",
	"physics": "physics_code",
	"process": "process_code",
}


static func render(ir: Dictionary) -> Dictionary:
	var generated: Dictionary = {}
	for stage in STAGE_TO_CODE_KEY.keys():
		if not ir.has(stage):
			continue
		var rendered := render_block(ir[stage])
		if not rendered.is_empty():
			generated[STAGE_TO_CODE_KEY[stage]] = rendered
	# Pass through structured arrays/strings the existing manager already knows.
	for passthrough in ["member_vars", "member_code", "helper_code", "signals"]:
		if ir.has(passthrough):
			generated[passthrough] = ir[passthrough]
	return generated


static func render_block(block: Variant, indent: String = "") -> String:
	if block is String:
		return "\n".join(Array(str(block).split("\n")).map(func(line): return indent + str(line)))
	if not (block is Array):
		return ""
	var lines: Array[String] = []
	for instruction in block:
		if instruction is String:
			lines.append(render_block(instruction, indent))
		elif instruction is Dictionary:
			_append_instruction(lines, instruction, indent)
	return "\n".join(lines)


static func _append_instruction(lines: Array[String], instruction: Dictionary, indent: String) -> void:
	var op := str(instruction.get("op", "statement"))
	match op:
		"statement":
			var code := str(instruction.get("code", ""))
			for line in code.split("\n"):
				lines.append(indent + line)
		"assign":
			lines.append("%s%s = %s" % [indent, str(instruction.get("target", "_value")), str(instruction.get("value", "null"))])
		"declare":
			var keyword := "var" if not bool(instruction.get("const", false)) else "const"
			lines.append("%s%s %s = %s" % [indent, keyword, str(instruction.get("name", "value")), str(instruction.get("value", "null"))])
		"call":
			var target := str(instruction.get("target", ""))
			var method := str(instruction.get("method", ""))
			var args: Array[String] = []
			for arg in instruction.get("args", []):
				args.append(str(arg))
			var prefix := target + "." if not target.is_empty() else ""
			lines.append("%s%s%s(%s)" % [indent, prefix, method, ", ".join(args)])
		"if":
			lines.append("%sif %s:" % [indent, str(instruction.get("condition", "false"))])
			var body := render_block(instruction.get("then", []), indent + "\t")
			if body.is_empty():
				lines.append(indent + "\tpass")
			else:
				lines.append_array(body.split("\n"))
			var else_block = instruction.get("else", [])
			if (else_block is Array or else_block is String) and not else_block.is_empty():
				lines.append(indent + "else:")
				var else_body := render_block(else_block, indent + "\t")
				lines.append_array(else_body.split("\n"))
		"return":
			var value := str(instruction.get("value", ""))
			lines.append(indent + ("return" if value.is_empty() else "return " + value))
		"await":
			lines.append("%sawait %s" % [indent, str(instruction.get("expression", "get_tree().process_frame"))])
		_:
			lines.append(indent + str(instruction.get("code", "# Unsupported BFG IR op: " + op)))
