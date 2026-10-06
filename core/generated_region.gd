@tool
extends RefCounted

## Saved-script compatibility is isolated here. New output always uses GDBlueprints.
const START := "# === GDBLUEPRINTS START ==="
const END := "# === GDBLUEPRINTS END ==="
const OLD_START := "# === LOGIC BRICKS START ==="
const OLD_END := "# === LOGIC BRICKS END ==="
const HASH_PREFIX := "# GDBlueprints generated SHA256: "

static func seal(body: String) -> String:
	var normalized := body.replace("\r\n", "\n").strip_edges()
	return HASH_PREFIX + normalized.sha256_text() + "\n" + normalized + "\n"

static func edit_error(source: String, start_marker: String = START, end_marker: String = END) -> String:
	source = normalize(source).replace("\r\n", "\n")
	var start := source.find(start_marker)
	var end := source.find(end_marker)
	if start < 0 or end < start: return ""
	var body := source.substr(start + start_marker.length(), end - start - start_marker.length()).strip_edges()
	if not body.begins_with(HASH_PREFIX): return "" # Adopt older releases on their first compile.
	var newline := body.find("\n")
	if newline < 0 or body.substr(newline + 1).strip_edges().sha256_text() != body.substr(HASH_PREFIX.length(), newline - HASH_PREFIX.length()):
		return "The generated region was edited outside the graph. No file was changed. Preserve your edits in a handwritten helper outside the markers, then restore the generated region from your last saved version before compiling."
	return ""

static func normalize(source: String) -> String:
	# Only replace complete marker lines, never user string literals or comments.
	var lines := source.split("\n")
	for index in lines.size():
		var line := lines[index].trim_suffix("\r")
		var suffix := "\r" if lines[index].ends_with("\r") else ""
		if line == OLD_START:
			lines[index] = START + suffix
		elif line == OLD_END:
			lines[index] = END + suffix
	return "\n".join(lines)
