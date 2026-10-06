@tool
extends GraphEdit

## Blueprint-like GraphEdit drop behavior.
## Right-click search and right-drag panning are handled by the panel's
## gui_input signal so GraphEdit keeps its native wheel/zoom handling.

signal graph_payload_dropped(data: Variant, local_position: Vector2)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		if data.has("bfg_variable"):
			return true
		# Godot editor SceneTree drags commonly expose selected node paths in "nodes".
		if data.has("nodes") or data.has("node") or data.has("object"):
			return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	graph_payload_dropped.emit(data, at_position)
