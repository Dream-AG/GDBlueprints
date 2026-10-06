@tool
extends EditorDebuggerPlugin

var panel

func setup(value) -> void:
	panel = value

func _has_capture(prefix: String) -> bool:
	return prefix == "gdblueprints"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message != "gdblueprints:trace" or data.is_empty() or not data[0] is Dictionary:
		return false
	if is_instance_valid(panel): panel.call_deferred("_gdb_debug_trace", data[0])
	return true
