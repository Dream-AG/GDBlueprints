@tool
extends Label

## Drag handle used by the Variables/Globals panel.
## Godot's editor docks can swallow the normal Control drag threshold, so this
## explicitly starts the drag once the left mouse has moved a few pixels.

var drag_payload: Dictionary = {}
var _pressed_at := Vector2.ZERO
var _left_down := false
var _drag_started := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _make_payload() -> Dictionary:
	return {"bfg_variable": drag_payload.duplicate(true)}

func _make_preview() -> Control:
	var preview := PanelContainer.new()
	var label := Label.new()
	label.text = "  %s  " % text
	label.add_theme_font_size_override("font_size", 14)
	preview.add_child(label)
	return preview

func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	var payload := _make_payload()
	set_drag_preview(_make_preview())
	return payload

func _gui_input(event: InputEvent) -> void:
	if drag_payload.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_left_down = event.pressed
		_drag_started = false
		_pressed_at = event.position
		return
	if event is InputEventMouseMotion and _left_down and not _drag_started:
		if event.position.distance_to(_pressed_at) >= 4.0:
			_drag_started = true
			force_drag(_make_payload(), _make_preview())
			accept_event()
