@tool
extends AcceptDialog

const Catalog = preload("res://addons/GDBlueprints/core/object_property_catalog.gd")

var _entries: Array = []
var _list: ItemList
var _get_button: Button
var _set_button: Button
var _status: Label
var _selected: Callable
var _mode: String

func configure(target: Object, selected: Callable, mode: String = "") -> void:
	title = "Browse Properties — " + (str(target.name) if target is Node else "Unresolved Target")
	_selected = selected
	_mode = mode
	_entries = Catalog.collect(target)
	get_ok_button().text = "Close"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(580, 420)
	add_child(box)
	var help := Label.new()
	help.text = "Choose a Godot property or script variable. Set changes it at runtime."
	if target == null:
		help.text = "Target cannot be resolved in the editor. Connect a Scene Tree reference\nor enter a path relative to this graph's node. Manual names remain available."
	box.add_child(help)
	var search := LineEdit.new()
	search.placeholder_text = "Search properties, types, or Blueprint variables…"
	search.clear_button_enabled = true
	box.add_child(search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 300
	box.add_child(_list)
	_status = Label.new()
	box.add_child(_status)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_get_button = Button.new()
	_get_button.text = "Get Property" if mode.is_empty() else "Choose Property"
	_get_button.visible = mode != "set"
	_get_button.pressed.connect(_choose.bind("get"))
	actions.add_child(_get_button)
	_set_button = Button.new()
	_set_button.text = "Set Property" if mode.is_empty() else "Choose Property"
	_set_button.visible = mode != "get"
	_set_button.pressed.connect(_choose.bind("set"))
	actions.add_child(_set_button)
	_list.item_selected.connect(func(_index): _update_actions())
	_list.item_activated.connect(func(_index): _choose("set" if _mode == "set" else "get"))
	search.text_changed.connect(_filter)
	search.text_submitted.connect(func(_query): _choose("set" if _mode == "set" else "get"))
	_filter("")
	popup_centered()
	search.grab_focus()

func _filter(query: String) -> void:
	_list.clear()
	for entry in _entries:
		var label := "%s : %s  [%s]%s" % [entry.name, entry.type, entry.source, " (read only)" if entry.read_only else ""]
		if not query.is_empty() and not label.to_lower().contains(query.to_lower()):
			continue
		var index := _list.add_item(label)
		_list.set_item_metadata(index, entry)
	_status.text = "No matching properties." if _list.item_count == 0 else "%d properties. Use typed value wires for non-String setters." % _list.item_count
	if _list.item_count > 0:
		_list.select(0)
	_update_actions()

func _update_actions() -> void:
	var indices := _list.get_selected_items()
	_get_button.disabled = indices.is_empty()
	_set_button.disabled = indices.is_empty() or bool(_list.get_item_metadata(indices[0]).read_only)

func _choose(operation: String) -> void:
	var indices := _list.get_selected_items()
	if indices.is_empty():
		return
	var entry: Dictionary = _list.get_item_metadata(indices[0])
	if operation == "set" and entry.read_only:
		return
	_selected.call(entry, operation)
	queue_free()
