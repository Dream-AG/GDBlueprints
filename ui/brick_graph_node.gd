@tool
extends GraphNode

## Shared graph shell. Property controls are built by panel_property_helper.gd.
func _init() -> void:
	resizable = false
	draggable = true
	selectable = true
	# Slot zero is reserved for execution pins by the panel.
	add_child(VBoxContainer.new())
