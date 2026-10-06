@tool
extends AcceptDialog

const Catalog = preload("res://addons/GDBlueprints/core/member_catalog.gd")
var entries: Array = []
var list: ItemList
var selected: Callable

func configure(target: Object, signal_mode: bool, choose: Callable) -> void:
	title = "Browse Signals" if signal_mode else "Browse Methods"
	selected = choose
	entries = Catalog.collect(target, signal_mode)
	get_ok_button().text = "Close"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 400)
	add_child(box)
	var help := Label.new()
	help.text = "Choose a declaration to create typed pins. Refresh after changing the script."
	if target == null: help.text = "Target cannot be resolved. Use Self, a relative NodePath, or a Scene Tree reference."
	box.add_child(help)
	var search := LineEdit.new()
	search.placeholder_text = "Search by name or parameter type"
	box.add_child(search)
	list = ItemList.new()
	list.custom_minimum_size.y = 300
	box.add_child(list)
	search.text_changed.connect(_filter)
	list.item_activated.connect(func(index):
		var entry: Dictionary = list.get_item_metadata(index)
		if entry.unsupported: return
		selected.call(entry)
		queue_free()
	)
	_filter("")
	popup_centered()
	search.grab_focus()

func _filter(query: String) -> void:
	list.clear()
	for entry in entries:
		var label := "%s(%s) -> %s%s" % [entry.name, entry.parameters, entry.return_type, " [variadic: use a fixed-signature helper]" if entry.unsupported else ""]
		if not query.is_empty() and not label.to_lower().contains(query.to_lower()): continue
		var index := list.add_item(label)
		list.set_item_metadata(index, entry)
		list.set_item_disabled(index, entry.unsupported)
