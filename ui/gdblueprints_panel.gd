@tool
extends VBoxContainer

## Main panel UI for the GDBlueprints plugin (bottom panel)
## Visual node graph editor for connecting blueprint nodes

const BrickGraphNode    = preload("res://addons/GDBlueprints/ui/brick_graph_node.gd")
const BlueprintGraphEdit = preload("res://addons/GDBlueprints/ui/blueprint_graph_edit.gd")
const VariableDragLabel = preload("res://addons/GDBlueprints/ui/variable_drag_label.gd")
const VariableUtils = preload("res://addons/GDBlueprints/core/blueprint_variable_utils.gd")
const BrickRegistry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const DocumentationHelper = preload("res://addons/GDBlueprints/core/documentation_helper.gd")
const PinTypeRegistry = preload("res://addons/GDBlueprints/core/pin_type_registry.gd")
const GraphSchema = preload("res://addons/GDBlueprints/core/graph_schema.gd")

var manager = null
var editor_interface = null
var plugin = null  # Reference to the EditorPlugin (for autoload registration)
var current_node: Node = null
var current_brick_domain: String = ""
var _clipboard_graph: Dictionary = {}  # Stored graph data for copy/paste (whole node)
var _clipboard_vars: Array = []  # Stored variables for copy/paste (whole node)
var _selection_clipboard: Dictionary = {}  # Selected bricks only — survives node switching
var is_locked: bool = false  # Lock to prevent losing current_node on selection change
var _instance_override: bool = false  # Allow editing instanced nodes when true
var _instance_panel: PanelContainer = null  # The instance warning/choice panel
var _script_required_overlay: CenterContainer = null  # Blocks GDBlueprints until the node has a script
var _script_required_desc: Label = null
var _script_parent_warning: Label = null
var _script_select_parent_button: Button = null

var node_info_label: Label
var add_script_button: Button
var lock_button: Button
var _template_save_dialog: FileDialog
var _template_load_dialog: FileDialog
var _graph_image_dialog: FileDialog
var options_menu: PopupMenu
var _popout_button: Button         # Toggles floating window
var _popout_window: Window = null  # The detached floating window (null when docked)
var _main_hsplit: HSplitContainer  # The bottom-panel hsplit (kept as member for re-docking)
var _toolbar_separator: HSeparator  # Separator above the toolbar (moved with toolbar)
var _toolbar: HBoxContainer         # Bottom toolbar with Add Frame / Apply Code (moved on popout)
var _apply_code_button: Button = null
var _frame_graph_button: Button = null
var _has_unapplied_changes: bool = false
var _dirty_indicator_token: int = 0
var _apply_validation_active: bool = false
var _suppress_dirty_mark: bool = false
var _instructions_label: Label      # "Select a node" label (moved with graph area)
var graph_edit: GraphEdit
var add_menu: PopupMenu
var sensors_menu: PopupMenu
var controllers_menu: PopupMenu
var actuators_menu: PopupMenu
var actuator_submenus: Dictionary = {}  # name -> PopupMenu, for sub-submenu ID lookup
var _brick_menu_context_popup: PopupMenu = null
var _brick_menu_context_class: String = ""
var _brick_menu_context_domain: String = ""
var next_node_id: int = 0
var last_mouse_position: Vector2 = Vector2.ZERO
var _variable_drop_menu: PopupMenu = null
var _pin_context_popup: PopupMenu = null
var _pin_context_node: GraphNode = null
var _pin_context_port: int = -1
var _pin_context_is_output: bool = false
var _data_drag_popup: PopupMenu = null
var _pending_variable_drop: Dictionary = {}
var _pending_variable_drop_position: Vector2 = Vector2.ZERO
var _right_pan_active: bool = false
var _right_pan_dragged: bool = false
var _right_pan_press_position: Vector2 = Vector2.ZERO
var _pending_connection_from_node: String = ""
var _pending_connection_from_port: int = -1
var _pending_connection_to_node: String = ""
var _pending_connection_to_port: int = -1
var _pending_connection_release_position: Vector2 = Vector2.ZERO

# Search popup (lazy-created)

# Side panel (vertical nav: Variables, Globals, Frames, States)
var side_panel: PanelContainer          # Outer wrapper added to _main_hsplit
var _side_hbox: HBoxContainer           # nav buttons | content stack
var _side_nav_panel: PanelContainer      # wrapper for the nav rail
var _side_nav: VBoxContainer            # left column of nav buttons
var _side_content_scroll: ScrollContainer # right content column
var _side_stack: VBoxContainer          # right column — only one child visible at a time
var _collapse_button: Button            # collapses to icon rail only
var _side_collapsed: bool = false
var _expanded_side_width: int = 360
var _active_tab_index: int = 0          # 0=Script Variables, 1=Globals, 2=Frames, 3=Customize
var _nav_buttons: Array[Button] = []    # Kept so we can update active highlight
var variables_panel: VBoxContainer
var variables_list: VBoxContainer
var variables_data: Array[Dictionary] = []  # Local variables for this node
var global_vars_data: Array[Dictionary] = []  # Global variables (scene-wide, stored on scene root)
var global_vars_panel: VBoxContainer  # Tab panel for global variables
var global_vars_list: VBoxContainer  # UI container for the globals section
var frames_panel: VBoxContainer
var frames_list: ItemList
var states_panel: VBoxContainer
var customize_panel: VBoxContainer
var states_data: Array[Dictionary] = []
var states_list: VBoxContainer
var state_debug_button: Button
var frame_settings_container: VBoxContainer
var selected_frame: GraphFrame = null
var _reference_helper = preload("res://addons/GDBlueprints/ui/panel_reference_helper.gd").new()
var _frames_helper = preload("res://addons/GDBlueprints/ui/panel_frames_helper.gd").new()
var _search_helper = preload("res://addons/GDBlueprints/ui/panel_search_helper.gd").new()
var _clipboard_helper = preload("res://addons/GDBlueprints/ui/panel_clipboard_helper.gd").new()
var _graph_helper = preload("res://addons/GDBlueprints/ui/panel_graph_helper.gd").new()
var _property_helper = preload("res://addons/GDBlueprints/ui/panel_property_helper.gd").new()
var _script_rebuild_helper = preload("res://addons/GDBlueprints/ui/panel_script_rebuild_helper.gd").new()

const DEFAULT_BRICK_SENSOR_COLOR := Color("038AA8")
const DEFAULT_BRICK_CONTROLLER_COLOR := Color("6703A1")
const DEFAULT_BRICK_ACTUATOR_COLOR := Color("B80449")
const DEFAULT_BRICK_HEADER_TEXT_COLOR := Color("FFFFFF")
const DEFAULT_BRICK_BODY_COLOR := Color("202020")
const DEFAULT_GRAPH_BACKGROUND_COLOR := Color("111111")
const EDITOR_COLOR_SETTING_PREFIX := "GDBlueprints/editor_colors/"

var _brick_sensor_color := DEFAULT_BRICK_SENSOR_COLOR
var _brick_controller_color := DEFAULT_BRICK_CONTROLLER_COLOR
var _brick_actuator_color := DEFAULT_BRICK_ACTUATOR_COLOR
var _brick_header_text_color := DEFAULT_BRICK_HEADER_TEXT_COLOR
var _brick_body_color := DEFAULT_BRICK_BODY_COLOR
var _graph_background_color := DEFAULT_GRAPH_BACKGROUND_COLOR
var _customize_color_pickers: Dictionary = {}


func _init() -> void:
	# Set minimum size for the bottom panel
	custom_minimum_size = Vector2(0, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_reference_helper.setup(self)
	_search_helper.setup(self)
	_clipboard_helper.setup(self)
	_graph_helper.setup(self)
	_property_helper.setup(self)
	_script_rebuild_helper.setup(self)

	# Create header
	var header_hbox = HBoxContainer.new()
	add_child(header_hbox)

	var documentation_button = Button.new()
	documentation_button.text = "Documentation"
	documentation_button.tooltip_text = "Open the bundled GDBlueprints documentation in your web browser"
	documentation_button.pressed.connect(_on_documentation_pressed)
	header_hbox.add_child(documentation_button)

	var title_label = Label.new()
	title_label.text = "GDBlueprints - Node Graph"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title_label.get_theme_font("bold", "EditorFonts")
	if title_font:
		title_label.add_theme_font_override("font", title_font)
	header_hbox.add_child(title_label)

	node_info_label = Label.new()
	node_info_label.text = "No node selected"
	header_hbox.add_child(node_info_label)

	# Lock button to prevent losing selection
	lock_button = Button.new()
	lock_button.text = "🔓"  # Unlocked icon
	lock_button.tooltip_text = "Lock selection (prevents panel from changing when clicking elsewhere)"
	lock_button.pressed.connect(_on_lock_toggled)
	header_hbox.add_child(lock_button)

	_create_template_dialogs()

	_popout_button = Button.new()
	_popout_button.text = "⧉"
	_popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"
	_popout_button.pressed.connect(_on_popout_pressed)
	header_hbox.add_child(_popout_button)

	# Separator
	var separator1 = HSeparator.new()
	add_child(separator1)

	# Create horizontal split: graph on left, variables on right
	_main_hsplit = HSplitContainer.new()
	_main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_hsplit.split_offset = -360  # Keep variable controls, including delete, visible by default
	add_child(_main_hsplit)

	# GraphEdit for visual node connections (LEFT SIDE)
	graph_edit = BlueprintGraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.show_zoom_label = true
	graph_edit.minimap_enabled = true
	graph_edit.minimap_size = Vector2(200, 150)

	_create_script_required_overlay()

	# Enable panning - allow dragging the canvas
	graph_edit.panning_scheme = GraphEdit.SCROLL_ZOOMS  # Mouse wheel zooms, drag pans

	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.connection_to_empty.connect(_on_connection_to_empty)
	graph_edit.connection_from_empty.connect(_on_connection_from_empty)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.graph_payload_dropped.connect(_on_graph_payload_dropped)
	graph_edit.gui_input.connect(_on_graph_edit_input)
	graph_edit.visible = false  # Hidden until node selected
	_main_hsplit.add_child(graph_edit)

	# Side Panel (RIGHT SIDE) - Tabbed: Variables, Globals, Frames
	_create_side_panel()
	_main_hsplit.add_child(side_panel)

	# Create add node menu
	_create_add_menu()

	# Instructions label (shown when graph is hidden)
	_instructions_label = Label.new()
	_instructions_label.name = "InstructionsLabel"
	_instructions_label.text = "👆 Select a 3D, 2D, or UI node, attach a GDScript, then build your Blueprint graph"
	_instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instructions_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instructions_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_instructions_label.add_theme_font_size_override("font_size", 16)
	add_child(_instructions_label)

	# Toolbar
	_toolbar_separator = HSeparator.new()
	add_child(_toolbar_separator)

	_toolbar = HBoxContainer.new()
	add_child(_toolbar)

	var help_label = Label.new()
	help_label.text = "  Right-click / type: Search nodes | Drag: Move | Right-drag: Pan | Drag Variables/Scene Nodes into graph | Scroll: Zoom"
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(help_label)

	var add_frame_button = Button.new()
	add_frame_button.text = "Add Frame"
	add_frame_button.pressed.connect(_on_add_frame_pressed)
	_toolbar.add_child(add_frame_button)

	_apply_code_button = Button.new()
	_apply_code_button.text = "Compile Blueprint → GDScript"
	_apply_code_button.pressed.connect(_on_apply_code_pressed)
	_toolbar.add_child(_apply_code_button)


func _ready() -> void:
	_load_editor_customization()
	_install_graph_menu_buttons()


func _install_graph_menu_buttons() -> void:
	if _frame_graph_button != null or graph_edit == null:
		return
	if not graph_edit.has_method("get_menu_hbox"):
		return
	var menu = graph_edit.call("get_menu_hbox")
	if not (menu is HBoxContainer):
		return
	_frame_graph_button = Button.new()
	_frame_graph_button.text = "Frame All"
	_frame_graph_button.tooltip_text = "Center and zoom the graph so all Blueprint nodes are visible."
	_frame_graph_button.focus_mode = Control.FOCUS_NONE
	_frame_graph_button.pressed.connect(_on_frame_graph_pressed)
	menu.add_child(_frame_graph_button)


func _on_frame_graph_pressed() -> void:
	_frame_graph_contents(true)


func _frame_graph_contents(user_requested: bool = false) -> void:
	if graph_edit == null or not graph_edit.visible:
		return
	var bounds := Rect2()
	var has_bounds := false
	for child in graph_edit.get_children():
		if not (child is GraphNode or child is GraphFrame):
			continue
		# Ignore hidden/zero-size helper elements and warning overlays.
		if child is GraphNode and str(child.name).begins_with("__bfg_warning_"):
			continue
		var item_size: Vector2 = child.size
		if item_size.x <= 1.0 or item_size.y <= 1.0:
			item_size = child.get_combined_minimum_size()
		var rect := Rect2(child.position_offset, item_size)
		bounds = rect if not has_bounds else bounds.merge(rect)
		has_bounds = true
	if not has_bounds:
		graph_edit.zoom = 1.0
		graph_edit.scroll_offset = Vector2.ZERO
		return
	var padding := Vector2(100.0, 80.0)
	var content_size := bounds.size + padding * 2.0
	var viewport_size := graph_edit.size
	if viewport_size.x <= 10.0 or viewport_size.y <= 10.0:
		return
	var fit_zoom := minf(viewport_size.x / maxf(content_size.x, 1.0), viewport_size.y / maxf(content_size.y, 1.0))
	# Do not zoom in beyond 100% automatically. A manual Frame All is allowed to
	# use the same behavior so text stays readable and predictable.
	fit_zoom = clampf(fit_zoom, graph_edit.zoom_min, minf(1.0, graph_edit.zoom_max))
	graph_edit.zoom = fit_zoom
	var center := bounds.get_center()
	graph_edit.scroll_offset = center - (viewport_size / maxf(graph_edit.zoom, 0.001)) * 0.5
	if user_requested:
		graph_edit.queue_redraw()


func _on_documentation_pressed() -> void:
	DocumentationHelper.open_home()


func _on_add_script_pressed() -> void:
	if not current_node or current_node.get_script():
		_update_ui()
		return

	var scene_root = editor_interface.get_edited_scene_root() if editor_interface else null
	var scene_dir = scene_root.scene_file_path.get_base_dir() if scene_root and not scene_root.scene_file_path.is_empty() else "res://"
	var base_name = current_node.name.to_snake_case().validate_filename()
	if base_name.is_empty():
		base_name = "blueprint_node"

	var script_path = scene_dir.path_join(base_name + ".gd")
	var suffix = 2
	while FileAccess.file_exists(script_path):
		script_path = scene_dir.path_join("%s_%d.gd" % [base_name, suffix])
		suffix += 1

	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		push_error("GDBlueprints: Could not create script at %s" % script_path)
		return
	file.store_string("extends %s\n" % current_node.get_class())
	file.close()

	if editor_interface:
		editor_interface.get_resource_filesystem().update_file(script_path)
	var script = ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if not script:
		push_error("GDBlueprints: Script was created but could not be loaded: %s" % script_path)
		return

	current_node.set_script(script)
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()
	_update_ui()


func _create_template_dialogs() -> void:
	_template_save_dialog = FileDialog.new()
	_template_save_dialog.title = "Save GDBlueprints Template"
	_template_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_template_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_template_save_dialog.filters = PackedStringArray(["*.gdbtemplate ; GDBlueprints Template"])
	_template_save_dialog.current_file = "blueprint.gdbtemplate"
	_template_save_dialog.file_selected.connect(_on_template_save_path_selected)
	add_child(_template_save_dialog)

	_template_load_dialog = FileDialog.new()
	_template_load_dialog.title = "Load GDBlueprints Template"
	_template_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_template_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_template_load_dialog.filters = PackedStringArray(["*.gdbtemplate ; GDBlueprints Template", "*.lbtemplate ; Legacy GDBlueprints Template"])
	_template_load_dialog.file_selected.connect(_on_template_load_path_selected)
	add_child(_template_load_dialog)

	_graph_image_dialog = FileDialog.new()
	_graph_image_dialog.title = "Export GDBlueprints Graph Image"
	_graph_image_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_graph_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_graph_image_dialog.filters = PackedStringArray(["*.png ; PNG Image"])
	_graph_image_dialog.current_file = "blueprints_for_godot_graph.png"
	_graph_image_dialog.file_selected.connect(_on_graph_image_path_selected)
	add_child(_graph_image_dialog)


func _on_save_template_pressed() -> void:
	if not current_node:
		push_warning("GDBlueprints: Select a node before saving a template.")
		return
	_template_save_dialog.popup_centered_ratio(0.65)


func _on_load_template_pressed() -> void:
	if not current_node:
		push_warning("GDBlueprints: Select a node before loading a template.")
		return
	if _is_part_of_instance(current_node):
		push_warning("GDBlueprints: Cannot load a template into an instanced node.")
		return
	_template_load_dialog.popup_centered_ratio(0.65)


func _on_template_save_path_selected(path: String) -> void:
	_clipboard_helper.save_template_to_file(path)


func _on_template_load_path_selected(path: String) -> void:
	await _clipboard_helper.load_template_from_file(path)

func _create_add_menu() -> void:
	add_menu = PopupMenu.new()
	add_menu.name = "AddMenu"
	add_child(add_menu)

	sensors_menu = PopupMenu.new()
	sensors_menu.name = "SensorsMenu"
	add_menu.add_child(sensors_menu)
	sensors_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(sensors_menu)

	controllers_menu = PopupMenu.new()
	controllers_menu.name = "ControllersMenu"
	add_menu.add_child(controllers_menu)
	controllers_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(controllers_menu)

	actuators_menu = PopupMenu.new()
	actuators_menu.name = "ActuatorsMenu"
	add_menu.add_child(actuators_menu)
	actuators_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(actuators_menu)

	add_menu.add_submenu_item("Triggers", "SensorsMenu", 0)
	add_menu.add_submenu_item("Flow", "ControllersMenu", 1)
	add_menu.add_submenu_item("Actions", "ActuatorsMenu", 2)
	_apply_add_menu_colors()
	add_menu.add_separator()
	add_menu.add_item("🔍 Search…", 4)
	add_menu.add_item("Reroute", 3)
	add_menu.add_separator()

	# Context menu shown after right-clicking a specific brick entry in one of
	# the Add submenus. Keep this separate from the Add menu itself so a right
	# click never adds the brick or opens the browser immediately.
	_brick_menu_context_popup = PopupMenu.new()
	_brick_menu_context_popup.name = "BrickMenuDocumentationContext"
	_brick_menu_context_popup.add_item("View Documentation", 0)
	_brick_menu_context_popup.id_pressed.connect(_on_brick_menu_context_id_pressed)
	add_child(_brick_menu_context_popup)

	options_menu = PopupMenu.new()
	options_menu.name = "OptionsMenu"
	add_menu.add_child(options_menu)
	options_menu.add_item("Copy", 100)
	options_menu.add_item("Paste", 101)
	options_menu.add_item("Duplicate", 102)
	options_menu.add_separator()
	options_menu.add_item("Save Template", 103)
	options_menu.add_item("Load Template", 104)
	options_menu.add_separator()
	options_menu.add_item("Export Graph Image", 105)
	options_menu.add_item("Rebuild from Script", 106)
	options_menu.add_item("Clear Bricks", 107)
	options_menu.id_pressed.connect(_on_options_menu_id_pressed)
	add_menu.add_submenu_item("Options", "OptionsMenu", 7)
	add_menu.id_pressed.connect(_on_main_menu_id_pressed)

	_refresh_add_menu_from_registry(false)


func _refresh_add_menu_from_registry(force_rescan: bool = false) -> void:
	# Rebuild the brick submenus from the registry instead of relying on
	# hard-coded menu IDs. This keeps the right-click menu in sync with any
	# .gd files dropped into the bricks/sensors, bricks/controllers, or
	# bricks/actuators folders.
	if force_rescan:
		BrickRegistry.refresh()
	else:
		BrickRegistry.ensure_scanned()

	sensors_menu.clear()
	controllers_menu.clear()
	actuators_menu.clear()

	for submenu in actuator_submenus.values():
		if is_instance_valid(submenu):
			actuators_menu.remove_child(submenu)
			submenu.queue_free()
	actuator_submenus.clear()

	var domain := current_brick_domain
	_populate_brick_menu_flat(sensors_menu, BrickRegistry.get_bricks_by_type("sensor", domain))
	_populate_brick_menu_flat(controllers_menu, BrickRegistry.get_bricks_by_type("controller", domain))
	_populate_actuator_menu(BrickRegistry.get_bricks_by_type("actuator", domain))


func _enable_brick_menu_doc_right_click(menu: PopupMenu) -> void:
	# PopupMenu activates brick entries with a left click. Listen to the popup
	# window as well so a right click can offer a documentation-only context
	# action without adding the brick.
	menu.window_input.connect(_on_brick_menu_window_input.bind(menu))


func _on_brick_menu_window_input(event: InputEvent, menu: PopupMenu) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return

	# PopupMenu focuses the item under the pointer. Every actual brick entry
	# stores its registered class in metadata; category/submenu rows do not.
	var item_index: int = menu.get_focused_item()
	if item_index < 0 or item_index >= menu.get_item_count():
		return
	if menu.is_item_disabled(item_index) or menu.is_item_separator(item_index):
		return

	var metadata: Variant = menu.get_item_metadata(item_index)
	if not metadata is Dictionary:
		return
	var brick_class: String = str(metadata.get("class", ""))
	if brick_class.is_empty():
		return

	_brick_menu_context_class = brick_class
	_brick_menu_context_domain = current_brick_domain

	# Close the Add-menu stack, then leave a small context menu at the pointer.
	# The browser is opened only if the user explicitly chooses View Documentation.
	menu.hide()
	if is_instance_valid(add_menu):
		add_menu.hide()
	if is_instance_valid(_brick_menu_context_popup):
		_brick_menu_context_popup.position = DisplayServer.mouse_get_position()
		_brick_menu_context_popup.popup()


func _on_brick_menu_context_id_pressed(id: int) -> void:
	if id != 0 or _brick_menu_context_class.is_empty():
		return
	DocumentationHelper.open_brick(_brick_menu_context_class, _brick_menu_context_domain)
	_brick_menu_context_class = ""
	_brick_menu_context_domain = ""


func _populate_brick_menu_flat(menu: PopupMenu, bricks: Array) -> void:
	for info in bricks:
		var id := int(info.get("menu_id", 0))
		var display_name := str(info.get("name", info.get("class", "Brick")))
		if str(info.get("type", "")) == "controller":
			if display_name == "Controller":
				display_name = "Gate"
			elif display_name == "Script Controller":
				display_name = "Script Gate"
		menu.add_item(display_name, id)
		var idx := menu.get_item_index(id)
		menu.set_item_metadata(idx, {"type": str(info.get("type", "")), "class": str(info.get("class", ""))})
		var description := str(info.get("description", ""))
		if not description.is_empty():
			menu.set_item_tooltip(idx, description)


func _populate_actuator_menu(bricks: Array) -> void:
	# UI graphs also expose the full common action set; categorize every domain.
	var groups: Dictionary = {}
	var group_order: Array = []
	for info in bricks:
		var category := str(info.get("category", "General"))
		if category.is_empty():
			category = "General"
		if not groups.has(category):
			groups[category] = []
			group_order.append(category)
		groups[category].append(info)

	for category in group_order:
		var group_items: Array = groups[category]
		if group_items.size() == 1 and category == "General":
			_populate_brick_menu_flat(actuators_menu, group_items)
		else:
			var submenu = PopupMenu.new()
			var submenu_name = "ActuatorSub_" + category.replace(" ", "_").replace("/", "_")
			submenu.name = submenu_name
			actuators_menu.add_child(submenu)
			submenu.id_pressed.connect(_on_add_menu_item_selected)
			_enable_brick_menu_doc_right_click(submenu)
			actuator_submenus[submenu_name] = submenu
			_populate_brick_menu_flat(submenu, group_items)
			actuators_menu.add_submenu_item(category, submenu_name)


func _create_side_panel() -> void:
	# Outer container — replaces the old TabContainer
	side_panel = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2.ZERO
	side_panel.size_flags_horizontal = Control.SIZE_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.visible = false  # Hidden until node selected

	# Horizontal split: Blender-like icon rail | content column
	_side_hbox = HBoxContainer.new()
	_side_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(_side_hbox)

	# Left nav column
	_side_nav_panel = PanelContainer.new()
	_side_nav_panel.custom_minimum_size = Vector2.ZERO
	_side_nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_hbox.add_child(_side_nav_panel)

	_side_nav = VBoxContainer.new()
	_side_nav.add_theme_constant_override("separation", 8)
	_side_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_nav.alignment = BoxContainer.ALIGNMENT_BEGIN
	_side_nav_panel.add_child(_side_nav)

	_collapse_button = Button.new()
	_collapse_button.flat = true
	_collapse_button.focus_mode = Control.FOCUS_NONE
	_collapse_button.custom_minimum_size = Vector2(32, 32)
	_collapse_button.tooltip_text = "Collapse to icon rail"
	_collapse_button.expand_icon = false
	_collapse_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_collapse_button.text = "<"
	_collapse_button.pressed.connect(_toggle_side_panel_collapsed)
	_side_nav.add_child(_collapse_button)

	# Right content stack (inside a scroll container so the split can get very thin)
	_side_content_scroll = ScrollContainer.new()
	_side_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_side_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_side_hbox.add_child(_side_content_scroll)

	_side_stack = VBoxContainer.new()
	_side_stack.add_theme_constant_override("separation", 8)
	_side_stack.custom_minimum_size = Vector2.ZERO
	_side_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_content_scroll.add_child(_side_stack)

	# Build the content panels. Script Variables and Global Variables are
	# deliberately separate again: globals are a different lifetime/scope in
	# Godot and mixing both lists made the sidebar too dense. States remains
	# supported for old graphs but is not a top-level workflow tab.
	_create_variables_tab()
	_create_global_variables_tab()
	_create_frames_tab()
	_create_states_tab()
	_create_customize_tab()

	_side_stack.add_child(variables_panel)
	_side_stack.add_child(global_vars_panel)
	_side_stack.add_child(frames_panel)
	_side_stack.add_child(customize_panel)
	# Keep the legacy tab owned even though it is not in the navigation.
	_side_stack.add_child(states_panel)
	states_panel.hide()

	# Build nav buttons (one per visible panel).
	var tab_defs = [
		{"tooltip": "Script Variables", "icon": "LocalVariable", "fallback": "V"},
		{"tooltip": "Global Variables", "icon": "Environment", "fallback": "G"},
		{"tooltip": "Frames", "icon": "KeyEasedSelected", "fallback": "F"},
	]
	for i in range(tab_defs.size()):
		var btn = Button.new()
		btn.flat = false
		btn.toggle_mode = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(32, 32)
		btn.tooltip_text = str(tab_defs[i]["tooltip"])
		btn.text = str(tab_defs[i]["fallback"])
		btn.expand_icon = false
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.theme_type_variation = "FlatButton"
		btn.set_meta("icon_name", str(tab_defs[i]["icon"]))
		btn.set_meta("fallback_text", str(tab_defs[i]["fallback"]))
		var idx = i  # capture for closure
		btn.pressed.connect(func(): _on_side_tab_pressed(idx))
		_side_nav.add_child(btn)
		_nav_buttons.append(btn)

	# Keep editor customization at the bottom of the rail.
	var nav_spacer = Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_nav.add_child(nav_spacer)

	var customize_btn = Button.new()
	customize_btn.flat = false
	customize_btn.toggle_mode = false
	customize_btn.focus_mode = Control.FOCUS_NONE
	customize_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	customize_btn.custom_minimum_size = Vector2(32, 32)
	customize_btn.tooltip_text = "Customize Editor"
	customize_btn.text = "C"
	customize_btn.expand_icon = false
	customize_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	customize_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	customize_btn.theme_type_variation = "FlatButton"
	customize_btn.set_meta("icon_name", "Color")
	customize_btn.set_meta("fallback_text", "C")
	customize_btn.pressed.connect(func(): _on_side_tab_pressed(3))
	_side_nav.add_child(customize_btn)
	_nav_buttons.append(customize_btn)

	_apply_side_tab_icons()
	_update_collapse_button_icon()

	# Show first tab by default
	_select_side_tab(0)


func _on_side_tab_pressed(index: int) -> void:
	if _side_collapsed:
		_set_side_panel_collapsed(false)
	_select_side_tab(index)


func _select_side_tab(index: int) -> void:
	_active_tab_index = index
	for i in range(_side_stack.get_child_count()):
		_side_stack.get_child(i).visible = (i == index)
	# Update button highlight
	for i in range(_nav_buttons.size()):
		var btn = _nav_buttons[i]
		if i == index:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			var active_sb = _make_active_nav_stylebox()
			btn.add_theme_stylebox_override("normal", active_sb)
			btn.add_theme_stylebox_override("hover", active_sb)
			btn.add_theme_stylebox_override("pressed", active_sb)
			btn.add_theme_stylebox_override("focus", active_sb)
		else:
			btn.remove_theme_color_override("font_color")
			var inactive_sb = _make_inactive_nav_stylebox()
			btn.add_theme_stylebox_override("normal", inactive_sb)
			btn.add_theme_stylebox_override("hover", inactive_sb)
			btn.add_theme_stylebox_override("pressed", inactive_sb)
			btn.add_theme_stylebox_override("focus", inactive_sb)


func _toggle_side_panel_collapsed() -> void:
	_set_side_panel_collapsed(not _side_collapsed)


func _set_side_panel_collapsed(collapsed: bool) -> void:
	if _side_collapsed == collapsed:
		return
	if collapsed:
		_expanded_side_width = maxi(_expanded_side_width, int(side_panel.size.x))
	_side_collapsed = collapsed
	if _side_content_scroll:
		_side_content_scroll.visible = not collapsed
	_update_collapse_button_icon()
	call_deferred("_apply_side_collapse_split")


func _apply_side_collapse_split() -> void:
	if not _main_hsplit or not side_panel or not _side_nav_panel:
		return
	if _side_collapsed:
		var rail_width := maxi(int(_side_nav_panel.size.x), 40)
		_main_hsplit.split_offset = -rail_width
	else:
		var target_width := maxi(_expanded_side_width, 140)
		_main_hsplit.split_offset = -target_width


func _update_collapse_button_icon() -> void:
	if not _collapse_button:
		return
	var icon_name := "Forward" if _side_collapsed else "Back"
	var fallback := ">" if _side_collapsed else "<"
	var icon = null
	if has_theme_icon(icon_name, "EditorIcons"):
		icon = get_theme_icon(icon_name, "EditorIcons")
	_collapse_button.icon = icon
	_collapse_button.text = "" if icon != null else fallback
	_collapse_button.tooltip_text = "Expand panel" if _side_collapsed else "Collapse to icon rail"


func _make_active_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.45, 0.75, 0.85)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _make_inactive_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	return sb


func _make_hover_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _apply_side_tab_icons() -> void:
	if _nav_buttons.is_empty():
		return
	for btn in _nav_buttons:
		if not is_instance_valid(btn):
			continue
		var icon_name = str(btn.get_meta("icon_name", ""))
		var fallback_text = str(btn.get_meta("fallback_text", ""))
		var icon = null
		if has_theme_icon(icon_name, "EditorIcons"):
			icon = get_theme_icon(icon_name, "EditorIcons")
		btn.icon = icon
		btn.text = "" if icon != null else fallback_text


func _apply_side_panel_visibility() -> void:
	if not side_panel:
		return
	side_panel.visible = graph_edit.visible
	if graph_edit.visible:
		call_deferred("_apply_side_collapse_split")


func _generate_global_var_id() -> String:
	return "lb_global_%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]


func _ensure_global_var_ids() -> void:
	var used_ids: Dictionary = {}
	for i in range(global_vars_data.size()):
		var var_data = global_vars_data[i]
		var gid = str(var_data.get("id", ""))
		if gid.is_empty() or used_ids.has(gid):
			gid = _generate_global_var_id() + "_%d" % i
			global_vars_data[i]["id"] = gid
		used_ids[gid] = true


func _get_global_usage_map() -> Dictionary:
	if not current_node or not current_node.has_meta("blueprints_for_godot_global_usage"):
		return {}
	var usage = current_node.get_meta("blueprints_for_godot_global_usage")
	return usage.duplicate(true) if usage is Dictionary else {}


func _is_global_used_in_current_script(var_data: Dictionary) -> bool:
	var gid = str(var_data.get("id", ""))
	if gid.is_empty():
		return false
	return bool(_get_global_usage_map().get(gid, false))


func _set_global_used_in_current_script(index: int, enabled: bool) -> void:
	if not current_node or index < 0 or index >= global_vars_data.size():
		return
	_ensure_global_var_ids()
	var gid = str(global_vars_data[index].get("id", ""))
	if gid.is_empty():
		return
	var usage = _get_global_usage_map()
	usage[gid] = enabled
	current_node.set_meta("blueprints_for_godot_global_usage", usage)
	_mark_scene_modified()


func _create_customize_tab() -> void:
	customize_panel = VBoxContainer.new()
	customize_panel.add_theme_constant_override("separation", 8)
	customize_panel.name = "Customize"
	customize_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = "Customize Editor"
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	customize_panel.add_child(title)

	var hint = Label.new()
	hint.text = "Colors are saved for this editor user."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hint.add_theme_font_size_override("font_size", 10)
	customize_panel.add_child(hint)

	customize_panel.add_child(HSeparator.new())
	_add_customize_color_row("Trigger Header", "sensor_header", _brick_sensor_color)
	_add_customize_color_row("Gate Header", "controller_header", _brick_controller_color)
	_add_customize_color_row("Action Header", "actuator_header", _brick_actuator_color)
	_add_customize_color_row("Header Text", "header_text", _brick_header_text_color)
	_add_customize_color_row("Brick Body", "brick_body", _brick_body_color)
	_add_customize_color_row("Graph Background", "graph_background", _graph_background_color)

	customize_panel.add_child(HSeparator.new())
	var reset_button = Button.new()
	reset_button.text = "Reset Colors"
	reset_button.tooltip_text = "Restore the default GDBlueprints editor colors"
	reset_button.pressed.connect(_reset_editor_customization)
	customize_panel.add_child(reset_button)


func _add_customize_color_row(label_text: String, key: String, color: Color) -> void:
	var row = HBoxContainer.new()
	customize_panel.add_child(row)

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var picker = ColorPickerButton.new()
	picker.color = color
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(72, 28)
	picker.tooltip_text = "Change " + label_text.to_lower()
	picker.color_changed.connect(_on_customize_color_changed.bind(key))
	row.add_child(picker)
	_customize_color_pickers[key] = picker


func _on_customize_color_changed(color: Color, key: String) -> void:
	_set_customization_color(key, color)
	_save_editor_customization_color(key, color)
	_apply_editor_customization()


func _set_customization_color(key: String, color: Color) -> void:
	match key:
		"sensor_header": _brick_sensor_color = color
		"controller_header": _brick_controller_color = color
		"actuator_header": _brick_actuator_color = color
		"header_text": _brick_header_text_color = color
		"brick_body": _brick_body_color = color
		"graph_background": _graph_background_color = color


func _get_blueprints_for_godot_editor_settings():
	if editor_interface and editor_interface.has_method("get_editor_settings"):
		return editor_interface.get_editor_settings()
	return null


func _load_editor_customization() -> void:
	var settings = _get_blueprints_for_godot_editor_settings()
	if settings:
		for key in ["sensor_header", "controller_header", "actuator_header", "header_text", "brick_body", "graph_background"]:
			var setting_name = EDITOR_COLOR_SETTING_PREFIX + key
			if settings.has_setting(setting_name):
				var saved = settings.get_setting(setting_name)
				if saved is Color:
					_set_customization_color(key, saved)
	_sync_customize_color_pickers()
	_apply_editor_customization()


func _save_editor_customization_color(key: String, color: Color) -> void:
	var settings = _get_blueprints_for_godot_editor_settings()
	if settings:
		settings.set_setting(EDITOR_COLOR_SETTING_PREFIX + key, color)


func _sync_customize_color_pickers() -> void:
	var colors = {
		"sensor_header": _brick_sensor_color,
		"controller_header": _brick_controller_color,
		"actuator_header": _brick_actuator_color,
		"header_text": _brick_header_text_color,
		"brick_body": _brick_body_color,
		"graph_background": _graph_background_color,
	}
	for key in colors:
		var picker = _customize_color_pickers.get(key)
		if is_instance_valid(picker):
			picker.color = colors[key]


func _reset_editor_customization() -> void:
	var defaults = {
		"sensor_header": DEFAULT_BRICK_SENSOR_COLOR,
		"controller_header": DEFAULT_BRICK_CONTROLLER_COLOR,
		"actuator_header": DEFAULT_BRICK_ACTUATOR_COLOR,
		"header_text": DEFAULT_BRICK_HEADER_TEXT_COLOR,
		"brick_body": DEFAULT_BRICK_BODY_COLOR,
		"graph_background": DEFAULT_GRAPH_BACKGROUND_COLOR,
	}
	for key in defaults:
		_set_customization_color(key, defaults[key])
		_save_editor_customization_color(key, defaults[key])
	_sync_customize_color_pickers()
	_apply_editor_customization()


func _make_menu_color_icon(color: Color) -> ImageTexture:
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _apply_add_menu_colors() -> void:
	if not is_instance_valid(add_menu):
		return
	# PopupMenu does not support a different background/text color per item, so
	# use color swatches that stay readable and track the customizable headers.
	add_menu.set_item_icon(0, _make_menu_color_icon(_brick_sensor_color))
	add_menu.set_item_icon(1, _make_menu_color_icon(_brick_controller_color))
	add_menu.set_item_icon(2, _make_menu_color_icon(_brick_actuator_color))


func _apply_editor_customization() -> void:
	_apply_add_menu_colors()
	if graph_edit:
		var graph_style = StyleBoxFlat.new()
		graph_style.bg_color = _graph_background_color
		graph_edit.add_theme_stylebox_override("panel", graph_style)
		for child in graph_edit.get_children():
			if child is GraphNode and child.has_meta("brick_data"):
				var brick_data = child.get_meta("brick_data")
				_apply_brick_visual_style(child, str(brick_data.get("brick_type", "")))


func _create_variables_tab() -> void:
	# Create the variables management tab
	variables_panel = VBoxContainer.new()
	variables_panel.add_theme_constant_override("separation", 8)
	variables_panel.name = "Variables"
	variables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── Local Variables header ──
	var header = HBoxContainer.new()
	variables_panel.add_child(header)

	var title = Label.new()
	title.text = "Script Variables"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	# Add Variable button
	var add_var_button = Button.new()
	add_var_button.text = "+ Add"
	add_var_button.pressed.connect(_on_add_variable_pressed)
	header.add_child(add_var_button)

	var sep = HSeparator.new()
	variables_panel.add_child(sep)

	# Scrollable list of local variables
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variables_panel.add_child(scroll)

	variables_list = VBoxContainer.new()
	variables_list.add_theme_constant_override("separation", 8)
	variables_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(variables_list)


func _create_global_variables_tab() -> void:
	# Create the global variables management tab (scene-wide, stored on scene root)
	global_vars_panel = VBoxContainer.new()
	global_vars_panel.add_theme_constant_override("separation", 8)
	global_vars_panel.name = "Globals"
	global_vars_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header = HBoxContainer.new()
	global_vars_panel.add_child(header)

	var title = Label.new()
	title.text = "Global Variables (Autoload)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.custom_minimum_size = Vector2(0, 0)
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	var add_global_button = Button.new()
	add_global_button.text = "+ Add"
	add_global_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_global_button.pressed.connect(_on_add_global_variable_pressed)
	header.add_child(add_global_button)

	var sep = HSeparator.new()
	global_vars_panel.add_child(sep)

	var hint = Label.new()
	hint.text = "Shared project-wide through the GlobalVars autoload. Prefer Script Variables unless data truly needs global scope."
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(0, 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 10)
	global_vars_panel.add_child(hint)

	var global_scroll = ScrollContainer.new()
	global_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	global_vars_panel.add_child(global_scroll)

	global_vars_list = VBoxContainer.new()
	global_vars_list.add_theme_constant_override("separation", 8)
	global_vars_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	global_scroll.add_child(global_vars_list)


func _create_frames_tab() -> void:
	# Create the frames management tab
	frames_panel = VBoxContainer.new()
	frames_panel.add_theme_constant_override("separation", 8)
	frames_panel.name = "Frames"
	frames_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header
	var header = HBoxContainer.new()
	frames_panel.add_child(header)

	var title = Label.new()
	title.text = "Frames"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	# Separator
	var sep1 = HSeparator.new()
	frames_panel.add_child(sep1)

	# Frame list with controls
	var list_container = HBoxContainer.new()
	frames_panel.add_child(list_container)

	# Frame list
	frames_list = ItemList.new()
	frames_list.custom_minimum_size = Vector2(0, 150)
	frames_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frames_list.tooltip_text = "Double-click a frame to center and fit it in the graph."
	frames_list.item_selected.connect(_on_frame_list_item_selected)
	frames_list.item_activated.connect(_on_frame_list_item_activated)  # Double-click to navigate to frame
	list_container.add_child(frames_list)

	# Separator
	var sep2 = HSeparator.new()
	frames_panel.add_child(sep2)

	# Frame settings (shown when a frame is selected)
	frame_settings_container = VBoxContainer.new()
	frame_settings_container.add_theme_constant_override("separation", 8)
	frame_settings_container.name = "FrameSettings"
	frame_settings_container.visible = false
	frames_panel.add_child(frame_settings_container)

	var settings_label = Label.new()
	settings_label.text = "Frame Settings:"
	var settings_font = settings_label.get_theme_font("bold", "EditorFonts")
	if settings_font:
		settings_label.add_theme_font_override("font", settings_font)
	frame_settings_container.add_child(settings_label)

	# Frame name field
	var name_label = Label.new()
	name_label.text = "Name:"
	frame_settings_container.add_child(name_label)

	var name_edit = LineEdit.new()
	name_edit.name = "FrameNameEdit"
	name_edit.placeholder_text = "Enter frame name..."
	name_edit.text_changed.connect(_on_frame_name_changed)
	frame_settings_container.add_child(name_edit)

	# Optional frame comment / description
	var comment_label = Label.new()
	comment_label.text = "Comment:"
	frame_settings_container.add_child(comment_label)

	var comment_edit = TextEdit.new()
	comment_edit.name = "FrameCommentEdit"
	comment_edit.placeholder_text = "Describe what this frame does..."
	comment_edit.custom_minimum_size = Vector2(0, 90)
	comment_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comment_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	comment_edit.text_changed.connect(_on_frame_comment_changed)
	frame_settings_container.add_child(comment_edit)

	# Frame color picker
	var color_label = Label.new()
	color_label.text = "Color:"
	frame_settings_container.add_child(color_label)

	var color_picker = ColorPickerButton.new()
	color_picker.name = "FrameColorPicker"
	color_picker.edit_alpha = true
	color_picker.custom_minimum_size = Vector2(96, 40)
	color_picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	color_picker.tooltip_text = "Current frame color. Click to choose a different color."

	# Give the color swatch a clear control outline so it cannot be mistaken
	# for a separator in the frame settings panel.
	var swatch_style = StyleBoxFlat.new()
	swatch_style.bg_color = Color(0, 0, 0, 0)
	swatch_style.border_width_left = 2
	swatch_style.border_width_top = 2
	swatch_style.border_width_right = 2
	swatch_style.border_width_bottom = 2
	swatch_style.border_color = get_theme_color("contrast_color_2", "Editor")
	swatch_style.corner_radius_top_left = 4
	swatch_style.corner_radius_top_right = 4
	swatch_style.corner_radius_bottom_left = 4
	swatch_style.corner_radius_bottom_right = 4
	color_picker.add_theme_stylebox_override("normal", swatch_style)

	var swatch_hover_style = swatch_style.duplicate()
	swatch_hover_style.border_color = get_theme_color("accent_color", "Editor")
	color_picker.add_theme_stylebox_override("hover", swatch_hover_style)
	color_picker.add_theme_stylebox_override("pressed", swatch_hover_style)

	color_picker.color_changed.connect(_on_frame_color_changed)
	frame_settings_container.add_child(color_picker)

	# Manual size controls
	var size_label = Label.new()
	size_label.text = "Frame Size:"
	frame_settings_container.add_child(size_label)

	var size_hbox = HBoxContainer.new()
	frame_settings_container.add_child(size_hbox)

	var width_label = Label.new()
	width_label.text = "W:"
	size_hbox.add_child(width_label)

	var width_spin = SpinBox.new()
	width_spin.name = "FrameWidthSpin"
	width_spin.min_value = 100
	width_spin.max_value = 2000
	width_spin.step = 10
	width_spin.value_changed.connect(_on_frame_width_changed)
	size_hbox.add_child(width_spin)

	var height_label = Label.new()
	height_label.text = "H:"
	size_hbox.add_child(height_label)

	var height_spin = SpinBox.new()
	height_spin.name = "FrameHeightSpin"
	height_spin.min_value = 100
	height_spin.max_value = 2000
	height_spin.step = 10
	height_spin.value_changed.connect(_on_frame_height_changed)
	size_hbox.add_child(height_spin)

	# Auto-resize button
	var resize_button = Button.new()
	resize_button.text = "Auto-Resize to Fit Nodes"
	resize_button.pressed.connect(_on_frame_resize_pressed)
	frame_settings_container.add_child(resize_button)

	# Delete frame button
	var delete_button = Button.new()
	delete_button.text = "Delete Frame"
	delete_button.modulate = Color(1, 0.5, 0.5)
	delete_button.pressed.connect(_on_frame_delete_pressed)
	frame_settings_container.add_child(delete_button)




func _create_states_tab() -> void:
	states_panel = VBoxContainer.new()
	states_panel.add_theme_constant_override("separation", 8)
	states_panel.name = "States"
	states_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header = HBoxContainer.new()
	states_panel.add_child(header)

	var title = Label.new()
	title.text = "States"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	state_debug_button = Button.new()
	var state_debug_enabled := false
	if current_node and is_instance_valid(current_node):
		state_debug_enabled = bool(current_node.get_meta("blueprints_for_godot_debug_watch_state", false))
	state_debug_button.button_pressed = state_debug_enabled
	_style_debug_watch_button(state_debug_button, state_debug_enabled)
	state_debug_button.tooltip_text = "Show this node's current state in the Runtime Debug Overlay"
	state_debug_button.toggled.connect(_on_state_debug_watch_toggled.bind(state_debug_button))
	header.add_child(state_debug_button)

	var add_state_button = Button.new()
	add_state_button.text = "+ Add"
	add_state_button.pressed.connect(_on_add_state_pressed)
	header.add_child(add_state_button)

	states_panel.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	states_panel.add_child(scroll)

	states_list = VBoxContainer.new()
	states_list.add_theme_constant_override("separation", 8)
	states_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(states_list)

	_refresh_states_ui()


func _sanitize_state_id(text_value: String) -> String:
	var sanitized_name = text_value.strip_edges().to_lower().replace(" ", "_")
	sanitized_name = sanitized_name.replace("-", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	sanitized_name = regex.sub(sanitized_name, "", true)
	if sanitized_name.is_empty():
		sanitized_name = "state"
	return sanitized_name


func _generate_unique_state_id(base_name: String) -> String:
	var candidate = _sanitize_state_id(base_name)
	var suffix = 1
	var existing: Dictionary = {}
	for state_data in states_data:
		existing[str(state_data.get("id", ""))] = true
	while existing.has(candidate):
		candidate = "%s_%d" % [_sanitize_state_id(base_name), suffix]
		suffix += 1
	return candidate


func _get_default_states() -> Array[Dictionary]:
	return [
		{
			"id": "state_1",
			"name": "State 1"
		}
	]


func _load_states_from_metadata(suppress_graph_save: bool = false) -> void:
	states_data.clear()
	if current_node and current_node.has_meta("blueprints_for_godot_states"):
		var saved = current_node.get_meta("blueprints_for_godot_states")
		if saved is Array:
			var migrate_state_watch := false
			for state_data in saved:
				var copied_state: Dictionary = state_data.duplicate(true)
				if bool(copied_state.get("debug_watch", false)):
					migrate_state_watch = true
				copied_state.erase("debug_watch")
				states_data.append(copied_state)
			if migrate_state_watch:
				current_node.set_meta("blueprints_for_godot_debug_watch_state", true)
	if state_debug_button and is_instance_valid(state_debug_button):
		var state_watch_enabled := bool(current_node.get_meta("blueprints_for_godot_debug_watch_state", false)) if current_node else false
		state_debug_button.set_pressed_no_signal(state_watch_enabled)
		_style_debug_watch_button(state_debug_button, state_watch_enabled)
	if states_data.is_empty():
		states_data = _get_default_states()
		# Guard: do not flush a stale graph_edit into this node's metadata when
		# called before _load_graph_from_metadata has had a chance to clear and
		# repopulate the canvas (e.g. during a node-selection switch).
		if not suppress_graph_save:
			_save_states_to_metadata()
		else:
			# Persist only the default states; skip the graph flush.
			if current_node and is_instance_valid(current_node):
				current_node.set_meta("blueprints_for_godot_states", states_data.duplicate(true))
	_refresh_states_ui()
	_refresh_brick_state_ui()


func _save_states_to_metadata() -> void:
	if not current_node or not is_instance_valid(current_node):
		return
	current_node.set_meta("blueprints_for_godot_states", states_data.duplicate(true))
	_mark_scene_modified()
	_save_graph_to_metadata()


func _refresh_states_ui() -> void:
	if not states_list:
		return
	for child in states_list.get_children():
		child.queue_free()
	for i in range(states_data.size()):
		_create_state_item_ui(i, states_data[i])


func _create_state_item_ui(index: int, state_data: Dictionary) -> void:
	var item_panel = PanelContainer.new()
	states_list.add_child(item_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	item_panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var name_edit = LineEdit.new()
	name_edit.text = str(state_data.get("name", "State"))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_state_name_changed.bind(index))
	header.add_child(name_edit)


	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.tooltip_text = "Delete state"
	delete_btn.pressed.connect(_on_delete_state_pressed.bind(index))
	header.add_child(delete_btn)


func _on_state_debug_watch_toggled(enabled: bool, button: Button) -> void:
	if not current_node or not is_instance_valid(current_node):
		return
	current_node.set_meta("blueprints_for_godot_debug_watch_state", enabled)
	_style_debug_watch_button(button, enabled)
	_mark_scene_modified()


func _on_add_state_pressed() -> void:
	var state_name = "State %d" % (states_data.size() + 1)
	var state_id = _generate_unique_state_id(state_name)
	states_data.append({
		"id": state_id,
		"name": state_name
	})
	_refresh_states_ui()
	_save_states_to_metadata()
	_refresh_brick_state_ui()


func _on_delete_state_pressed(index: int) -> void:
	if index < 0 or index >= states_data.size():
		return
	states_data.remove_at(index)
	if states_data.is_empty():
		states_data = _get_default_states()
	_refresh_states_ui()
	_save_states_to_metadata()
	_refresh_brick_state_ui()


func _on_state_name_changed(new_text: String, index: int) -> void:
	if index < 0 or index >= states_data.size():
		return
	states_data[index]["name"] = new_text
	_save_states_to_metadata()
	_refresh_brick_state_ui()


func get_state_options() -> Array:
	var result: Array = []
	for state_data in states_data:
		result.append({"id": str(state_data.get("id", "")), "name": str(state_data.get("name", ""))})
	return result


func get_state_display_name(state_id: String) -> String:
	for state_data in states_data:
		if str(state_data.get("id", "")) == state_id:
			return str(state_data.get("name", state_id))
	return state_id

func _enter_tree() -> void:
	# Apply editor icons now that the theme is available.
	_apply_side_tab_icons()


func set_selected_node(node: Node) -> void:
	# Don't change selection if locked
	if is_locked:
		return

	# No-op if the same node is re-selected (avoids a spurious save+reload cycle)
	if node == current_node:
		return

	# Reset instance override when switching nodes
	_instance_override = false
	_hide_instance_panel()

	# Save current state before switching (but NOT if current node is an instance).
	# This bookkeeping save is not a user edit, so it must not create a false
	# "unapplied changes" indicator on the next node.
	_suppress_dirty_mark = true
	if current_node and not _is_part_of_instance(current_node):
		_save_graph_to_metadata()
		_frames_helper.save_frames_to_metadata(self)
	_suppress_dirty_mark = false

	_clear_all_apply_warnings()
	_apply_validation_active = false
	_clear_unapplied_changes()
	current_node = node
	_update_ui()


func _update_ui() -> void:
	node_info_label.remove_theme_color_override("font_color")
	_hide_script_required_overlay()

	if not current_node:
		current_brick_domain = ""
		node_info_label.text = "No node selected - Select a Node3D, Node2D, or UI Control node in the scene tree"
		graph_edit.visible = false
		_apply_side_panel_visibility()
		if _toolbar:
			_toolbar.visible = false
		if _toolbar_separator:
			_toolbar_separator.visible = false
		if _instructions_label:
			_instructions_label.visible = true
		return

	# Check if node is supported
	if not _is_supported_node(current_node):
		current_brick_domain = ""
		node_info_label.text = "Unsupported node type: %s - Use a Node3D, Node2D, or UI Control node" % current_node.get_class()
		graph_edit.visible = false
		_apply_side_panel_visibility()
		if _toolbar:
			_toolbar.visible = false
		if _toolbar_separator:
			_toolbar_separator.visible = false
		if _instructions_label:
			_instructions_label.visible = true
		return

	# Instanced scenes must be explicitly unlocked before any other editing choice.
	if _is_part_of_instance(current_node) and not _instance_override:
		node_info_label.text = "⚠ Instanced Node: %s" % current_node.name
		node_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
		graph_edit.visible = false
		_apply_side_panel_visibility()
		if _toolbar:
			_toolbar.visible = false
		if _toolbar_separator:
			_toolbar_separator.visible = false
		if _instructions_label:
			_instructions_label.visible = false
		_show_instance_panel()
		return

	# Hide instance panel after choosing Edit This Instance, or for regular nodes.
	_hide_instance_panel()

	current_brick_domain = _get_selected_node_domain()
	_refresh_add_menu_from_registry(false)

	# A script is required before GDBlueprints can be edited. Show a full blocking
	# prompt in the graph area instead of allowing students into a dead-end state.
	if current_node.get_script() == null:
		_clear_graph_display()
		node_info_label.text = "⚠ Node: %s (%s) - Script required" % [current_node.name, current_node.get_class()]
		node_info_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		graph_edit.visible = true
		_apply_side_panel_visibility()
		if side_panel:
			side_panel.visible = false
		if _toolbar:
			_toolbar.visible = false
		if _toolbar_separator:
			_toolbar_separator.visible = false
		if _instructions_label:
			_instructions_label.visible = false
		_show_script_required_overlay()
		return

	var owner_script := current_node.get_script()
	var owner_script_name := "<no script>"
	if owner_script and not str(owner_script.resource_path).is_empty():
		owner_script_name = str(owner_script.resource_path).get_file()
	node_info_label.text = "Graph: %s (%s)  •  %s  •  Right-click to add %s nodes" % [current_node.name, current_node.get_class(), owner_script_name, current_brick_domain.to_upper()]
	graph_edit.visible = true
	_apply_side_panel_visibility()
	if _toolbar:
		_toolbar.visible = true
	if _toolbar_separator:
		_toolbar_separator.visible = true
	if _instructions_label:
		_instructions_label.visible = false

	# Load states before building graph UI so state dropdowns have options immediately.
	# Pass suppress_graph_save=true so that writing default states for a freshly-selected
	# node does NOT trigger a graph flush while graph_edit still holds the previous
	# node's bricks (the canvas is cleared and repopulated by _load_graph_from_metadata below).
	_load_states_from_metadata(true)
	# Variable-aware bricks (Compare Variable / Modify Variable) build their
	# operation dropdowns while the graph UI is created. Load variable metadata
	# first so Array variables get their Array-specific menus immediately when
	# reopening a project or switching nodes.
	_load_variables_from_metadata()
	await _load_graph_from_metadata()
	_frames_helper.load_frames_from_metadata(self)
	# GraphEdit keeps its previous scroll position when switching scene nodes.
	# Frame the freshly loaded graph so users never open onto empty space.
	await get_tree().process_frame
	_frame_graph_contents(false)
	_refresh_brick_state_ui()
	_refresh_variable_brick_context_ui()


func _refresh_brick_state_ui() -> void:
	if not graph_edit or not _property_helper:
		return
	for child in graph_edit.get_children():
		if child is GraphNode and child.has_meta("brick_data"):
			var brick_data = child.get_meta("brick_data")
			var brick_instance = brick_data.get("brick_instance")
			if not brick_instance:
				continue
			var brick_type = str(brick_data.get("brick_type", ""))
			if brick_type in ["controller", "actuator"]:
				_property_helper._refresh_state_dropdown(child, brick_instance)
				if brick_type == "controller":
					_property_helper._update_controller_title(child, brick_instance)


func _refresh_variable_brick_context_ui() -> void:
	if not graph_edit or not _property_helper:
		return
	for child in graph_edit.get_children():
		if not (child is GraphNode and child.has_meta("brick_data")):
			continue
		var brick_data = child.get_meta("brick_data")
		var brick_instance = brick_data.get("brick_instance")
		if brick_instance:
			# The helper no-ops for non-variable bricks. Checking the script there also
			# covers 2D compatibility aliases that share these same brick scripts.
			_property_helper._refresh_variable_brick_operation_control(child, brick_instance)


func _is_supported_node(node: Node) -> bool:
	return node is Node3D or node is Node2D or node is Control


func _get_selected_node_domain() -> String:
	if current_node is Control:
		return "ui"
	if current_node is Node2D:
		return "2d"
	if current_node is Node3D:
		return "3d"
	return ""



## ── Pop-out / dock ────────────────────────────────────────────────────────────

func _on_popout_pressed() -> void:
	if _popout_window:
		_dock_window()
	else:
		_popout_window_open()


func _popout_window_open() -> void:
	# Create the floating window
	_popout_window = Window.new()
	_popout_window.title = "GDBlueprints"
	_popout_window.size = Vector2i(1280, 720)
	_popout_window.wrap_controls = true
	_popout_window.min_size = Vector2i(640, 400)
	_popout_window.close_requested.connect(_dock_window)

	# Root container inside the window (mirrors the bottom panel VBox structure)
	var win_root = VBoxContainer.new()
	win_root.add_theme_constant_override("separation", 8)
	win_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popout_window.add_child(win_root)

	# Move instructions label into the window root
	remove_child(_instructions_label)
	win_root.add_child(_instructions_label)

	# Re-create the hsplit inside the window
	var win_hsplit = HSplitContainer.new()
	win_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win_hsplit.split_offset = _main_hsplit.split_offset
	win_root.add_child(win_hsplit)

	# Move graph_edit and side_panel into the window hsplit
	_main_hsplit.remove_child(graph_edit)
	_main_hsplit.remove_child(side_panel)
	win_hsplit.add_child(graph_edit)
	win_hsplit.add_child(side_panel)

	# Move toolbar separator and toolbar into the window root
	remove_child(_toolbar_separator)
	remove_child(_toolbar)
	win_root.add_child(_toolbar_separator)
	win_root.add_child(_toolbar)

	# Re-parent add_menu into the floating window so right-click popups
	# appear on the correct monitor (popups always follow their owner window)
	remove_child(add_menu)
	_popout_window.add_child(add_menu)

	# Hide the now-empty bottom panel hsplit
	_main_hsplit.visible = false

	# Update button
	_popout_button.text = "⬅"
	_popout_button.tooltip_text = "Dock back into the bottom panel"

	# Add the window to the editor
	get_tree().root.add_child(_popout_window)
	_popout_window.popup_centered()


func _dock_window() -> void:
	if not _popout_window:
		return

	# Retrieve the window's hsplit so we can restore split_offset
	var win_root = _popout_window.get_child(0) if _popout_window.get_child_count() > 0 else null
	var win_hsplit: HSplitContainer = null
	if win_root:
		for child in win_root.get_children():
			if child is HSplitContainer:
				win_hsplit = child
				break

	# Restore split offset from window if available
	if win_hsplit:
		_main_hsplit.split_offset = win_hsplit.split_offset
		win_hsplit.remove_child(graph_edit)
		win_hsplit.remove_child(side_panel)

	# Move instructions label back
	if win_root:
		win_root.remove_child(_instructions_label)
	add_child(_instructions_label)
	move_child(_instructions_label, get_child_count() - 1)

	# Re-parent back into the bottom panel hsplit
	_main_hsplit.add_child(graph_edit)
	_main_hsplit.add_child(side_panel)
	_main_hsplit.visible = true

	# Move toolbar separator and toolbar back
	if win_root:
		win_root.remove_child(_toolbar_separator)
		win_root.remove_child(_toolbar)
	add_child(_toolbar_separator)
	add_child(_toolbar)

	# Move add_menu back to the main panel
	_popout_window.remove_child(add_menu)
	add_child(add_menu)

	# Close and free the window
	_popout_window.close_requested.disconnect(_dock_window)
	_popout_window.queue_free()
	_popout_window = null

	# Restore button
	_popout_button.text = "⧉"
	_popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"


func _create_script_required_overlay() -> void:
	_script_required_overlay = CenterContainer.new()
	_script_required_overlay.name = "ScriptRequiredOverlay"
	_script_required_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_script_required_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_script_required_overlay.visible = false
	graph_edit.add_child(_script_required_overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 250)
	_script_required_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "⚠  Script Required"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	vbox.add_child(title)

	_script_required_desc = Label.new()
	_script_required_desc.text = "GDBlueprints cannot be added to this node until it has a script."
	_script_required_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_script_required_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_script_required_desc)

	add_script_button = Button.new()
	add_script_button.text = "Add Script to Node"
	add_script_button.tooltip_text = "Create and attach the script required by GDBlueprints"
	add_script_button.custom_minimum_size = Vector2(220, 44)
	add_script_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_script_button.pressed.connect(_on_add_script_pressed)
	vbox.add_child(add_script_button)

	_script_parent_warning = Label.new()
	_script_parent_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_script_parent_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_parent_warning.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	_script_parent_warning.visible = false
	vbox.add_child(_script_parent_warning)

	_script_select_parent_button = Button.new()
	_script_select_parent_button.text = "Select Parent"
	_script_select_parent_button.tooltip_text = "Select the nearest parent that already has a script or GDBlueprints"
	_script_select_parent_button.custom_minimum_size = Vector2(220, 40)
	_script_select_parent_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_script_select_parent_button.visible = false
	_script_select_parent_button.pressed.connect(_on_select_parent_pressed)
	vbox.add_child(_script_select_parent_button)


func _show_script_required_overlay() -> void:
	if not _script_required_overlay:
		return

	var parent_with_logic = _get_parent_with_script_or_logic()
	if _script_parent_warning:
		_script_parent_warning.text = "This is a child of a node with a script/logic."
		_script_parent_warning.visible = parent_with_logic != null
	if _script_select_parent_button:
		_script_select_parent_button.visible = parent_with_logic != null

	_script_required_overlay.visible = true
	_script_required_overlay.move_to_front()


func _get_parent_with_script_or_logic() -> Node:
	if not current_node:
		return null

	var parent = current_node.get_parent()
	while parent:
		if parent.get_script() != null or parent.has_meta("blueprints_for_godot_graph") or parent.has_meta("blueprints_for_godot"):
			return parent
		parent = parent.get_parent()
	return null


func _on_select_parent_pressed() -> void:
	var parent_with_logic = _get_parent_with_script_or_logic()
	if not parent_with_logic or not editor_interface:
		return

	var selection = editor_interface.get_selection()
	selection.clear()
	selection.add_node(parent_with_logic)


func _hide_script_required_overlay() -> void:
	if _script_required_overlay:
		_script_required_overlay.visible = false


func _show_instance_panel() -> void:
	if _instance_panel:
		_instance_panel.visible = true
		return

	# Build the panel
	_instance_panel = PanelContainer.new()
	_instance_panel.name = "InstancePanel"
	_instance_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_theme_constant_override("separation", 10)
	_instance_panel.add_child(vbox)

	# Warning icon + title
	var title = Label.new()
	title.text = "⚠  Instanced Scene"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = "This node belongs to an instanced scene.\nChanges made here will only affect this instance.\nTo change all instances, edit the original scene."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Buttons
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	var open_btn = Button.new()
	open_btn.text = "📂  Open Original Scene"
	open_btn.tooltip_text = "Open the original scene file for this instance"
	open_btn.pressed.connect(_on_open_original_pressed)
	btn_box.add_child(open_btn)

	var override_btn = Button.new()
	override_btn.text = "✏  Edit This Instance"
	override_btn.tooltip_text = "Add GDBlueprints to this instance only.\nWarning: these bricks will not appear in the original scene."
	override_btn.pressed.connect(_on_edit_instance_pressed)
	btn_box.add_child(override_btn)

	# Insert above the graph_edit in the layout
	var parent = graph_edit.get_parent()
	var graph_index = graph_edit.get_index()
	parent.add_child(_instance_panel)
	parent.move_child(_instance_panel, graph_index)


func _hide_instance_panel() -> void:
	if _instance_panel:
		_instance_panel.visible = false


func _on_open_original_pressed() -> void:
	if not current_node or not editor_interface:
		return
	# Walk up to find the instanced scene root
	var target = current_node
	var edited_root = editor_interface.get_edited_scene_root()
	while target:
		if target.scene_file_path != "" and target != edited_root:
			editor_interface.open_scene_from_path(target.scene_file_path)
			return
		target = target.get_parent()


func _on_edit_instance_pressed() -> void:
	_instance_override = true
	_hide_instance_panel()
	_update_ui()


func _is_part_of_instance(node: Node) -> bool:
	# Check if the node is part of an instanced scene (not the root scene)
	if not editor_interface:
		return false

	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return false

	var current = node
	while current:
		if current == edited_scene_root:
			return false
		if current.scene_file_path != "" and current != edited_scene_root:
			return true
		current = current.get_parent()

	return false


func _clear_graph_display() -> void:
	graph_edit.clear_connections()
	var children_to_remove = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			children_to_remove.append(child)
	for child in children_to_remove:
		graph_edit.remove_child(child)
		child.free()


func _load_graph_from_metadata() -> void:
	# Clear existing graph before loading the selected node.
	_clear_graph_display()

	if not current_node or not current_node.has_meta("blueprints_for_godot_graph"):
		pass
		return

	# Snapshot the node we are loading for — current_node may change during the
	# await below if the user clicks another node while this coroutine is suspended.
	var _loading_for_node = current_node
	var graph_data = GraphSchema.migrate(_loading_for_node.get_meta("blueprints_for_godot_graph"))

	# Restore nodes
	for node_data in graph_data.get("nodes", []):
		_create_graph_node_from_data(node_data)

	# Restore connections (must happen after all nodes are created)
	await get_tree().process_frame

	# If the user switched nodes while we were suspended, discard this load —
	# the new set_selected_node call will handle the correct node's graph.
	if current_node != _loading_for_node:
		graph_edit.clear_connections()
		for child in graph_edit.get_children():
			if child is GraphNode:
				child.queue_free()
		return

	for conn in graph_data.get("connections", []):
		graph_edit.connect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
	_sync_value_bindings_from_connections()

	next_node_id = graph_data.get("next_id", 0)


## Take a deep copy of the current graph metadata for undo/redo snapshots
func _take_graph_snapshot() -> Dictionary:
	return _clipboard_helper.take_graph_snapshot()


## Restore a graph snapshot: write it back to metadata and rebuild the visual graph.
## The metadata write is synchronous; the visual rebuild is deferred one frame.
func _restore_graph_snapshot(snapshot: Dictionary) -> void:
	_restore_graph_snapshot_for_node(current_node, snapshot)

func _restore_graph_snapshot_for_node(target_node: Node, snapshot: Dictionary) -> void:
	_clipboard_helper.restore_graph_snapshot(target_node, snapshot)


## Called deferred after a snapshot restore so the visual graph rebuilds cleanly
func _reload_graph_deferred(target_node: Node = current_node) -> void:
	await _clipboard_helper.reload_graph_deferred(target_node)


## Record an undoable graph action.
## Call BEFORE making changes (before_snapshot) and AFTER (after_snapshot).
func _record_undo(action_name: String, before_snapshot: Dictionary, after_snapshot: Dictionary, target_node: Node = current_node, merge: bool = false) -> void:
	_clipboard_helper.record_undo(action_name, before_snapshot, after_snapshot, target_node, merge)


func _save_graph_to_metadata(action_name: String = "Edit GDBlueprints", record_change: bool = true, merge: bool = true) -> void:
	_sync_value_bindings_from_connections()
	_clipboard_helper.save_graph_to_metadata(action_name, record_change, merge)


func _mark_unapplied_changes() -> void:
	if _suppress_dirty_mark:
		return
	_has_unapplied_changes = true
	_dirty_indicator_token += 1
	_set_compile_button_state("dirty")


func _set_compile_button_state(state: String) -> void:
	if not is_instance_valid(_apply_code_button):
		return
	var box := StyleBoxFlat.new()
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	if state == "dirty":
		box.bg_color = Color("c69b24")
		_apply_code_button.text = "Compile Blueprint → GDScript  •"
		_apply_code_button.tooltip_text = "Graph changes have not been compiled to GDScript yet."
	elif state == "success":
		box.bg_color = Color("3b8f55")
		_apply_code_button.text = "✓ Compiled to GDScript"
		_apply_code_button.tooltip_text = "The visual graph and generated GDScript are in sync."
	else:
		box.bg_color = Color("4b4b4b")
		_apply_code_button.text = "Compile Blueprint → GDScript"
		_apply_code_button.tooltip_text = ""
	_apply_code_button.add_theme_stylebox_override("normal", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = box.bg_color.lightened(0.08)
	_apply_code_button.add_theme_stylebox_override("hover", hover)


func _clear_unapplied_changes() -> void:
	_has_unapplied_changes = false
	_dirty_indicator_token += 1
	_set_compile_button_state("idle")


func _warning_node_name(graph_node: GraphNode) -> String:
	return "apply_warning_" + str(graph_node.name)


func _remove_apply_warning(graph_node: GraphNode) -> void:
	var warning = graph_edit.get_node_or_null(NodePath(_warning_node_name(graph_node)))
	if warning:
		graph_edit.remove_child(warning)
		warning.queue_free()


func _set_apply_warning(graph_node: GraphNode, messages: Array[String]) -> void:
	_remove_apply_warning(graph_node)
	if messages.is_empty():
		return
	var warning = GraphNode.new()
	warning.name = _warning_node_name(graph_node)
	warning.title = ""
	warning.draggable = false
	warning.selectable = false
	warning.resizable = false
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.z_index = 100
	var label = Label.new()
	label.text = "⚠ " + " • ".join(messages)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.add_child(label)
	var box = StyleBoxFlat.new()
	box.bg_color = Color("5a430d")
	box.border_color = Color("f2b84b")
	box.set_border_width_all(2)
	box.content_margin_left = 10
	box.content_margin_right = 20
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_left = 5
	box.corner_radius_bottom_right = 5
	warning.add_theme_stylebox_override("panel", box)
	warning.add_theme_stylebox_override("panel_selected", box)
	var empty_title = StyleBoxEmpty.new()
	warning.add_theme_stylebox_override("titlebar", empty_title)
	warning.add_theme_stylebox_override("titlebar_selected", empty_title)
	graph_edit.add_child(warning)
	warning.size = warning.get_combined_minimum_size()
	warning.position_offset = graph_node.position_offset + Vector2(0, -warning.size.y - 10)


func _refresh_apply_validation_warnings() -> void:
	if not _apply_validation_active or not is_instance_valid(graph_edit):
		return
	# Apply Code is the validation checkpoint. Rebuild the warning set from
	# exactly the bricks that exist at this moment; later edits do not add
	# warnings until Apply Code is pressed again.
	_clear_all_apply_warnings()
	var connections = graph_edit.get_connection_list()
	for child in graph_edit.get_children():
		if not (child is GraphNode and child.has_meta("brick_data")):
			continue
		var messages: Array[String] = []
		if not _graph_helper.is_brick_in_complete_chain(child, connections):
			messages.append("Incomplete Brick Chain")
		var brick_data: Dictionary = child.get_meta("brick_data")
		var brick_instance = brick_data.get("brick_instance")
		if brick_instance and brick_instance.has_method("get_configuration_warnings"):
			for message in brick_instance.call("get_configuration_warnings", current_node):
				var text := str(message).strip_edges()
				if not text.is_empty():
					messages.append(text)
		_set_apply_warning(child, messages)


func _clear_all_apply_warnings() -> void:
	var warnings_to_remove: Array[Node] = []
	for child in graph_edit.get_children():
		if child is GraphNode and str(child.name).begins_with("apply_warning_"):
			warnings_to_remove.append(child)
	for warning in warnings_to_remove:
		graph_edit.remove_child(warning)
		warning.queue_free()


func _on_popup_request(position: Vector2) -> void:
	# Kept for compatibility with older scenes. BlueprintGraphEdit now handles
	# right-click directly and opens search instead of a context menu.
	_on_graph_quick_search_requested(position)


func _on_graph_quick_search_requested(position: Vector2) -> void:
	if not current_node or current_node.get_script() == null:
		return
	last_mouse_position = (position + graph_edit.scroll_offset) / graph_edit.zoom
	_refresh_add_menu_from_registry(true)
	var screen_pos = graph_edit.get_screen_position() + position
	_open_search_popup(screen_pos)


func _on_graph_payload_dropped(data: Variant, position: Vector2) -> void:
	if not current_node or current_node.get_script() == null:
		return
	# A SceneTree drag temporarily changes Godot editor selection. Tell the plugin that
	# this was a reference drop, not a request to leave the graph receiving the drop.
	if data is Dictionary and (data.has("nodes") or data.has("node") or data.has("object")):
		if plugin and plugin.has_method("cancel_pending_scene_selection"):
			plugin.call("cancel_pending_scene_selection")
	last_mouse_position = (position + graph_edit.scroll_offset) / graph_edit.zoom
	if data is Dictionary and data.has("bfg_variable"):
		_pending_variable_drop = data["bfg_variable"].duplicate(true)
		_pending_variable_drop_position = last_mouse_position
		_show_variable_drop_menu(graph_edit.get_screen_position() + position)
		return
	if data is Dictionary and data.has("nodes"):
		_create_scene_node_getter_from_drop(data["nodes"], last_mouse_position)
		return
	if data is Dictionary:
		var direct_node = data.get("node", data.get("object", null))
		if direct_node is Node:
			_create_scene_node_getter_from_drop([direct_node], last_mouse_position)


func _show_variable_drop_menu(screen_pos: Vector2) -> void:
	if not is_instance_valid(_variable_drop_menu):
		_variable_drop_menu = PopupMenu.new()
		_variable_drop_menu.name = "VariableDropMenu"
		_variable_drop_menu.add_item("Get Variable", 0)
		_variable_drop_menu.add_item("Set Variable", 1)
		_variable_drop_menu.id_pressed.connect(_on_variable_drop_menu_selected)
		add_child(_variable_drop_menu)
	_variable_drop_menu.position = Vector2i(screen_pos)
	_variable_drop_menu.popup()


func _on_variable_drop_menu_selected(id: int) -> void:
	var info := _resolve_dragged_variable(_pending_variable_drop)
	if info.is_empty():
		return
	if id == 0:
		_create_value_getter_node(info, _pending_variable_drop_position)
	else:
		_create_variable_setter_node(info, _pending_variable_drop_position)


func _resolve_dragged_variable(payload: Dictionary) -> Dictionary:
	var scope := str(payload.get("scope", "local"))
	var index := int(payload.get("index", -1))
	var data_array = global_vars_data if scope == "global" else variables_data
	if index < 0 or index >= data_array.size():
		return {}
	var info: Dictionary = data_array[index].duplicate(true)
	info["scope"] = scope
	if scope == "global":
		_set_global_used_in_current_script(index, true)
	return info


func _create_variable_setter_node(info: Dictionary, position: Vector2) -> void:
	var node := _create_graph_node("actuator", "VariableActuator", position)
	if node == null or not node.has_meta("brick_data"):
		return
	var brick = node.get_meta("brick_data").get("brick_instance")
	var variable_name := str(info.get("name", ""))
	brick.set_property("variable_name", variable_name)
	brick.set_property("mode", "assign")
	node.title = "Set %s" % (variable_name if not variable_name.is_empty() else "Variable")

	# Keep the visible controls in sync with the preconfigured brick. Otherwise
	# sync_graph_ui_to_bricks() would copy the old blank UI field back into the
	# brick immediately before compilation.
	var variable_control = _find_property_control(node, "variable_name")
	if variable_control is LineEdit:
		variable_control.text = variable_name

	_save_graph_to_metadata("Add Set Variable", true, false)


func _sanitize_value_expression_name(value: String) -> String:
	var out := value.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex.sub(out, "", true)


func _create_value_getter_node(info: Dictionary, position: Vector2) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = "value_node_%d" % next_node_id
	next_node_id += 1
	graph_node.position_offset = position
	graph_node.title = "Get %s" % str(info.get("name", "Variable"))
	graph_node.resizable = false
	graph_node.draggable = true
	var expr := _sanitize_value_expression_name(str(info.get("name", "")))
	var value_info := {
		"kind":"variable", "name":str(info.get("name", "")),
		"type":str(info.get("type", "Variant")), "scope":str(info.get("scope", "local")),
		"expression":expr,
		"outputs":[{"name":"Value", "type":str(info.get("type", "Variant")), "expression":expr}]
	}
	_build_value_node_visual(graph_node, value_info)
	_setup_value_node_context_menu(graph_node)
	_add_view_code_button(graph_node)
	graph_edit.add_child(graph_node)
	_save_graph_to_metadata("Add Get Variable", true, false)
	return graph_node


func _create_scene_node_getter_from_drop(nodes_data: Variant, position: Vector2) -> void:
	if not editor_interface:
		return
	if not (nodes_data is Array or nodes_data is PackedStringArray) or nodes_data.is_empty():
		return
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return
	var target: Node = null
	var raw_path = nodes_data[0]
	if raw_path is Node:
		target = raw_path
	elif raw_path is NodePath or raw_path is String:
		var path_text := str(raw_path)
		# Absolute NodePaths can be resolved directly while the edited scene is in the tree.
		target = root.get_node_or_null(NodePath(path_text))
		# Some editor drags use a path prefixed with the edited scene root name.
		if target == null and path_text.begins_with(str(root.name) + "/"):
			target = root.get_node_or_null(NodePath(path_text.substr(str(root.name).length() + 1)))
		# And some include the full absolute scene-root path as text. Strip that prefix.
		if target == null:
			var root_path_text := str(root.get_path())
			if path_text.begins_with(root_path_text + "/"):
				var relative_text := path_text.substr(root_path_text.length() + 1)
				target = root.get_node_or_null(NodePath(relative_text))
	if target == null:
		return
	var relative := current_node.get_path_to(target)
	var graph_node := GraphNode.new()
	graph_node.name = "value_node_%d" % next_node_id
	next_node_id += 1
	graph_node.position_offset = position
	graph_node.title = "Get %s" % target.name
	var expression := "get_node(\"%s\")" % str(relative)
	var value_info := {
		"kind":"node", "name":target.name, "type":target.get_class(), "expression":expression, "node_path":str(relative),
		"godot_term":"Godot: %s" % expression,
		"outputs":[{"name":"Node", "type":target.get_class(), "expression":expression}]
	}
	_build_value_node_visual(graph_node, value_info)
	_setup_value_node_context_menu(graph_node)
	_add_view_code_button(graph_node)
	graph_edit.add_child(graph_node)
	_save_graph_to_metadata("Add Node Reference", true, false)


func _refresh_value_node_visual(graph_node: GraphNode) -> void:
	if graph_node == null or not graph_node.has_meta("value_node"):
		return
	# Remove only the content rows we added. Keep PopupMenu children intact.
	for child in graph_node.get_children():
		if child is PopupMenu:
			continue
		graph_node.remove_child(child)
		child.queue_free()
	_build_value_node_visual(graph_node, graph_node.get_meta("value_node"))
	_add_view_code_button(graph_node)
	graph_node.reset_size()

func _toggle_value_node_split(graph_node: GraphNode) -> void:
	if graph_node == null or not graph_node.has_meta("value_node"):
		return
	var info: Dictionary = graph_node.get_meta("value_node").duplicate(true)
	# Determine the unsplit base type from stored outputs, not the normalized list.
	var raw_outputs = info.get("outputs", [])
	if not (raw_outputs is Array) or raw_outputs.size() != 1:
		return
	var base: Dictionary = raw_outputs[0]
	var type_name := str(base.get("type", info.get("type", "Variant")))
	if not _is_splittable_value_type(type_name):
		return
	var splitting := not bool(info.get("split_struct", false))
	if not splitting:
		# Recombine: component ports disappear, so remove their connections first.
		for conn in graph_edit.get_connection_list().duplicate():
			if str(conn.get("from_node", "")) == str(graph_node.name) and int(conn.get("from_port", 0)) > 0:
				_disconnect_connection_dictionary(conn, "Recombine Struct Pin")
	info["split_struct"] = splitting
	graph_node.set_meta("value_node", info)
	_refresh_value_node_visual(graph_node)
	var popup = graph_node.get_node_or_null("ValueNodeContextMenu")
	if popup is PopupMenu and popup.get_item_count() > 1:
		popup.set_item_text(0, "Recombine Struct Pin" if splitting else "Split Struct Pin")
	_save_graph_to_metadata("Split Struct Pin" if splitting else "Recombine Struct Pin", true, false)

func _variable_type_for_pin(type_name: String) -> String:
	return PinTypeRegistry.variable_type(type_name)


func _unique_local_variable_name(base_name: String) -> String:
	var cleaned := _sanitize_value_expression_name(base_name.to_snake_case())
	if cleaned.is_empty():
		cleaned = "new_variable"
	var candidate := cleaned
	var suffix := 2
	var names: Dictionary = {}
	for item in variables_data:
		names[str(item.get("name", ""))] = true
	while names.has(candidate):
		candidate = "%s_%d" % [cleaned, suffix]
		suffix += 1
	return candidate


func _ensure_pin_context_popup() -> void:
	if is_instance_valid(_pin_context_popup):
		return
	_pin_context_popup = PopupMenu.new()
	_pin_context_popup.name = "DataPinContextMenu"
	_pin_context_popup.add_item("Promote to Variable", 0)
	_pin_context_popup.id_pressed.connect(_on_pin_context_selected)
	add_child(_pin_context_popup)


func _show_pin_context_for(graph_node: GraphNode, port: int, is_output: bool, screen_position: Vector2) -> bool:
	if graph_node == null or port < 0:
		return false
	var type_name := "Variant"
	if is_output:
		var output_info := _get_value_output_info(graph_node, port)
		if output_info.is_empty():
			return false
		type_name = str(output_info.get("type", "Variant"))
	else:
		if not graph_node.has_meta("value_input_types"):
			return false
		var input_types: Dictionary = graph_node.get_meta("value_input_types")
		if not input_types.has(port):
			return false
		type_name = str(input_types.get(port, "Variant"))
	_pin_context_node = graph_node
	_pin_context_port = port
	_pin_context_is_output = is_output
	_ensure_pin_context_popup()
	var variable_type := _variable_type_for_pin(type_name)
	_pin_context_popup.set_item_disabled(0, variable_type.is_empty())
	var promote_tooltip := "This pin type cannot currently be stored as a sidebar variable."
	if not variable_type.is_empty():
		var direction := "output" if is_output else "input"
		promote_tooltip = "Create a %s Script Variable from this %s pin and wire it automatically." % [variable_type, direction]
	_pin_context_popup.set_item_tooltip(0, promote_tooltip)
	_pin_context_popup.position = Vector2i(screen_position)
	_pin_context_popup.popup()
	return true


func _install_pin_context_target(control: Control, graph_node: GraphNode, port: int, is_output: bool) -> void:
	if control == null or control.has_meta("bfg_pin_context_target"):
		return
	control.set_meta("bfg_pin_context_target", true)
	control.tooltip_text = (control.tooltip_text + "\n\n" if not control.tooltip_text.is_empty() else "") + "Right-click this data pin row to Promote to Variable."
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_pin_context_for(graph_node, port, is_output, control.get_screen_position() + event.position)
			control.accept_event()
	)


func _try_show_data_pin_context(graph_node: GraphNode, local_position: Vector2) -> bool:
	if graph_node == null:
		return false
	var best_distance := 32.0
	var found_port := -1
	var found_output := false
	# Only data input ports qualify; exec input ports are intentionally excluded.
	if graph_node.has_meta("value_input_types"):
		var input_types: Dictionary = graph_node.get_meta("value_input_types")
		for key in input_types.keys():
			var port := int(key)
			if port < 0 or port >= graph_node.get_input_port_count():
				continue
			var distance := local_position.distance_to(graph_node.get_input_port_position(port))
			if distance < best_distance:
				best_distance = distance
				found_port = port
				found_output = false
	for port in range(graph_node.get_output_port_count()):
		var info := _get_value_output_info(graph_node, port)
		if info.is_empty():
			continue
		var distance := local_position.distance_to(graph_node.get_output_port_position(port))
		if distance < best_distance:
			best_distance = distance
			found_port = port
			found_output = true
	if found_port < 0:
		return false
	return _show_pin_context_for(graph_node, found_port, found_output, graph_node.get_screen_position() + local_position)


func _on_pin_context_selected(id: int) -> void:
	if id != 0 or not is_instance_valid(_pin_context_node):
		return
	var pin_type := "Variant"
	var suggested_name := "new_variable"
	if _pin_context_is_output:
		var output_info := _get_value_output_info(_pin_context_node, _pin_context_port)
		pin_type = str(output_info.get("type", "Variant"))
		suggested_name = str(output_info.get("name", "value"))
	else:
		var input_types: Dictionary = _pin_context_node.get_meta("value_input_types", {})
		pin_type = str(input_types.get(_pin_context_port, "Variant"))
		var port_map: Dictionary = _pin_context_node.get_meta("value_input_ports", {})
		suggested_name = str(port_map.get(_pin_context_port, "value"))
	var variable_type := _variable_type_for_pin(pin_type)
	if variable_type.is_empty():
		return
	var variable_name := _unique_local_variable_name(suggested_name)
	var var_data := {
		"name": variable_name,
		"type": variable_type,
		"value": VariableUtils.get_default_value_for_variable_type(variable_type),
		"exported": false,
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100",
		"collapsed": false
	}
	variables_data.append(var_data)
	_save_variables_to_metadata()
	_refresh_variables_ui()
	var info: Dictionary = var_data.duplicate(true)
	info["scope"] = "local"
	if _pin_context_is_output:
		var setter_position := _pin_context_node.position_offset + Vector2(_pin_context_node.size.x + 90.0, 20.0)
		var setter := _create_graph_node("actuator", "VariableActuator", setter_position)
		if setter and setter.has_meta("brick_data"):
			var brick = setter.get_meta("brick_data").get("brick_instance")
			brick.set_property("variable_name", variable_name)
			brick.set_property("mode", "assign")
			setter.title = "Set %s" % variable_name
			var variable_control = _find_property_control(setter, "variable_name")
			if variable_control is LineEdit:
				variable_control.text = variable_name
			_on_connection_request(str(_pin_context_node.name), _pin_context_port, str(setter.name), 1)
	else:
		var getter_position := _pin_context_node.position_offset - Vector2(250.0, 0.0)
		var getter := _create_value_getter_node(info, getter_position)
		if getter:
			_on_connection_request(str(getter.name), 0, str(_pin_context_node.name), _pin_context_port)
	_select_side_tab(0)


func _setup_value_node_context_menu(graph_node: GraphNode) -> void:
	var popup := PopupMenu.new()
	popup.name = "ValueNodeContextMenu"
	popup.add_item("View Documentation", 2)
	var info: Dictionary = graph_node.get_meta("value_node") if graph_node.has_meta("value_node") else {}
	var raw_outputs = info.get("outputs", [])
	var can_split := false
	if raw_outputs is Array and raw_outputs.size() == 1 and raw_outputs[0] is Dictionary:
		can_split = _is_splittable_value_type(str(raw_outputs[0].get("type", info.get("type", "Variant"))))
	if can_split:
		popup.add_item("Recombine Struct Pin" if bool(info.get("split_struct", false)) else "Split Struct Pin", 1)
		popup.add_separator()
	popup.add_item("Delete", 0)
	popup.id_pressed.connect(func(id):
		if not is_instance_valid(graph_node):
			return
		if id == 1:
			_toggle_value_node_split(graph_node)
			return
		if id == 2:
			DocumentationHelper.open_value(graph_node.get_meta("value_node", {}))
			return
		if id == 0:
			_clear_value_bindings_from_source(graph_node)
			graph_edit.remove_child(graph_node)
			graph_node.queue_free()
			_save_graph_to_metadata("Delete Value Node", true, false)
	)
	graph_node.add_child(popup)
	graph_node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _try_show_data_pin_context(graph_node, event.position):
				return
			popup.position = graph_node.get_screen_position() + event.position
			popup.popup()
	)

func _on_main_menu_id_pressed(id: int) -> void:
	if id == 3:
		_create_reroute_node(last_mouse_position)
	elif id == 4:
		_open_search_popup(add_menu.position)


func _on_options_menu_id_pressed(id: int) -> void:
	match id:
		100:
			_on_copy_bricks_pressed()
		101:
			await _on_paste_bricks_pressed()
		102:
			await _on_duplicate_bricks_pressed()
		103:
			_on_save_template_pressed()
		104:
			_on_load_template_pressed()
		105:
			_on_export_graph_image_pressed()
		106:
			await _on_rebuild_from_script_pressed()
		107:
			await _on_clear_bricks_pressed()


func _on_clear_bricks_pressed() -> void:
	if not current_node:
		return

	# Confirm before wiping — this is destructive and not undo-able via the
	# standard undo stack (metadata removal is not tracked by UndoRedo).
	var confirm = ConfirmationDialog.new()
	confirm.title = "Clear Bricks"
	confirm.dialog_text = "Remove all bricks from \"%s\"?\n\nYou can undo this action." % current_node.name
	confirm.ok_button_text = "Clear"
	add_child(confirm)
	confirm.popup_centered()

	await confirm.confirmed
	confirm.queue_free()

	if not current_node or not is_instance_valid(current_node):
		return

	# Clear the visual canvas
	var before_snapshot = _take_graph_snapshot()
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	await get_tree().process_frame

	# Remove all logic-brick metadata keys from the node
	for key in ["blueprints_for_godot", "blueprints_for_godot_graph", "blueprints_for_godot_states",
				"blueprints_for_godot_variables", "blueprints_for_godot_global_usage",
				"blueprints_for_godot_debug_watch_state"]:
		if current_node.has_meta(key):
			current_node.remove_meta(key)

	# Persist the now-empty graph so downstream saves don't resurrect old data
	_save_graph_to_metadata("Clear GDBlueprints", false)
	_mark_scene_modified()
	_record_undo("Clear GDBlueprints", before_snapshot, _take_graph_snapshot())

	# Reset state UI to defaults
	_load_states_from_metadata(true)
	_load_variables_from_metadata()

	push_warning("GDBlueprints: All bricks cleared from '%s'. Script markers remain — remove them manually if needed." % current_node.name)


func _open_search_popup(screen_pos: Vector2, initial_text: String = "") -> void:
	_search_helper.open_search_popup(screen_pos, initial_text)


func _create_reroute_node(position: Vector2) -> void:
	var graph_node = GraphNode.new()
	graph_node.name = "reroute_%d" % next_node_id
	next_node_id += 1
	graph_node.title = ""
	graph_node.position_offset = position
	graph_node.custom_minimum_size = Vector2(30, 0)
	graph_node.size = Vector2(30, 30)
	graph_node.resizable = false
	graph_node.draggable = true

	# Add a minimal spacer child so the slot renders
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 4)
	graph_node.add_child(spacer)

	# Both input and output, type 0, white color (connects to both green and blue)
	graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

	# Mark as reroute so chain extraction skips it
	graph_node.set_meta("is_reroute", true)

	graph_node.dragged.connect(_on_reroute_dragged.bind(graph_node))

	graph_edit.add_child(graph_node)
	_save_graph_to_metadata("Add Reroute", true, false)


func _on_add_menu_item_selected(id: int) -> void:
	var metadata = _get_brick_menu_metadata(id)
	if metadata:
		var brick_type = metadata["type"]
		var brick_class = metadata["class"]
		var before_snapshot = _take_graph_snapshot()
		_create_graph_node(brick_type, brick_class, last_mouse_position)
		_record_undo("Add Blueprint Node", before_snapshot, _take_graph_snapshot())


func _get_brick_menu_metadata(id: int):
	# Auto-discovered bricks use registry-assigned IDs, so do not assume
	# sensors/controllers/actuators live in fixed numeric ranges.
	for menu in [sensors_menu, controllers_menu, actuators_menu]:
		var item_index = menu.get_item_index(id)
		if item_index >= 0:
			return menu.get_item_metadata(item_index)

	for submenu in actuator_submenus.values():
		if not is_instance_valid(submenu):
			continue
		var sub_index = submenu.get_item_index(id)
		if sub_index >= 0:
			return submenu.get_item_metadata(sub_index)

	return null


func _apply_brick_visual_style(graph_node: GraphNode, brick_type: String) -> void:
	var header_color := Color.WHITE
	match brick_type:
		"sensor": header_color = _brick_sensor_color
		"controller": header_color = _brick_controller_color
		"actuator": header_color = _brick_actuator_color
		_: return

	var titlebar := StyleBoxFlat.new()
	titlebar.bg_color = header_color
	titlebar.corner_radius_top_left = 4
	titlebar.corner_radius_top_right = 4
	titlebar.content_margin_left = 10.0
	var titlebar_selected := titlebar.duplicate()
	titlebar_selected.bg_color = header_color.lightened(0.12)
	graph_node.add_theme_stylebox_override("titlebar", titlebar)
	graph_node.add_theme_stylebox_override("titlebar_selected", titlebar_selected)
	# GraphNode exposes its title as a Label inside the titlebar HBox. Style that
	# Label directly; GraphNode itself has no title text color theme property.
	var titlebar_hbox := graph_node.get_titlebar_hbox()
	if titlebar_hbox.get_child_count() > 0 and titlebar_hbox.get_child(0) is Label:
		var title_label := titlebar_hbox.get_child(0) as Label
		title_label.add_theme_color_override("font_color", _brick_header_text_color)
		title_label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		title_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		title_label.add_theme_constant_override("outline_size", 0)

	var body := StyleBoxFlat.new()
	body.bg_color = _brick_body_color
	body.corner_radius_bottom_left = 4
	body.corner_radius_bottom_right = 4
	var body_selected := body.duplicate()
	body_selected.bg_color = _brick_body_color.lightened(0.08)
	graph_node.add_theme_stylebox_override("panel", body)
	graph_node.add_theme_stylebox_override("panel_selected", body_selected)

	# Connections carry the color of the brick type they are flowing toward:
	# sensor -> controller is cyan; controller -> actuator is magenta.
	if brick_type == "sensor":
		graph_node.set_slot(0, false, 0, Color.WHITE, true, 0, _brick_sensor_color)
	elif brick_type == "value":
		graph_node.set_slot(0, false, 0, Color.WHITE, false, 0, Color.WHITE)
	elif brick_type == "controller":
		graph_node.set_slot(0, true, 0, _brick_sensor_color, true, 0, _brick_actuator_color)
	else:
		# Actions have both an execution input and output, matching Unreal's
		# normal exec-pin flow so actions can be chained directly.
		graph_node.set_slot(0, true, 0, _brick_actuator_color, true, 0, _brick_actuator_color)


func _find_property_child_index(graph_node: GraphNode, property_name: String) -> int:
	for i in range(graph_node.get_child_count()):
		var child = graph_node.get_child(i)
		if child.has_meta("property_name") and str(child.get_meta("property_name")) == property_name:
			return i
	return -1


func _value_pin_color(type_name: String) -> Color:
	return PinTypeRegistry.color(type_name)


func _normalized_pin_type(type_name: String) -> String:
	return PinTypeRegistry.normalize(type_name)


func _pin_types_compatible(source_type: String, target_type: String) -> bool:
	return PinTypeRegistry.compatible(source_type, target_type)


func _pin_conversion_suggestion(source_type: String, target_type: String) -> String:
	return PinTypeRegistry.conversion_suggestion(source_type, target_type)


func _annotate_value_input_type(graph_node: GraphNode, child_index: int, property_name: String, type_name: String, input_port: int) -> void:
	if child_index < 0 or child_index >= graph_node.get_child_count():
		return
	var row = graph_node.get_child(child_index)
	if row is Control:
		_install_pin_context_target(row, graph_node, input_port, false)
	if not row is Container:
		return
	for existing in row.get_children():
		if existing is Label:
			_install_pin_context_target(existing, graph_node, input_port, false)
		if existing.has_meta("bfg_pin_type_badge"):
			return
	var badge := Label.new()
	badge.text = "[%s]" % _normalized_pin_type(type_name)
	badge.set_meta("bfg_pin_type_badge", true)
	badge.add_theme_color_override("font_color", _value_pin_color(type_name))
	var normalized_type := _normalized_pin_type(type_name)
	badge.tooltip_text = "%s expects %s data. %s\nPin colors are a quick hint; the type label is authoritative." % [property_name.replace("_", " ").capitalize(), normalized_type, PinTypeRegistry.display_help(normalized_type)]
	row.add_child(badge)
	_install_pin_context_target(badge, graph_node, input_port, false)


func _append_value_input_row(graph_node: GraphNode, label_text: String, property_name: String, type_name: String, input_port: int, port_map: Dictionary) -> int:
	var row := HBoxContainer.new()
	row.set_meta("bfg_virtual_value_input", true)
	row.set_meta("property_name", property_name)
	var label := Label.new()
	label.text = "%s  %s" % [label_text, type_name]
	var normalized_type := _normalized_pin_type(type_name)
	label.tooltip_text = "Blueprint value input. Expected type: %s. %s\nIncompatible types are blocked and will suggest a conversion." % [normalized_type, PinTypeRegistry.display_help(normalized_type)]
	row.add_child(label)
	_install_pin_context_target(label, graph_node, input_port, false)
	_install_pin_context_target(row, graph_node, input_port, false)
	graph_node.add_child(row)
	var child_index := graph_node.get_child_count() - 1
	graph_node.set_slot(child_index, true, 1, _value_pin_color(type_name), false, 0, Color.WHITE)
	port_map[input_port] = property_name
	return input_port + 1


func _pin_type_from_variant_type(property_type: int) -> String:
	return PinTypeRegistry.type_from_variant_type(property_type)


func _get_brick_input_definitions(brick_instance) -> Array:
	if brick_instance == null:
		return []
	var legacy = brick_instance.get_property_definitions() if brick_instance.has_method("get_property_definitions") else []
	if legacy is Array and not legacy.is_empty():
		return legacy
	if brick_instance.has_method("get_blueprint_definition"):
		var definition = brick_instance.call("get_blueprint_definition")
		if definition is Dictionary:
			var inputs = definition.get("inputs", [])
			if inputs is Array:
				return inputs
	return []


func _property_is_blueprint_value_input(prop_def: Dictionary, brick_instance) -> bool:
	if prop_def.has("blueprint_pin"):
		return bool(prop_def.get("blueprint_pin", false))
	var prop_name := str(prop_def.get("name", ""))
	if prop_name.is_empty():
		return false
	var prop_type := int(prop_def.get("type", TYPE_NIL))
	var hint := int(prop_def.get("hint", PROPERTY_HINT_NONE))
	# Enum/resource/path/action/group/mode choices describe how the node itself is
	# configured, rather than runtime data flowing through a Blueprint pin.
	if hint not in [PROPERTY_HINT_NONE, PROPERTY_HINT_RANGE]:
		return false
	var lower := prop_name.to_lower()
	if lower.ends_with("_name") or lower.ends_with("_path") or lower.ends_with("_id") or lower.ends_with("_source"):
		return false
	if lower in ["event", "effect", "behavior", "scope", "slot", "target", "property"]:
		return false
	var config_tokens := ["mode", "operation", "method", "variable_name", "node_name", "node_path", "target_node_name", "script_path", "resource", "scene", "animation", "action", "group", "state_id", "axis", "space", "transition", "ease", "bus", "property_name", "type"]
	for token in config_tokens:
		if lower == token or lower.ends_with("_" + token) or lower.begins_with(token + "_"):
			return false
	# Primitive literals are safe for the generic value-binding compiler. Complex
	# structs are exposed when the brick explicitly declares an expression slot.
	if prop_type in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT, TYPE_FLOAT]:
		return true
	if prop_type == TYPE_BOOL:
		return brick_instance.properties.has(prop_name + "_expression")
	if prop_type in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D]:
		return brick_instance.properties.has(prop_name + "_expression")
	return false

func _setup_value_input_pins(graph_node: GraphNode, brick_class: String) -> void:
	if not graph_node.has_meta("brick_data"):
		return
	var brick_instance = graph_node.get_meta("brick_data").get("brick_instance")
	if brick_instance == null:
		return
	_setup_declared_exec_inputs(graph_node, brick_instance)
	var bindings: Array[Dictionary] = []
	var seen: Dictionary = {}

	# Explicit BFG-native pins override the general heuristics and provide accurate types.
	var explicit: Array[Dictionary] = []
	if brick_class == "PrintStringActuator" or brick_class == "PrintWarningActuator":
		explicit = [{"property":"text", "label":"Text", "type":"String"}]
	elif brick_class == "VariableActuator":
		explicit = [{"property":"value", "label":"Value", "type":"Variant"}]
	elif brick_class == "DestroyActorActuator":
		explicit = [{"property":"target_node_name", "label":"Target", "type":"Node"}]
	elif brick_class == "BranchController":
		explicit = [{"property":"condition", "label":"Condition", "type":"Bool"}]
	elif brick_class == "CastToScriptController":
		explicit = [{"property":"target", "label":"Target", "type":"Object"}]
	for item in explicit:
		bindings.append(item)
		seen[str(item.get("property", ""))] = true

	# Automatically expose ordinary runtime literal fields. This is deliberately
	# separate from configuration choices such as Mode/Action/Animation/Script.
	for prop_def in _get_brick_input_definitions(brick_instance):
		if not prop_def is Dictionary or not _property_is_blueprint_value_input(prop_def, brick_instance):
			continue
		var prop_name := str(prop_def.get("name", ""))
		if seen.has(prop_name):
			continue
		bindings.append({
			"property": prop_name,
			"label": str(prop_def.get("pin_label", prop_name.replace("_", " ").capitalize())),
			"type": str(prop_def.get("pin_type", _pin_type_from_variant_type(int(prop_def.get("type", TYPE_NIL)))))
		})
		seen[prop_name] = true

	var port_map: Dictionary = {}
	var type_map: Dictionary = {}
	var brick_type := str(graph_node.get_meta("brick_data").get("brick_type", ""))
	# Events/Sensors have no execution input, so their first data input is port 0.
	# Flow/Action nodes reserve input port 0 for execution.
	var input_port: int = brick_instance.get_exec_input_definitions().size()
	for binding in bindings:
		var prop_name := str(binding.get("property", ""))
		var type_name := str(binding.get("type", "Variant"))
		var child_index := _find_property_child_index(graph_node, prop_name)
		if child_index >= 0:
			graph_node.set_slot(child_index, true, 1, _value_pin_color(type_name), false, 0, Color.WHITE)
			_annotate_value_input_type(graph_node, child_index, prop_name, type_name, input_port)
			port_map[input_port] = prop_name
			type_map[input_port] = _normalized_pin_type(type_name)
			input_port += 1
		else:
			# Properties inside collapsible Details groups cannot own GraphNode slots;
			# expose a compact runtime pin row for them instead.
			type_map[input_port] = _normalized_pin_type(type_name)
			input_port = _append_value_input_row(graph_node, str(binding.get("label", prop_name)), prop_name, type_name, input_port, port_map)

	# Set Actor Transform keeps its three high-level vector pins visible regardless
	# of the legacy details mode below them.
	if brick_class == "TransformsActuator":
		for transform_binding in [
			{"property":"position_variable", "label":"Position", "type":"Vector3"},
			{"property":"rotation_variable", "label":"Rotation", "type":"Vector3"},
			{"property":"scale_variable", "label":"Scale", "type":"Vector3"}
		]:
			var pname := str(transform_binding["property"])
			if not port_map.values().has(pname):
				type_map[input_port] = _normalized_pin_type(str(transform_binding["type"]))
				input_port = _append_value_input_row(graph_node, str(transform_binding["label"]), pname, str(transform_binding["type"]), input_port, port_map)

	if not port_map.is_empty():
		graph_node.set_meta("value_input_ports", port_map)
		graph_node.set_meta("value_input_types", type_map)

func _setup_declared_exec_inputs(graph_node: GraphNode, brick_instance) -> void:
	var definitions: Array = brick_instance.get_exec_input_definitions()
	if definitions.size() <= 1 or graph_node.has_meta("exec_input_ports"): return
	graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
	var ports: Dictionary = {0:str(definitions[0].id)}
	for index in range(1, definitions.size()):
		var label := Label.new()
		label.text = str(definitions[index].name)
		graph_node.add_child(label)
		graph_node.move_child(label, index)
		graph_node.set_slot(index, true, 0, Color.WHITE, false, 0, Color.WHITE)
		ports[index] = str(definitions[index].id)
	graph_node.set_meta("exec_input_ports", ports)

func _setup_declared_exec_outputs(graph_node: GraphNode, brick_instance) -> void:
	if graph_node == null or brick_instance == null or not brick_instance.has_method("get_exec_output_definitions"):
		return
	var definitions = brick_instance.call("get_exec_output_definitions")
	if not (definitions is Array):
		return
	if definitions.is_empty():
		graph_node.set_slot(0, not brick_instance.get_exec_input_definitions().is_empty(), 0, Color.WHITE, false, 0, Color.WHITE)
		graph_node.set_meta("exec_output_ports", {})
		return
	# Ordinary nodes use the built-in right-side exec port on row 0 for Then.
	# Only materialize named rows when a node declares custom/multiple flow exits.
	if definitions.size() == 1:
		var only = definitions[0]
		if only is Dictionary and str(only.get("id", "then")) == "then":
			return
	graph_node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
	var port_map: Dictionary = {}
	for port_index in range(definitions.size()):
		var output = definitions[port_index]
		if not output is Dictionary:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(output.get("name", output.get("id", "Then")))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(label)
		graph_node.add_child(row)
		var child_index := graph_node.get_child_count() - 1
		var port_color := Color.WHITE
		var color_text := str(output.get("color", ""))
		if not color_text.is_empty():
			port_color = Color(color_text)
		graph_node.set_slot(child_index, false, 0, Color.WHITE, true, 0, port_color)
		port_map[port_index] = str(output.get("id", "then"))
	if not port_map.is_empty():
		graph_node.set_meta("exec_output_ports", port_map)


# Compatibility wrappers retained for older helper code and third-party addons.
func _setup_branch_exec_outputs(graph_node: GraphNode, _brick_class: String) -> void:
	if graph_node and graph_node.has_meta("brick_data"):
		_setup_declared_exec_outputs(graph_node, graph_node.get_meta("brick_data").get("brick_instance"))


func _setup_cast_exec_outputs(graph_node: GraphNode, _brick_class: String) -> void:
	# _setup_branch_exec_outputs now covers any custom flow definition. Avoid
	# duplicating rows if legacy code invokes both compatibility wrappers.
	if graph_node and graph_node.has_meta("exec_output_ports"):
		return
	if graph_node and graph_node.has_meta("brick_data"):
		_setup_declared_exec_outputs(graph_node, graph_node.get_meta("brick_data").get("brick_instance"))


func _setup_brick_value_outputs(graph_node: GraphNode, brick_instance, brick_class: String) -> void:
	if brick_instance == null or not brick_instance.has_method("get_value_output_definitions"):
		return
	if str(brick_instance.get_execution_spec().get("kind")) in ["for", "foreach", "function_call"]:
		brick_instance.properties["_execution_id"] = str(graph_node.name)
	var definitions = brick_instance.call("get_value_output_definitions")
	if not (definitions is Array) or definitions.is_empty():
		return
	# Data outputs follow the node's execution outputs. Ordinary nodes reserve
	# output port 0 for Then; custom flow nodes reserve however many exits they declare.
	var output_port: int = brick_instance.get_exec_output_definitions().size()
	var port_map: Dictionary = {}
	for index in range(definitions.size()):
		var output = definitions[index]
		if not output is Dictionary:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		var out_type := _normalized_pin_type(str(output.get("type", "Variant")))
		label.text = "%s  [%s]" % [str(output.get("name", "Value")), out_type]
		label.tooltip_text = "Data output type: %s" % out_type
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(label)
		_install_pin_context_target(label, graph_node, output_port, true)
		_install_pin_context_target(row, graph_node, output_port, true)
		graph_node.add_child(row)
		var child_index := graph_node.get_child_count() - 1
		graph_node.set_slot(child_index, false, 0, Color.WHITE, true, 1, _value_pin_color(out_type))
		port_map[output_port] = {"definition_index":index}
		output_port += 1
	if not port_map.is_empty():
		graph_node.set_meta("value_output_ports", port_map)


func _get_value_output_info(source_node: GraphNode, from_port: int) -> Dictionary:
	if source_node == null:
		return {}
	if source_node.has_meta("value_node"):
		var info: Dictionary = source_node.get_meta("value_node")
		var outputs := _normalized_value_outputs(info)
		if from_port >= 0 and from_port < outputs.size() and outputs[from_port] is Dictionary:
			return outputs[from_port]
		return {}
	# Executable nodes can expose typed data outputs in addition to exec flow.
	if source_node.has_meta("value_output_ports") and source_node.has_meta("brick_data"):
		var port_map: Dictionary = source_node.get_meta("value_output_ports")
		var entry = port_map.get(from_port, {})
		if entry is Dictionary:
			var brick = source_node.get_meta("brick_data").get("brick_instance")
			if brick != null and brick.has_method("get_value_output_definitions"):
				var definitions = brick.call("get_value_output_definitions")
				var index := int(entry.get("definition_index", -1))
				if definitions is Array and index >= 0 and index < definitions.size() and definitions[index] is Dictionary:
					return definitions[index]
	return {}


func _apply_value_binding(target_node: GraphNode, property_name: String, source_node: GraphNode, from_port: int = 0) -> void:
	if not target_node.has_meta("brick_data") or _get_value_output_info(source_node, from_port).is_empty():
		return
	var brick = target_node.get_meta("brick_data").get("brick_instance")
	if brick == null:
		return
	var output_info := _get_value_output_info(source_node, from_port)
	var expression := str(output_info.get("expression", "")).strip_edges()
	brick.set_property(property_name + "_expression", expression)
	var control = _find_property_control(target_node, property_name)
	var driven_tooltip := "Driven by %s.%s [%s]. Disconnect the data wire to edit this value manually." % [source_node.title, str(output_info.get("name", "Value")), _normalized_pin_type(str(output_info.get("type", "Variant")))]
	if control is LineEdit:
		control.editable = false
		control.modulate = Color(0.55, 0.55, 0.55, 1.0)
		control.set_meta("bfg_value_bound", true)
		control.tooltip_text = driven_tooltip
	elif control is CheckBox:
		control.disabled = true
		control.modulate = Color(0.55, 0.55, 0.55, 1.0)
		control.set_meta("bfg_value_bound", true)
		control.tooltip_text = driven_tooltip
	elif control is SpinBox:
		control.editable = false
		control.modulate = Color(0.55, 0.55, 0.55, 1.0)
		control.set_meta("bfg_value_bound", true)
		control.tooltip_text = driven_tooltip

func _clear_value_binding(target_node: GraphNode, property_name: String) -> void:
	if not target_node.has_meta("brick_data"):
		return
	var brick = target_node.get_meta("brick_data").get("brick_instance")
	if brick:
		brick.set_property(property_name + "_expression", "")
	var control = _find_property_control(target_node, property_name)
	var restored_tooltip := ""
	if brick != null and brick.has_method("get_tooltip_definitions"):
		var tooltip_defs = brick.call("get_tooltip_definitions")
		if tooltip_defs is Dictionary:
			restored_tooltip = str(tooltip_defs.get(property_name, ""))
	if restored_tooltip.is_empty() and control is CheckBox:
		restored_tooltip = "Checked = True; unchecked = False."
	if control is LineEdit:
		control.editable = true
		control.modulate = Color.WHITE
		control.set_meta("bfg_value_bound", false)
		control.tooltip_text = restored_tooltip
	elif control is CheckBox:
		control.disabled = false
		control.modulate = Color.WHITE
		control.set_meta("bfg_value_bound", false)
		control.tooltip_text = restored_tooltip
	elif control is SpinBox:
		control.editable = true
		control.modulate = Color.WHITE
		control.set_meta("bfg_value_bound", false)
		control.tooltip_text = restored_tooltip

func _find_property_control(graph_node: GraphNode, property_name: String) -> Control:
	var found = graph_node.find_child("PropertyControl_" + property_name, true, false)
	return found as Control if found is Control else null

func _clear_value_bindings_from_source(source_node: GraphNode) -> void:
	if source_node == null:
		return
	for conn in graph_edit.get_connection_list():
		if str(conn.get("from_node", "")) != str(source_node.name):
			continue
		var target = graph_edit.get_node_or_null(NodePath(conn.get("to_node", "")))
		if target and target.has_meta("value_input_ports"):
			var prop_name := str(target.get_meta("value_input_ports").get(int(conn.get("to_port", -1)), ""))
			if not prop_name.is_empty():
				_clear_value_binding(target, prop_name)


func _sync_value_bindings_from_connections() -> void:
	var incoming: Dictionary = {}
	for edge in graph_edit.get_connection_list():
		var key := str(edge.to_node)
		if not incoming.has(key): incoming[key] = []
		incoming[key].append(edge)
	var done: Dictionary = {}
	for child in graph_edit.get_children():
		if child is GraphNode: _sync_value_inputs(child, incoming, {}, done)

func _sync_value_inputs(target: GraphNode, incoming: Dictionary, visiting: Dictionary, done: Dictionary) -> void:
	if done.has(target.name) or visiting.has(target.name): return
	visiting[target.name] = true
	for conn in incoming.get(str(target.name), []):
		var source := graph_edit.get_node_or_null(NodePath(conn.from_node)) as GraphNode
		if source == null or _get_value_output_info(source, int(conn.from_port)).is_empty(): continue
		var property_name := str(target.get_meta("value_input_ports", {}).get(int(conn.to_port), ""))
		if property_name.is_empty(): continue
		_sync_value_inputs(source, incoming, visiting, done)
		_apply_value_binding(target, property_name, source, int(conn.from_port))
	visiting.erase(target.name)
	done[target.name] = true

func _is_splittable_value_type(type_name: String) -> bool:
	return PinTypeRegistry.is_splittable(type_name)

func _split_struct_outputs(type_name: String, expression: String) -> Array:
	return PinTypeRegistry.split_outputs(type_name, expression)


func _normalized_value_outputs(value_info: Dictionary) -> Array:
	var outputs = value_info.get("outputs", [])
	var result: Array = []
	if outputs is Array and not outputs.is_empty():
		result = outputs.duplicate(true)
	else:
		result = [{
			"name":"Value",
			"type":str(value_info.get("type", "Variant")),
			"expression":str(value_info.get("expression", ""))
		}]

	# Unreal-style Split Struct for variable getters. Keep the aggregate output at
	# port 0, then expose X/Y/Z/etc. so existing connections remain stable.
	if bool(value_info.get("split_struct", false)) and result.size() == 1:
		var base: Dictionary = result[0]
		var type_name := str(base.get("type", value_info.get("type", "Variant")))
		var expression := str(base.get("expression", value_info.get("expression", "")))
		result.append_array(_split_struct_outputs(type_name, expression))
	return result

func _build_value_node_visual(graph_node: GraphNode, value_info: Dictionary) -> void:
	var godot_term := str(value_info.get("godot_term", ""))
	if not godot_term.is_empty():
		var subtitle := Label.new()
		subtitle.text = godot_term
		subtitle.add_theme_font_size_override("font_size", 10)
		subtitle.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
		graph_node.add_child(subtitle)
	var output_port := 0
	for output in _normalized_value_outputs(value_info):
		if not output is Dictionary:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s  %s" % [str(output.get("name", "Value")), str(output.get("type", "Variant"))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(label)
		_install_pin_context_target(label, graph_node, output_port, true)
		_install_pin_context_target(row, graph_node, output_port, true)
		graph_node.add_child(row)
		var child_index := graph_node.get_child_count() - 1
		graph_node.set_slot(child_index, false, 0, Color.WHITE, true, 1, _value_pin_color(str(output.get("type", "Variant"))))
		output_port += 1
	graph_node.set_meta("value_node", value_info)
	if str(value_info.get("kind", "")) == "node":
		var browse := Button.new()
		browse.text = "Browse Properties…"
		browse.tooltip_text = "Discover Godot properties and script variables; add a connected Get or Set node."
		browse.pressed.connect(_browse_reference_properties.bind(graph_node))
		graph_node.add_child(browse)


func _resolve_property_reference(source: GraphNode, output_port: int = 0) -> Node:
	return _reference_helper._resolve_property_reference(source, output_port)

func _resolve_property_target(graph_node: GraphNode) -> Node:
	return _reference_helper._resolve_property_target(graph_node)

func _browse_object_property(graph_node: GraphNode) -> void:
	_reference_helper._browse_object_property(graph_node)

func _browse_reference_properties(source: GraphNode) -> void:
	_reference_helper._browse_reference_properties(source)

func _create_registry_value_node(brick_instance, brick_class: String, position: Vector2) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = "value_node_%d" % next_node_id
	next_node_id += 1
	graph_node.position_offset = position
	var info := BrickRegistry.get_brick_info(brick_class)
	graph_node.title = str(info.get("name", brick_instance.get_brick_name()))
	graph_node.resizable = false
	graph_node.draggable = true
	var outputs: Array = []
	if brick_instance.has_method("get_value_output_definitions"):
		outputs = brick_instance.call("get_value_output_definitions")
	var value_info := {
		"kind":"pure",
		"name":graph_node.title,
		"type":"Variant",
		"godot_term":str(info.get("godot_term", "")),
		"brick_class":brick_class,
		"outputs":outputs
	}
	_build_value_node_visual(graph_node, value_info)
	_setup_value_node_context_menu(graph_node)
	_add_view_code_button(graph_node)
	graph_edit.add_child(graph_node)
	_save_graph_to_metadata("Add Value Node", false)
	return graph_node


func _create_graph_node(brick_type: String, brick_class: String, position: Vector2) -> GraphNode:
	# Create the brick instance
	var brick_instance = _create_brick_instance(brick_class)
	if not brick_instance:
		push_error("GDBlueprints: Failed to create brick instance for: " + brick_class)
		return null

	# Pure value nodes have data outputs but no execution pins.
	if brick_type == "value" and brick_instance.get_property_definitions().is_empty():
		return _create_registry_value_node(brick_instance, brick_class, position)

	# Let bricks choose smarter defaults from the node they are being added to.
	if current_node and brick_instance.has_method("apply_context_defaults"):
		brick_instance.call("apply_context_defaults", current_node)

	# Create the GraphNode
	var graph_node = BrickGraphNode.new()
	graph_node.name = "brick_node_%d" % next_node_id
	next_node_id += 1

	graph_node.position_offset = position
	var _ui_info = BrickRegistry.get_brick_info(brick_class)
	graph_node.title = str(_ui_info.get("name", brick_instance.get_brick_name()))

	# Store brick data
	graph_node.set_meta("brick_data", {
		"brick_type": brick_type,
		"brick_class": brick_class,
		"brick_instance": brick_instance
	})

	# Color-code brick headers and their connection ports.
	_apply_brick_visual_style(graph_node, brick_type)

	# Create UI for brick properties
	_create_brick_ui(graph_node, brick_instance)
	_setup_value_input_pins(graph_node, brick_class)
	_setup_declared_exec_outputs(graph_node, brick_instance)
	_setup_brick_value_outputs(graph_node, brick_instance, brick_class)

	if brick_type == "controller":
		_update_controller_title(graph_node, brick_instance)
	_add_view_code_button(graph_node)

	# Add context menu for duplicate/delete
	_setup_graph_node_context_menu(graph_node)

	# Connect drag signal for frame detection
	graph_node.dragged.connect(_on_brick_node_dragged.bind(graph_node))

	graph_edit.add_child(graph_node)
	_save_graph_to_metadata("Add Blueprint Node", false)
	return graph_node



func _create_graph_node_from_data(node_data: Dictionary) -> GraphNode:
	# Handle pure value/getter nodes (variables, SceneTree references, and pure value bricks).
	if node_data.get("is_value_node", false):
		var value_info: Dictionary = node_data.get("value_node", {}).duplicate(true)
		var graph_node := GraphNode.new()
		graph_node.name = node_data["id"]
		graph_node.position_offset = node_data["position"]
		graph_node.title = str(value_info.get("name", "Value"))
		if str(value_info.get("kind", "variable")) in ["variable", "node"] and not graph_node.title.begins_with("Get "):
			graph_node.title = "Get %s" % graph_node.title
		graph_node.resizable = false
		graph_node.draggable = true
		_build_value_node_visual(graph_node, value_info)
		_setup_value_node_context_menu(graph_node)
		_add_view_code_button(graph_node)
		graph_edit.add_child(graph_node)
		return graph_node

	# Handle reroute nodes
	if node_data.get("is_reroute", false):
		var graph_node = GraphNode.new()
		graph_node.name = node_data["id"]
		graph_node.title = ""
		graph_node.position_offset = node_data["position"]
		graph_node.custom_minimum_size = Vector2(30, 0)
		graph_node.size = Vector2(30, 30)
		graph_node.resizable = false
		graph_node.draggable = true
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(10, 4)
		graph_node.add_child(spacer)
		graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
		graph_node.set_meta("is_reroute", true)
		graph_node.dragged.connect(_on_reroute_dragged.bind(graph_node))
		graph_edit.add_child(graph_node)
		return graph_node

	var brick_type = node_data["brick_type"]
	var brick_class = node_data["brick_class"]
	var position = node_data["position"]
	var properties = node_data.get("properties", {})
	var instance_name = node_data.get("instance_name", "")
	var debug_enabled = node_data.get("debug_enabled", false)
	var debug_message = node_data.get("debug_message", "")

	# Create brick instance
	var brick_instance = _create_brick_instance(brick_class)
	if not brick_instance:
		return null

	# Restore instance name
	if not instance_name.is_empty():
		brick_instance.set_instance_name(instance_name)

	# Restore debug fields
	brick_instance.debug_enabled = debug_enabled
	brick_instance.debug_message = debug_message

	# Restore properties
	for prop_name in properties:
		brick_instance.set_property(prop_name, properties[prop_name])

	# If this is a WaypointPathActuator, restore pos_# Node3D children
	if brick_class == "WaypointPathActuator" and current_node is Node3D:
		var WaypointPathActuator = load("res://addons/GDBlueprints/bricks/actuators/3d/waypoint_path_actuator.gd")
		if WaypointPathActuator:
			WaypointPathActuator.sync_waypoint_nodes(current_node, brick_instance)

	# Restore pos_# Node2D children for the 2D Waypoint Path actuator.
	if brick_class == "WaypointPath2DActuator" and current_node is Node2D:
		var WaypointPath2DActuator = load("res://addons/GDBlueprints/bricks/actuators/2d/waypoint_path_2d_actuator.gd")
		if WaypointPath2DActuator:
			WaypointPath2DActuator.sync_waypoint_nodes(current_node, brick_instance)

	# Create GraphNode
	var graph_node = BrickGraphNode.new()
	graph_node.name = node_data["id"]
	graph_node.position_offset = position
	var _ui_info = BrickRegistry.get_brick_info(brick_class)
	graph_node.title = str(_ui_info.get("name", brick_instance.get_brick_name()))

	# Store brick data
	graph_node.set_meta("brick_data", {
		"brick_type": brick_type,
		"brick_class": brick_class,
		"brick_instance": brick_instance
	})

	# Color-code brick headers and their connection ports.
	_apply_brick_visual_style(graph_node, brick_type)

	# Create UI
	_create_brick_ui(graph_node, brick_instance)
	_setup_value_input_pins(graph_node, brick_class)
	_setup_declared_exec_outputs(graph_node, brick_instance)
	_setup_brick_value_outputs(graph_node, brick_instance, brick_class)

	if brick_type == "controller":
		_update_controller_title(graph_node, brick_instance)
	_add_view_code_button(graph_node)

	# Add context menu for duplicate/delete
	_setup_graph_node_context_menu(graph_node)

	# Connect drag signal for frame detection
	graph_node.dragged.connect(_on_brick_node_dragged.bind(graph_node))

	graph_edit.add_child(graph_node)
	return graph_node


func _create_brick_instance(brick_class: String):
	var script_path: String = BrickRegistry.get_script_path(brick_class)
	if script_path.is_empty():
		push_error("GDBlueprints: No script registered for brick class: " + brick_class)
		return null

	# Ensure the base class is resident in the resource cache before loading
	# the brick script. Scripts that use extends "res://..." fail to instantiate
	# with .new() if their base class hasn't been loaded yet.
	var _base = load("res://addons/GDBlueprints/core/blueprint_node.gd")
	if not _base:
		push_error("GDBlueprints: could not load base class blueprint_node.gd")
		return null

	var brick_script = load(script_path)
	if not brick_script:
		push_error("GDBlueprints: Failed to load script: " + script_path)
		return null

	if not brick_script.can_instantiate():
		push_error("GDBlueprints: Script cannot be instantiated (check for parse errors): " + script_path)
		return null

	return brick_script.new()


func _create_brick_ui(graph_node: GraphNode, brick_instance) -> void:
	_property_helper._create_brick_ui(graph_node, brick_instance)


func _on_lock_toggled() -> void:
	# Toggle the lock state to prevent/allow selection changes
	is_locked = not is_locked

	if is_locked:
		lock_button.text = "🔒"  # Locked icon
		lock_button.modulate = Color(1.0, 0.8, 0.8)  # Slight red tint
		if current_node:
			node_info_label.text = "🔒 Locked: " + current_node.name
	else:
		lock_button.text = "🔓"  # Unlocked icon
		lock_button.modulate = Color.WHITE
		if current_node:
			node_info_label.text = "Selected: " + current_node.name


func _setup_graph_node_context_menu(graph_node: GraphNode) -> void:
	# Set up right-click context menu for a graph node
	var popup_menu = PopupMenu.new()
	popup_menu.add_item("Duplicate", 0)
	popup_menu.add_item("View Documentation", 2)
	popup_menu.add_separator()
	popup_menu.add_item("Delete", 1)

	popup_menu.id_pressed.connect(_on_graph_node_context_menu.bind(graph_node))
	graph_node.add_child(popup_menu)

	# Connect gui_input to show context menu on right-click
	graph_node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				if _try_show_data_pin_context(graph_node, event.position):
					return
				popup_menu.position = graph_node.get_screen_position() + event.position
				popup_menu.popup()
	)


func _on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
	if id == 2:
		if graph_node.has_meta("brick_data"):
			var brick_data: Dictionary = graph_node.get_meta("brick_data")
			DocumentationHelper.open_brick(str(brick_data.get("brick_class", "")), current_brick_domain)
		return
	await _clipboard_helper.on_graph_node_context_menu(id, graph_node)


func _duplicate_graph_node(original_node: GraphNode) -> GraphNode:
	return await _clipboard_helper.duplicate_graph_node(original_node)


func _generate_unique_brick_name(base_name: String) -> String:
	return _clipboard_helper.generate_unique_brick_name(base_name)


func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	var before_snapshot = _take_graph_snapshot()

	# Check if this is a sensor → actuator direct connection
	var from_graph_node = graph_edit.get_node_or_null(NodePath(from_node))
	var to_graph_node = graph_edit.get_node_or_null(NodePath(to_node))

	if from_graph_node and to_graph_node:
		var from_data = from_graph_node.get_meta("brick_data") if from_graph_node.has_meta("brick_data") else null
		var to_data = to_graph_node.get_meta("brick_data") if to_graph_node.has_meta("brick_data") else null

	# Keep execution and data wiring distinct. This catches accidental attempts
	# to plug an exec wire into a value socket (or a data wire into exec).
	var source_value_info := _get_value_output_info(from_graph_node, from_port) if from_graph_node else {}
	var target_is_value_port := false
	if to_graph_node and to_graph_node.has_meta("value_input_ports"):
		target_is_value_port = to_graph_node.get_meta("value_input_ports").has(to_port)
	if not source_value_info.is_empty() and not target_is_value_port:
		var data_to_exec_message := "Data output [%s] cannot connect to an execution pin. Connect it to a matching typed data input instead." % _normalized_pin_type(str(source_value_info.get("type", "Variant")))
		if to_graph_node:
			_set_apply_warning(to_graph_node, [data_to_exec_message])
		push_warning("GDBlueprints: " + data_to_exec_message)
		return
	if source_value_info.is_empty() and target_is_value_port:
		var exec_to_data_message := "Execution pins cannot connect to data inputs. Use a typed data output that matches this pin."
		_set_apply_warning(to_graph_node, [exec_to_data_message])
		push_warning("GDBlueprints: " + exec_to_data_message)
		return

	# Value-pin connection (separate port type from execution flow).
	if from_graph_node and not source_value_info.is_empty() and to_graph_node and to_graph_node.has_meta("value_input_ports"):
		var port_map: Dictionary = to_graph_node.get_meta("value_input_ports")
		var prop_name := str(port_map.get(to_port, ""))
		if not prop_name.is_empty():
			var output_info := source_value_info
			var source_type := _normalized_pin_type(str(output_info.get("type", "Variant")))
			var input_types: Dictionary = to_graph_node.get_meta("value_input_types") if to_graph_node.has_meta("value_input_types") else {}
			var target_type := _normalized_pin_type(str(input_types.get(to_port, "Variant")))
			if not _pin_types_compatible(source_type, target_type):
				var type_message := "Type mismatch: %s cannot connect to %s. %s" % [source_type, target_type, _pin_conversion_suggestion(source_type, target_type)]
				_set_apply_warning(to_graph_node, [type_message])
				push_warning("GDBlueprints: " + type_message)
				return
			# One source per value input, matching Blueprint pin behavior.
			for existing in graph_edit.get_connection_list():
				if existing["to_node"] == to_node and int(existing["to_port"]) == to_port:
					graph_edit.disconnect_node(existing["from_node"], existing["from_port"], existing["to_node"], existing["to_port"])
			graph_edit.connect_node(from_node, from_port, to_node, to_port)
			_apply_value_binding(to_graph_node, prop_name, from_graph_node, from_port)
			_save_graph_to_metadata("Connect Value Pin", false)
			_record_undo("Connect Value Pin", before_snapshot, _take_graph_snapshot())
			return

	# Normal connection (sensor→controller or controller→actuator)
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_save_graph_to_metadata("Connect GDBlueprints", false)
	_record_undo("Connect GDBlueprints", before_snapshot, _take_graph_snapshot())


func _ensure_data_drag_popup() -> void:
	if is_instance_valid(_data_drag_popup):
		return
	_data_drag_popup = PopupMenu.new()
	_data_drag_popup.name = "DataPinDragMenu"
	_data_drag_popup.add_item("Promote to Variable", 0)
	_data_drag_popup.add_separator()
	_data_drag_popup.add_item("Search Compatible Nodes...", 1)
	_data_drag_popup.id_pressed.connect(_on_data_drag_popup_selected)
	add_child(_data_drag_popup)


func _show_data_drag_popup(source: GraphNode, from_port: int, release_position: Vector2) -> void:
	_ensure_data_drag_popup()
	var output_info := _get_value_output_info(source, from_port)
	var type_name := str(output_info.get("type", "Variant"))
	var variable_type := _variable_type_for_pin(type_name)
	_data_drag_popup.set_item_disabled(0, variable_type.is_empty())
	var promote_tip := "This data type cannot currently be stored as a sidebar variable."
	if not variable_type.is_empty():
		promote_tip = "Create a %s Script Variable and wire this output into a Set Variable node." % variable_type
	_data_drag_popup.set_item_tooltip(0, promote_tip)
	_data_drag_popup.set_item_text(2, "Search Compatible Nodes...")
	_data_drag_popup.set_item_tooltip(2, "Open node search and connect this %s output to a compatible data input." % _normalized_pin_type(type_name))
	_data_drag_popup.position = Vector2i(graph_edit.get_screen_position() + release_position)
	_data_drag_popup.popup()


func _show_input_data_drag_popup(target: GraphNode, to_port: int, release_position: Vector2) -> void:
	_ensure_data_drag_popup()
	var input_types: Dictionary = target.get_meta("value_input_types", {})
	var type_name := str(input_types.get(to_port, "Variant"))
	var variable_type := _variable_type_for_pin(type_name)
	_data_drag_popup.set_item_disabled(0, variable_type.is_empty())
	var promote_tip := "This data type cannot currently be stored as a sidebar variable."
	if not variable_type.is_empty():
		promote_tip = "Create a %s Script Variable, add its getter, and wire it into this input." % variable_type
	_data_drag_popup.set_item_tooltip(0, promote_tip)
	_data_drag_popup.set_item_text(2, "Search Compatible Values...")
	_data_drag_popup.set_item_tooltip(2, "Search for a value-producing node that can feed this %s input." % _normalized_pin_type(type_name))
	_data_drag_popup.position = Vector2i(graph_edit.get_screen_position() + release_position)
	_data_drag_popup.popup()


func _on_data_drag_popup_selected(id: int) -> void:
	if not _pending_connection_from_node.is_empty():
		var source = graph_edit.get_node_or_null(NodePath(_pending_connection_from_node))
		if not (source is GraphNode):
			_cancel_pending_connection()
			return
		if id == 0:
			_pin_context_node = source
			_pin_context_port = _pending_connection_from_port
			_pin_context_is_output = true
			_cancel_pending_connection()
			_on_pin_context_selected(0)
		elif id == 1:
			_refresh_add_menu_from_registry(true)
			_open_search_popup(graph_edit.get_screen_position() + _pending_connection_release_position)
		return
	if not _pending_connection_to_node.is_empty():
		var target = graph_edit.get_node_or_null(NodePath(_pending_connection_to_node))
		if not (target is GraphNode):
			_cancel_pending_connection()
			return
		if id == 0:
			_pin_context_node = target
			_pin_context_port = _pending_connection_to_port
			_pin_context_is_output = false
			_cancel_pending_connection()
			_on_pin_context_selected(0)
		elif id == 1:
			_refresh_add_menu_from_registry(true)
			_open_search_popup(graph_edit.get_screen_position() + _pending_connection_release_position)


func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	if not current_node or current_node.get_script() == null:
		return
	_cancel_pending_connection()
	_pending_connection_from_node = str(from_node)
	_pending_connection_from_port = from_port
	_pending_connection_release_position = release_position
	last_mouse_position = (release_position + graph_edit.scroll_offset) / graph_edit.zoom
	var source = graph_edit.get_node_or_null(NodePath(str(from_node)))
	# Unreal-style data-pin workflow: dragging any typed output (including a
	# split Vector/Color component pin) into empty space offers Promote to
	# Variable before the normal compatible-node search.
	if source is GraphNode and not _get_value_output_info(source, from_port).is_empty():
		_show_data_drag_popup(source, from_port, release_position)
		return
	_refresh_add_menu_from_registry(true)
	_open_search_popup(graph_edit.get_screen_position() + release_position)


func _on_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	if not current_node or current_node.get_script() == null:
		return
	var target = graph_edit.get_node_or_null(NodePath(str(to_node)))
	if not (target is GraphNode) or not target.has_meta("value_input_types"):
		return
	var input_types: Dictionary = target.get_meta("value_input_types")
	if not input_types.has(to_port):
		return
	_cancel_pending_connection()
	_pending_connection_to_node = str(to_node)
	_pending_connection_to_port = to_port
	_pending_connection_release_position = release_position
	last_mouse_position = (release_position + graph_edit.scroll_offset) / graph_edit.zoom
	_show_input_data_drag_popup(target, to_port, release_position)


func _cancel_pending_connection() -> void:
	_pending_connection_from_node = ""
	_pending_connection_from_port = -1
	_pending_connection_to_node = ""
	_pending_connection_to_port = -1
	_pending_connection_release_position = Vector2.ZERO


func _search_candidate_allowed(info: Dictionary) -> bool:
	if not _pending_connection_to_node.is_empty():
		# An input pin dragged into empty space needs a node that can produce data.
		return str(info.get("type", "")) in ["value", "controller", "actuator"]
	if _pending_connection_from_node.is_empty():
		return true
	var source = graph_edit.get_node_or_null(NodePath(_pending_connection_from_node))
	if source == null:
		return true
	# A typed data output can come from a pure getter or an executable node.
	if not _get_value_output_info(source, _pending_connection_from_port).is_empty():
		return str(info.get("type", "")) in ["controller", "actuator"]
	# Exec wire released into empty space: context-search executable nodes only.
	if source.has_meta("brick_data"):
		return str(info.get("type", "")) in ["controller", "actuator"]
	return true


func _complete_pending_connection_to_new_node(new_node: GraphNode) -> void:
	if new_node == null:
		_cancel_pending_connection()
		return
	if not _pending_connection_to_node.is_empty():
		var target_name := _pending_connection_to_node
		var to_port := _pending_connection_to_port
		var target = graph_edit.get_node_or_null(NodePath(target_name))
		_cancel_pending_connection()
		if target == null:
			return
		# Connect the first typed output on the newly-created source node.
		for output_port in range(new_node.get_output_port_count()):
			if not _get_value_output_info(new_node, output_port).is_empty():
				_on_connection_request(str(new_node.name), output_port, target_name, to_port)
				return
		return
	if _pending_connection_from_node.is_empty():
		return
	var from_name := _pending_connection_from_node
	var from_port := _pending_connection_from_port
	var source = graph_edit.get_node_or_null(NodePath(from_name))
	_cancel_pending_connection()
	if source == null or not new_node.has_meta("brick_data"):
		return
	var brick_type := str(new_node.get_meta("brick_data").get("brick_type", ""))
	if brick_type not in ["controller", "actuator"]:
		return
	if not _get_value_output_info(source, from_port).is_empty():
		# A data wire released in empty space should connect to the first value
		# input on the newly-created node, not its execution input.
		if not new_node.has_meta("value_input_ports"):
			return
		var port_map: Dictionary = new_node.get_meta("value_input_ports")
		var input_ports := port_map.keys()
		input_ports.sort()
		if input_ports.is_empty():
			return
		_on_connection_request(from_name, from_port, str(new_node.name), int(input_ports[0]))
		return
	_on_connection_request(from_name, from_port, str(new_node.name), 0)


func _disconnect_connection_dictionary(conn: Dictionary, action_name: String = "Disconnect Blueprint Wire") -> void:
	if conn.is_empty():
		return
	var before_snapshot = _take_graph_snapshot()
	var to_graph_node = graph_edit.get_node_or_null(NodePath(str(conn.get("to_node", ""))))
	if to_graph_node and to_graph_node.has_meta("value_input_ports"):
		var prop_name := str(to_graph_node.get_meta("value_input_ports").get(int(conn.get("to_port", -1)), ""))
		if not prop_name.is_empty():
			_clear_value_binding(to_graph_node, prop_name)
	graph_edit.disconnect_node(str(conn.get("from_node", "")), int(conn.get("from_port", 0)), str(conn.get("to_node", "")), int(conn.get("to_port", 0)))
	_save_graph_to_metadata(action_name, false)
	_record_undo(action_name, before_snapshot, _take_graph_snapshot())


func _on_graph_edit_input(event: InputEvent) -> void:
	if not current_node or current_node.get_script() == null:
		return

	# Unreal shortcut: Alt + left-click a wire to break that connection.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.alt_pressed:
		var closest := graph_edit.get_closest_connection_at_point(event.position, 14.0)
		if not closest.is_empty():
			_disconnect_connection_dictionary(closest, "Alt-click Disconnect Wire")
			graph_edit.accept_event()
			return

	# Blueprint-style navigation: right-click empty graph opens search;
	# right-click + drag pans the canvas. This is handled here instead of in
	# a GraphEdit override so native wheel zoom and other GraphEdit input remain intact.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_right_pan_active = true
			_right_pan_dragged = false
			_right_pan_press_position = event.position
			graph_edit.accept_event()
		else:
			if _right_pan_active:
				_right_pan_active = false
				if not _right_pan_dragged:
					_on_graph_quick_search_requested(event.position)
				graph_edit.accept_event()
		return

	if event is InputEventMouseMotion and _right_pan_active:
		# Never keep panning after RMB has physically been released, even if a
		# popup/child Control consumed the release event before GraphEdit saw it.
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0:
			_right_pan_active = false
			_right_pan_dragged = false
			return
		if event.position.distance_to(_right_pan_press_position) > 4.0:
			_right_pan_dragged = true
		graph_edit.scroll_offset -= event.relative / maxf(graph_edit.zoom, 0.001)
		graph_edit.accept_event()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Ctrl+D to duplicate selected nodes
		if event.keycode == KEY_D and event.ctrl_pressed:
			_duplicate_selected_nodes()
			graph_edit.accept_event()
		# Ctrl+C — copy selected bricks, or whole node if nothing selected
		elif event.keycode == KEY_C and event.ctrl_pressed:
			_on_copy_bricks_pressed()
			graph_edit.accept_event()
		# Ctrl+V — paste selection clipboard if available, else whole-node clipboard
		elif event.keycode == KEY_V and event.ctrl_pressed:
			_on_paste_bricks_pressed()
			graph_edit.accept_event()
		# Type-to-search: any printable character (no modifiers except Shift) opens the search popup
		elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			var ch = event.as_text()
			# as_text() returns the printable character(s); skip special key names (len > 1 means it's e.g. "Escape", "F1", etc.)
			if ch.length() == 1 and ch.unicode_at(0) >= 32:
				# Store position under mouse for placing the new brick
				last_mouse_position = (graph_edit.get_local_mouse_position() + graph_edit.scroll_offset) / graph_edit.zoom
				var screen_pos = graph_edit.get_screen_position() + graph_edit.get_local_mouse_position()
				_open_search_popup(screen_pos, ch)
				graph_edit.accept_event()


func _duplicate_selected_nodes() -> void:
	await _clipboard_helper.duplicate_selected_nodes()


func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	var before_snapshot = _take_graph_snapshot()
	var to_graph_node = graph_edit.get_node_or_null(NodePath(to_node))
	if to_graph_node and to_graph_node.has_meta("value_input_ports"):
		var prop_name := str(to_graph_node.get_meta("value_input_ports").get(to_port, ""))
		if not prop_name.is_empty():
			_clear_value_binding(to_graph_node, prop_name)
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_save_graph_to_metadata("Disconnect GDBlueprints", false)
	_record_undo("Disconnect GDBlueprints", before_snapshot, _take_graph_snapshot())


func _on_delete_nodes_request(nodes: Array) -> void:
	_clipboard_helper.on_delete_nodes_request(nodes)


func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
	_property_helper._on_property_changed(value, graph_node, property_name)


func _update_controller_title(graph_node: GraphNode, brick_instance) -> void:
	_property_helper._update_controller_title(graph_node, brick_instance)


func _on_instance_name_changed(new_name: String, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_instance_name_changed(new_name, graph_node, brick_instance)


func _on_debug_enabled_changed(enabled: bool, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_debug_enabled_changed(enabled, graph_node, brick_instance)


func _on_debug_message_changed(new_message: String, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_debug_message_changed(new_message, graph_node, brick_instance)


func _on_copy_bricks_pressed() -> void:
	_clipboard_helper.on_copy_bricks_pressed()


## Capture selected graph nodes and their internal connections
## into a portable dictionary that can be pasted onto any node.
func _capture_selection(selected_nodes: Array) -> Dictionary:
	return _clipboard_helper.capture_selection(selected_nodes)


func _on_paste_bricks_pressed() -> void:
	await _clipboard_helper.on_paste_bricks_pressed()


## Paste the selection clipboard into the current graph.
## Pasted nodes are offset slightly so they don't land on top of existing bricks.
## Internal connections are recreated. The clipboard is not cleared so the user
## can paste the same set multiple times or switch nodes and paste again.
func _paste_selection(clipboard: Dictionary) -> void:
	await _clipboard_helper.paste_selection(clipboard)




func _on_duplicate_bricks_pressed() -> void:
	var selected_nodes: Array = []
	for child in graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)
	if selected_nodes.is_empty():
		push_warning("GDBlueprints: Select one or more bricks to duplicate.")
		return
	var duplicate_data := _capture_selection(selected_nodes)
	await _paste_selection(duplicate_data)


func _on_export_graph_image_pressed() -> void:
	if not current_node:
		push_warning("GDBlueprints: Select a node before exporting the graph.")
		return
	_graph_image_dialog.popup_centered_ratio(0.65)


func _on_graph_image_path_selected(path: String) -> void:
	await _export_graph_image(path)


func _export_graph_image(path: String) -> void:
	if not path.to_lower().ends_with(".png"):
		path += ".png"

	var selected_names: Dictionary = {}
	var export_items: Array[GraphElement] = []
	var bounds := Rect2()
	var has_bounds := false

	for child in graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_names[child.name] = true

	var selection_only := not selected_names.is_empty()
	var included_frame_names: Dictionary = {}
	if selection_only:
		for frame_name in frame_node_mapping.keys():
			var members: Array = frame_node_mapping.get(frame_name, [])
			for member_name in members:
				if selected_names.has(str(member_name)):
					included_frame_names[str(frame_name)] = true
					break

	for child in graph_edit.get_children():
		if not (child is GraphNode or child is GraphFrame):
			continue
		if selection_only:
			if child is GraphNode and not selected_names.has(child.name):
				continue
			if child is GraphFrame and not included_frame_names.has(child.name):
				continue
		export_items.append(child)
		var item_rect := Rect2(child.position_offset, child.size)
		bounds = item_rect if not has_bounds else bounds.merge(item_rect)
		has_bounds = true

	if not has_bounds:
		push_warning("GDBlueprints: There are no bricks to export.")
		return

	# Render cloned graph elements on a standalone canvas. GraphEdit is not used
	# here because it clamps scrolling and applies viewport transforms that can
	# crop or offset an off-screen export.
	var render_scale := 2.0
	var margin := 50.0
	var export_origin := bounds.position - Vector2(margin, margin)
	var export_size := bounds.size + Vector2(margin * 2.0, margin * 2.0)
	var output_width := maxi(1, int(ceil(export_size.x * render_scale)))
	var output_height := maxi(1, int(ceil(export_size.y * render_scale)))

	var export_viewport := SubViewport.new()
	export_viewport.name = "GDBlueprintsGraphExportViewport"
	export_viewport.size = Vector2i(output_width, output_height)
	export_viewport.disable_3d = true
	export_viewport.transparent_bg = false
	export_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(export_viewport)

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	export_viewport.add_child(canvas)

	var background := ColorRect.new()
	background.color = Color.WHITE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.z_index = -100
	canvas.add_child(background)

	# Draw frames first so they sit behind connections and bricks. GraphFrame is
	# designed to live inside GraphEdit, so render a publication-friendly frame
	# directly on the standalone canvas instead of cloning the editor control.
	for item in export_items:
		if item is GraphFrame:
			_add_export_frame(canvas, item as GraphFrame, export_origin, render_scale)

	# Draw connections after frames so cloned bricks appear above them.
	var exported_node_names: Dictionary = {}
	for item in export_items:
		if item is GraphNode:
			exported_node_names[item.name] = true

	for conn in graph_edit.get_connection_list():
		if not exported_node_names.has(conn["from_node"]) or not exported_node_names.has(conn["to_node"]):
			continue
		var from_node := graph_edit.get_node_or_null(NodePath(str(conn["from_node"]))) as GraphNode
		var to_node := graph_edit.get_node_or_null(NodePath(str(conn["to_node"]))) as GraphNode
		if from_node == null or to_node == null:
			continue
		var from_port := int(conn["from_port"])
		var to_port := int(conn["to_port"])
		var start_point := (from_node.position_offset + from_node.get_output_port_position(from_port) - export_origin) * render_scale
		var end_point := (to_node.position_offset + to_node.get_input_port_position(to_port) - export_origin) * render_scale
		var connection_color := from_node.get_output_port_color(from_port)
		_add_export_connection(canvas, start_point, end_point, connection_color, render_scale)

	for item in export_items:
		if not item is GraphNode:
			continue
		var node_copy := item.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as GraphNode
		if node_copy == null:
			continue
		node_copy.position = (item.position_offset - export_origin) * render_scale
		node_copy.scale = Vector2.ONE * render_scale
		node_copy.selected = false
		node_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node_copy.z_index = 10
		canvas.add_child(node_copy)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var exported: Image = export_viewport.get_texture().get_image()
	if exported.get_format() != Image.FORMAT_RGBA8:
		exported.convert(Image.FORMAT_RGBA8)
	var result := exported.save_png(path)
	export_viewport.queue_free()

	if result != OK:
		push_error("GDBlueprints: Failed to export graph image to %s (error %s)." % [path, result])
	else:
		print("GDBlueprints: Exported graph image to ", path)



func _add_export_frame(canvas: Control, frame: GraphFrame, export_origin: Vector2, render_scale: float) -> void:
	var panel := PanelContainer.new()
	panel.position = (frame.position_offset - export_origin) * render_scale
	panel.size = frame.size * render_scale
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = -10

	# GraphFrame displays its tint composited over the GraphEdit background.
	# Recreate that visible result as an opaque export color so a white export
	# background does not make translucent frame colors appear brighter.
	var tint: Color = frame.tint_color if frame.tint_color_enabled else Color(0.3, 0.5, 0.7, 0.5)
	var graph_background := Color(0.06, 0.06, 0.06, 1.0)
	var graph_panel := graph_edit.get_theme_stylebox("panel")
	if graph_panel is StyleBoxFlat:
		graph_background = (graph_panel as StyleBoxFlat).bg_color
	var fill := Color(
		lerpf(graph_background.r, tint.r, tint.a),
		lerpf(graph_background.g, tint.g, tint.a),
		lerpf(graph_background.b, tint.b, tint.a),
		1.0
	)
	var border := Color(tint.r, tint.g, tint.b, 1.0)

	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(2, int(round(2.0 * render_scale))))
	style.corner_radius_top_left = int(round(6.0 * render_scale))
	style.corner_radius_top_right = int(round(6.0 * render_scale))
	style.corner_radius_bottom_left = int(round(6.0 * render_scale))
	style.corner_radius_bottom_right = int(round(6.0 * render_scale))
	style.content_margin_left = 12.0 * render_scale
	style.content_margin_right = 12.0 * render_scale
	style.content_margin_top = 8.0 * render_scale
	style.content_margin_bottom = 8.0 * render_scale
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 8)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(text_box)

	var title_label := Label.new()
	title_label.text = str(frame_titles.get(frame.name, frame.title))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var editor_title_size := frame.get_theme_font_size("title_font_size")
	if editor_title_size <= 0:
		editor_title_size = 18
	var editor_title_color := frame.get_theme_color("title_color")
	if editor_title_color.a <= 0.0:
		editor_title_color = Color.WHITE
	title_label.add_theme_font_size_override("font_size", maxi(16, int(round(float(editor_title_size) * render_scale))))
	title_label.add_theme_color_override("font_color", editor_title_color)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var comment: String = str(frame_comments.get(frame.name, "")).strip_edges()
	if not comment.is_empty():
		var comment_label := Label.new()
		comment_label.text = comment
		comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comment_label.add_theme_font_size_override("font_size", maxi(11, int(round(12.0 * render_scale))))
		comment_label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18, 1.0))
		comment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(comment_label)

func _add_export_connection(canvas: Control, start_point: Vector2, end_point: Vector2, color: Color, render_scale: float) -> void:
	var line := Line2D.new()
	line.width = 3.0 * render_scale
	line.default_color = color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 0
	canvas.add_child(line)

	var horizontal_distance := absf(end_point.x - start_point.x)
	var handle_length := maxf(40.0 * render_scale, horizontal_distance * 0.5)
	var control_1 := start_point + Vector2(handle_length, 0.0)
	var control_2 := end_point - Vector2(handle_length, 0.0)
	var segments := 32
	for index in range(segments + 1):
		var amount := float(index) / float(segments)
		line.add_point(start_point.bezier_interpolate(control_1, control_2, end_point, amount))


func _add_view_code_button(graph_node: GraphNode) -> void:
	if graph_node == null or graph_node.get_node_or_null("ViewCodeButton"):
		return
	if graph_node.has_meta("brick_data"):
		var member_id := str(graph_node.get_meta("brick_data").get("brick_class", ""))
		var brick = graph_node.get_meta("brick_data").brick_instance
		if str(graph_node.get_meta("brick_data").get("brick_type", "")) in ["controller", "actuator"]:
			var breakpoint_button := Button.new()
			breakpoint_button.name = "BreakpointButton"
			breakpoint_button.toggle_mode = true
			breakpoint_button.button_pressed = brick.debug_enabled
			breakpoint_button.text = "● Breakpoint" if brick.debug_enabled else "○ Breakpoint"
			breakpoint_button.tooltip_text = "Pause before this execution node. Synchronous Function nodes are trace-only so their public methods remain normal non-awaiting GDScript calls."
			breakpoint_button.toggled.connect(func(enabled: bool):
				brick.debug_enabled = enabled
				breakpoint_button.text = "● Breakpoint" if enabled else "○ Breakpoint"
				breakpoint_button.modulate = Color("ff625f") if enabled else Color.WHITE
				_save_graph_to_metadata("Toggle Graph Breakpoint")
			)
			breakpoint_button.modulate = Color("ff625f") if brick.debug_enabled else Color.WHITE
			graph_node.get_titlebar_hbox().add_child(breakpoint_button)
		if member_id in ["CallGraphFunction", "CallCustomEventActuator", "ConnectSignalActuator", "EmitTypedSignal"]:
			var browse := Button.new()
			browse.name = "BrowseMembersButton"
			browse.text = "Browse Signals" if member_id in ["ConnectSignalActuator", "EmitTypedSignal"] else "Browse Methods"
			browse.pressed.connect(func(): preload("res://addons/GDBlueprints/ui/member_editor.gd").browse(self, graph_node))
			graph_node.add_child(browse)
		if member_id == "ConnectSignalActuator":
			var event_button := Button.new()
			event_button.name = "CreateSignalEventButton"
			event_button.text = "Create / Update Signal Event"
			event_button.pressed.connect(func():
				var error := preload("res://addons/GDBlueprints/ui/member_editor.gd").create_signal_event(self, graph_node)
				if not error.is_empty(): push_warning(error)
			)
			graph_node.add_child(event_button)
	var view_code_btn := Button.new()
	view_code_btn.name = "ViewCodeButton"
	view_code_btn.text = "View Code"
	view_code_btn.tooltip_text = "Open the generated GDScript near the code produced by this node"
	view_code_btn.pressed.connect(_on_view_node_code.bind(graph_node))
	graph_node.add_child(view_code_btn)
	if graph_node.has_meta("brick_data") and str(graph_node.get_meta("brick_data").get("brick_class", "")) in ["CustomEventSensor", "CallCustomEventActuator", "FunctionEntry", "CallGraphFunction", "EmitTypedSignal"]:
		var parameters_button := Button.new()
		parameters_button.text = "Apply Parameters"
		if str(graph_node.get_meta("brick_data").get("brick_class", "")) in ["FunctionEntry", "CallGraphFunction"]:
			parameters_button.text = "Apply Signature"
		parameters_button.name = "ApplyParametersButton"
		parameters_button.tooltip_text = "Apply parameters and any return/local declarations. Existing wires follow names; incompatible connected changes are rejected."
		parameters_button.pressed.connect(func():
			var error := preload("res://addons/GDBlueprints/ui/event_signature_editor.gd").apply(self, graph_node)
			if not error.is_empty(): push_warning(error)
		)
		graph_node.add_child(parameters_button)
		if str(graph_node.get_meta("brick_data").get("brick_class", "")) in ["CallGraphFunction", "CallCustomEventActuator"]:
			var copy_signature := Button.new()
			copy_signature.text = "Use Local Definition"
			copy_signature.tooltip_text = "Copy the matching function/event signature from this node's graph and apply it safely. Target must be Self."
			copy_signature.pressed.connect(func():
				var error := preload("res://addons/GDBlueprints/ui/event_signature_editor.gd").use_local_definition(self, graph_node)
				if not error.is_empty(): push_warning(error)
			)
			graph_node.add_child(copy_signature)


func _connection_is_exec(conn: Dictionary) -> bool:
	var from_node = graph_edit.get_node_or_null(NodePath(str(conn.get("from_node", ""))))
	var to_node = graph_edit.get_node_or_null(NodePath(str(conn.get("to_node", ""))))
	if not (from_node is GraphNode and to_node is GraphNode):
		return false
	if not _get_value_output_info(from_node, int(conn.get("from_port", 0))).is_empty():
		return false
	if to_node.has_meta("value_input_types"):
		var input_types: Dictionary = to_node.get_meta("value_input_types")
		if input_types.has(int(conn.get("to_port", 0))):
			return false
	return true


func _gdb_debug_trace(payload: Dictionary) -> void:
	if not is_instance_valid(current_node) or not is_instance_valid(graph_edit): return
	var scene := current_node.get_tree().edited_scene_root if current_node.get_tree() else null
	if scene == null: return
	if scene.scene_file_path != str(payload.get("scene", "")): return
	if str(scene.get_path_to(current_node)) != str(payload.get("owner_path", "")): return
	var active_id := str(payload.get("node_id", ""))
	for child in graph_edit.get_children():
		if not child is GraphNode or child is GraphFrame: continue
		if not child.has_meta("gdb_debug_original_modulate"): child.set_meta("gdb_debug_original_modulate", child.modulate)
		child.modulate = child.get_meta("gdb_debug_original_modulate")
		if str(child.name) == active_id:
			child.modulate = Color("ffd45e") if bool(payload.get("paused", false)) else Color("8ff0a4")
			child.tooltip_text = _gdb_debug_tooltip(payload)
			if bool(payload.get("paused", false)):
				graph_edit.set_selected(child)
				graph_edit.scroll_offset = child.position_offset - graph_edit.size * 0.4


func _gdb_debug_tooltip(payload: Dictionary) -> String:
	var lines: Array[String] = ["Runtime execution: step %s, depth %s, input %s" % [payload.get("step", 0), payload.get("depth", 0), payload.get("entry", "")]]
	for key in ["function_arguments", "function_locals", "event_arguments", "values", "loops", "watched"]:
		var value = payload.get(key)
		if value is Dictionary and value.is_empty(): continue
		if value is Array and value.is_empty(): continue
		lines.append("%s: %s" % [key.replace("_", " ").capitalize(), str(value)])
	return "\n".join(lines)


func _find_chain_anchor_for_node(graph_node: GraphNode) -> Dictionary:
	var connections = graph_edit.get_connection_list()
	var queue: Array = [{"node":graph_node, "downstream_port":-1}]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		var node = item.get("node")
		if not (node is GraphNode) or visited.has(str(node.name)):
			continue
		visited[str(node.name)] = true
		if node.has_meta("brick_data"):
			var data: Dictionary = node.get_meta("brick_data")
			var brick_type := str(data.get("brick_type", ""))
			var brick_class := str(data.get("brick_class", ""))
			if brick_type == "controller":
				var name := _graph_helper.get_chain_name_for_controller(node)
				var port := int(item.get("downstream_port", -1))
				if brick_class == "BranchController" and port >= 0:
					name += "_true" if port == 0 else "_false"
				elif brick_class == "CastToScriptController" and port >= 0:
					name += "_success" if port == 0 else "_failure"
				return {"func":"_blueprint_%s" % name}
			if brick_type == "sensor":
				return {"func":"_blueprint_direct_%s" % str(node.name).replace("brick_node_", "event_")}
		for conn in connections:
			if not _connection_is_exec(conn):
				continue
			if str(conn.get("to_node", "")) == str(node.name):
				var upstream = graph_edit.get_node_or_null(NodePath(str(conn.get("from_node", ""))))
				if upstream is GraphNode:
					queue.append({"node":upstream, "downstream_port":int(conn.get("from_port", -1))})
	# Pure/data-only nodes: follow their consumers, then find that consumer's exec chain.
	for conn in connections:
		if str(conn.get("from_node", "")) != str(graph_node.name):
			continue
		if _connection_is_exec(conn):
			continue
		var consumer = graph_edit.get_node_or_null(NodePath(str(conn.get("to_node", ""))))
		if consumer is GraphNode:
			var anchor := _find_chain_anchor_for_node(consumer)
			if not anchor.is_empty():
				return anchor
	return {}


func _open_script_at_function(func_name: String) -> bool:
	if not current_node or not editor_interface:
		return false
	var script = current_node.get_script()
	if not script or script.resource_path.is_empty():
		return false
	var file = FileAccess.open(script.resource_path, FileAccess.READ)
	if not file:
		return false
	var line_number := 1
	var found := false
	while not file.eof_reached():
		var line := file.get_line()
		if (not func_name.is_empty() and line.strip_edges().begins_with("func " + func_name)) or (func_name.is_empty() and "GDBlueprints GENERATED START" in line):
			found = true
			break
		line_number += 1
	file.close()
	if not found:
		return false
	editor_interface.set_main_screen_editor("Script")
	editor_interface.edit_script(script, line_number)
	return true


func _on_view_node_code(graph_node: GraphNode) -> void:
	if not current_node or not current_node.get_script():
		push_warning("GDBlueprints: No script on this node. Compile the graph first.")
		return
	var anchor := _find_chain_anchor_for_node(graph_node)
	var func_name := str(anchor.get("func", ""))
	if not func_name.is_empty() and _open_script_at_function(func_name):
		return
	# Disconnected value nodes and incomplete chains still get a useful View Code action.
	if _open_script_at_function(""):
		return
	editor_interface.edit_script(current_node.get_script(), 1)


func _on_view_chain_code(controller_node: GraphNode) -> void:
	# Open the generated script and jump to this chain's function
	if not current_node or not editor_interface:
		return

	var script = current_node.get_script()
	if not script:
		push_warning("GDBlueprints: No script on this node. Click 'Apply Code' first.")
		return

	# Get chain name from controller node
	var chain_name = _graph_helper.get_chain_name_for_controller(controller_node)
	var func_name = "_blueprint_%s" % chain_name

	# Read the script to find the line number
	var script_path = script.resource_path
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		push_warning("GDBlueprints: Could not read script file.")
		return

	var line_number = 1
	var found = false
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges().begins_with("func " + func_name):
			found = true
			break
		line_number += 1
	file.close()

	if not found:
		push_warning("GDBlueprints: Chain function '%s' not found in script. Try 'Apply Code' first." % func_name)
		return

	# Open script editor at the line
	editor_interface.set_main_screen_editor("Script")
	editor_interface.edit_script(script, line_number)


func _on_rebuild_metadata_pressed() -> void:
	if not current_node:
		push_error("GDBlueprints: No node selected!")
		return

	if not manager:
		push_error("GDBlueprints: Manager not initialized!")
		return

	if not current_node.has_meta("blueprints_for_godot_graph"):
		push_warning("GDBlueprints: No saved graph metadata found on this node.")
		return

	await _load_graph_from_metadata()
	await get_tree().process_frame
	_graph_helper.sync_graph_ui_to_bricks()

	var chains = _graph_helper.extract_chains_from_graph(true)
	if chains.is_empty():
		push_warning("GDBlueprints: Could not rebuild metadata because no connected Event/flow chains were found in the saved graph.")
		return

	manager.save_chains(current_node, chains)

	var complete_count := 0
	for chain in chains:
		var controllers = chain.get("controllers", [])
		var is_script_controller = controllers.size() > 0 and controllers[0].get("type", "") == "ScriptController"
		var has_sensors = chain.get("sensors", []).size() > 0
		var has_actuators = chain.get("actuators", []).size() > 0
		if has_sensors and (has_actuators or is_script_controller):
			complete_count += 1

	if complete_count < chains.size():
		push_warning("GDBlueprints: Rebuilt %d chain(s) from graph data, but %d are incomplete and will not generate code until their connections are restored." % [chains.size(), chains.size() - complete_count])
	else:
		print("GDBlueprints: Rebuilt blueprints_for_godot metadata for %s from saved graph data." % current_node.name)


func _on_rebuild_from_script_pressed() -> void:
	if not current_node:
		push_error("GDBlueprints: No node selected!")
		return
	if not manager:
		push_error("GDBlueprints: Manager not initialized!")
		return
	await _script_rebuild_helper.rebuild_from_script()


func _on_apply_code_pressed() -> void:

	if not current_node:
		push_error("GDBlueprints: No node selected!")
		return

	if not manager:
		push_error("GDBlueprints: Manager not initialized!")
		return

	if not editor_interface:
		push_error("GDBlueprints: Editor interface not available!")
		return

	_apply_validation_active = true
	var saved_graph = current_node.get_meta("blueprints_for_godot_graph", {})
	if saved_graph is Dictionary and int(saved_graph.get("execution_version",1)) > preload("res://addons/GDBlueprints/core/execution_graph_compiler.gd").FORMAT_VERSION:
		push_error("GDBlueprints: Upgrade the plugin before compiling this newer execution format.")
		return
	_refresh_apply_validation_warnings()

	_graph_helper.sync_graph_ui_to_bricks()
	_save_graph_to_metadata()

	# Extract chains
	var chains = _graph_helper.extract_chains_from_graph()
	if chains.is_empty():
		push_warning("GDBlueprints: Nothing to compile. Connect an Event directly to an Action, or route it through an explicit flow node such as Branch.")
		if _apply_code_button:
			_apply_code_button.text = "Nothing connected"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_apply_code_button):
					_apply_code_button.text = "Compile Blueprint → GDScript"
			)
		return

	# Preserve the last compiled representation if validation rejects this edit.
	var had_compiled_chains := current_node.has_meta("blueprints_for_godot")
	var previous_chains: Array = manager.get_chains(current_node).duplicate(true)

	if not current_node.get_script():
		push_error("GDBlueprints: Selected node has no script. Click Add Script to Node first.")
		return

	# Get script path before regeneration
	var script_path = current_node.get_script().resource_path

	# Get variables code
	var variables_code = get_variables_code()

	# Save and regenerate - this writes the file to disk
	manager.save_chains(current_node, chains)
	if not manager.regenerate_script(current_node, variables_code):
		if had_compiled_chains: current_node.set_meta("blueprints_for_godot", previous_chains)
		else: current_node.remove_meta("blueprints_for_godot")
		_set_compile_button_state("dirty")
		if _apply_code_button:
			_apply_code_button.tooltip_text = manager.last_compile_error
		return

	# Phase 1: create any required scene nodes (CanvasLayer, ColorRect, etc.)
	# @export var assignment happens in Phase 2 AFTER set_script() below,
	# because set_script() resets all properties to their defaults.
	_apply_scene_setup_create(current_node, chains)

	# Get script path if we didn't have one
	if script_path.is_empty() and current_node.get_script():
		script_path = current_node.get_script().resource_path

	if script_path.is_empty():
		push_error("GDBlueprints: No script path available!")
		return

	# Do not save the scene here. Apply Code should only regenerate/reload the
	# script and create required helper nodes in the live editor scene. Saving the
	# whole scene on every click is expensive in larger projects and makes Apply
	# Code feel slow. Inspector refresh uses EditorInterface after the reload; it
	# must never minimize or hide the Godot editor window.

	# Force filesystem to update
	var filesystem = editor_interface.get_resource_filesystem()
	filesystem.update_file(script_path)

	# Snapshot current_node before awaiting — the user may click away during the
	# yield, setting current_node to null or a different node.
	var _apply_node = current_node

	# Wait a frame
	await get_tree().process_frame

	# Guard: node must still be valid after the yield
	if not is_instance_valid(_apply_node):
		push_error("GDBlueprints: Node was freed during Apply Code — try again.")
		return

	# Reload the script with cache bypass
	var reloaded_script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	if not reloaded_script:
		push_error("GDBlueprints: Failed to reload script from disk!")
		return

	# Apply the reloaded script to the node
	_apply_node.set_script(reloaded_script)
	_has_unapplied_changes = false
	_dirty_indicator_token += 1

	# Phase 2: assign @export vars now that the new script is live.
	# This MUST come after set_script() or the assignments get wiped.
	await get_tree().process_frame
	if is_instance_valid(_apply_node):
		_apply_scene_setup_assign(_apply_node, chains)

	# Refresh the Inspector using Godot's editor API instead of minimizing the
	# entire editor window. The old OS-window refresh hack caused visible flashing,
	# focus loss, and occasional long minimizes on some platforms.
	print("GDBlueprints: Compiled %d execution chain(s) to %s" % [chains.size(), script_path])
	_set_compile_button_state("success")
	if is_instance_valid(_apply_node):
		# Ask Inspector consumers to rebuild after exported properties changed.
		_apply_node.notify_property_list_changed()
		if editor_interface:
			editor_interface.inspect_object(_apply_node)
	# Keep the user's current workspace and graph visible after compiling.



## ============================================================================
## VARIABLES PANEL FUNCTIONS
## ============================================================================

func _on_add_variable_pressed() -> void:
	var var_data = {
		"name": "new_variable",
		"type": "int",
		"value": "0",
		"exported": false,
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100",
		"collapsed": false
	}
	variables_data.append(var_data)
	_refresh_variables_ui()
	_save_variables_to_metadata()


func _on_add_global_variable_pressed() -> void:
	var var_data = {
		"id": _generate_global_var_id(),
		"name": "new_global",
		"type": "int",
		"value": "0",
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100",
		"collapsed": false
	}
	global_vars_data.append(var_data)
	_refresh_global_vars_ui()
	_save_global_vars_to_metadata()


func _refresh_variables_ui() -> void:
	for child in variables_list.get_children():
		child.queue_free()
	for i in range(variables_data.size()):
		_create_variable_ui(i, variables_data[i])


func _refresh_global_vars_ui() -> void:
	if not global_vars_list:
		return
	_ensure_global_var_ids()
	for child in global_vars_list.get_children():
		child.queue_free()
	for i in range(global_vars_data.size()):
		_create_global_variable_ui(i, global_vars_data[i])


func _is_debug_watch_enabled(value: Variant) -> bool:
	if value is bool:
		return value
	if value is String:
		return value.strip_edges().to_lower() == "true"
	if value is int:
		return value == 1
	return false


func _style_debug_watch_button(button: Button, active: bool) -> void:
	button.text = "🐞"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(34, 28)
	button.tooltip_text = "Show in Runtime Debug Overlay"
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	if active:
		normal.bg_color = Color(1.0, 0.72, 0.12, 1.0)
		normal.border_color = Color(1.0, 0.9, 0.35, 1.0)
		button.add_theme_color_override("font_color", Color(0.08, 0.06, 0.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.0, 1.0))
	else:
		normal.bg_color = Color(0.18, 0.18, 0.18, 1.0)
		normal.border_color = Color(0.36, 0.36, 0.36, 1.0)
		button.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.62, 0.62, 0.62, 1.0))
	# Keep the persistent on/off appearance unchanged under the mouse.
	# Toggle buttons use hover_pressed while both active and hovered, so all
	# interactive states must explicitly share the same style.
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("hover_pressed", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var icon_color := Color(0.08, 0.06, 0.0, 1.0) if active else Color(0.62, 0.62, 0.62, 1.0)
	button.add_theme_color_override("font_hover_color", icon_color)
	button.add_theme_color_override("font_hover_pressed_color", icon_color)
	button.add_theme_color_override("font_focus_color", icon_color)


func _create_variable_ui(index: int, var_data: Dictionary) -> void:
	var panel = PanelContainer.new()
	variables_list.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var collapse_btn = Button.new()
	collapse_btn.text = "▼"
	collapse_btn.custom_minimum_size = Vector2(24, 0)
	collapse_btn.name = "CollapseBtn"
	header.add_child(collapse_btn)

	var name_display = VariableDragLabel.new()
	name_display.text = "⠿  %s: %s" % [var_data["name"], var_data["type"]]
	name_display.drag_payload = {"scope":"local", "index":index}
	name_display.tooltip_text = "Drag this variable into the graph to choose Get or Set, like Unreal Blueprints"
	name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_display.name = "NameDisplay"
	header.add_child(name_display)

	var debug_btn = Button.new()
	debug_btn.button_pressed = _is_debug_watch_enabled(var_data.get("debug_watch", false))
	_style_debug_watch_button(debug_btn, debug_btn.button_pressed)
	debug_btn.toggled.connect(_on_local_variable_debug_watch_toggled.bind(index, debug_btn))
	header.add_child(debug_btn)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.pressed.connect(_on_delete_variable_pressed.bind(index))
	header.add_child(delete_btn)

	var details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.name = "Details"
	vbox.add_child(details)

	# Name
	var row1 = HBoxContainer.new()
	details.add_child(row1)
	var name_label = Label.new()
	name_label.text = "Name:"
	row1.add_child(name_label)
	var name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.text = var_data["name"]
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_variable_name_changed.bind(index, name_display))
	row1.add_child(name_edit)

	# Type
	var row2 = HBoxContainer.new()
	details.add_child(row2)
	var type_label = Label.new()
	type_label.text = "Type:"
	row2.add_child(type_label)
	var type_option = OptionButton.new()
	type_option.name = "TypeOption"
	var type_names = VariableUtils.get_supported_types()
	var current_type := str(var_data.get("type", "int"))
	if VariableUtils.is_supported_type(current_type) and current_type not in type_names:
		type_names.append(current_type)
	for type_i in range(type_names.size()):
		type_option.add_item(type_names[type_i], type_i)
	var type_index = type_names.find(str(var_data.get("type", "int")))
	type_option.selected = type_index
	type_option.item_selected.connect(_on_variable_type_changed.bind(index, name_display))
	row2.add_child(type_option)
	_add_type_expression(details, index, false)

	# Value
	_create_local_variable_value_editor(details, index, var_data)

	# Export
	var row4 = HBoxContainer.new()
	details.add_child(row4)
	var export_check = CheckBox.new()
	export_check.text = "Expose in Inspector"
	export_check.tooltip_text = "Godot equivalent of an instance-editable variable: exposes this script variable in the Inspector for each node instance."
	export_check.button_pressed = var_data.get("exported", false)
	var can_export_type := VariableUtils.can_export(str(var_data.get("type", "int")))
	export_check.disabled = not can_export_type
	if not can_export_type:
		export_check.button_pressed = false
		export_check.tooltip_text = "This type is assigned at runtime and cannot use Godot's @export annotation."
	export_check.toggled.connect(_on_variable_exported_changed.bind(index))
	row4.add_child(export_check)

	var scope_row = HBoxContainer.new()
	details.add_child(scope_row)
	var make_global_btn = Button.new()
	make_global_btn.text = "Make Global"
	make_global_btn.tooltip_text = "Move this variable to project-wide GlobalVars scope. Use this only when multiple unrelated scenes/scripts truly need the same value."
	make_global_btn.pressed.connect(_on_make_variable_global.bind(index))
	scope_row.add_child(make_global_btn)

	# Min / Max (numeric types only)
	var is_numeric = var_data["type"] in ["int", "float"]

	var row_min = HBoxContainer.new()
	row_min.name = "RowMin"
	row_min.visible = is_numeric
	details.add_child(row_min)
	var min_check = CheckBox.new()
	min_check.text = "Min"
	min_check.button_pressed = var_data.get("use_min", false)
	row_min.add_child(min_check)
	var min_edit = LineEdit.new()
	min_edit.text = var_data.get("min_val", "0")
	min_edit.custom_minimum_size = Vector2(60, 0)
	min_edit.editable = var_data.get("use_min", false)
	min_edit.modulate.a = 1.0 if var_data.get("use_min", false) else 0.4
	min_edit.text_changed.connect(_on_variable_min_val_changed.bind(index))
	row_min.add_child(min_edit)
	min_check.toggled.connect(_on_variable_min_toggled.bind(index, min_edit))

	var row_max = HBoxContainer.new()
	row_max.name = "RowMax"
	row_max.visible = is_numeric
	details.add_child(row_max)
	var max_check = CheckBox.new()
	max_check.text = "Max"
	max_check.button_pressed = var_data.get("use_max", false)
	row_max.add_child(max_check)
	var max_edit = LineEdit.new()
	max_edit.text = var_data.get("max_val", "100")
	max_edit.custom_minimum_size = Vector2(60, 0)
	max_edit.editable = var_data.get("use_max", false)
	max_edit.modulate.a = 1.0 if var_data.get("use_max", false) else 0.4
	max_edit.text_changed.connect(_on_variable_max_val_changed.bind(index))
	row_max.add_child(max_edit)
	max_check.toggled.connect(_on_variable_max_toggled.bind(index, max_edit))

	_apply_variable_collapsed_state(collapse_btn, details, var_data.get("collapsed", false))
	collapse_btn.pressed.connect(_on_local_variable_collapse_toggled.bind(index, collapse_btn, details))


func _on_variable_name_changed(new_name: String, index: int, name_display: Label) -> void:
	# Handle variable name change
	if index < variables_data.size():
		variables_data[index]["name"] = new_name
		# Update the display label
		name_display.text = "⠿  %s: %s" % [new_name, variables_data[index]["type"]]
		_save_variables_to_metadata()


func _on_variable_type_changed(type_index: int, index: int, name_display: Label) -> void:
	# Handle variable type change
	if index < variables_data.size():
		var type_names = VariableUtils.get_supported_types()
		if type_index < 0 or type_index >= type_names.size():
			return
		var new_type = type_names[type_index]
		variables_data[index]["type"] = new_type
		variables_data[index]["value"] = VariableUtils.coerce_variable_value_for_type(variables_data[index].get("value", VariableUtils.get_default_value_for_variable_type(new_type)), new_type)
		if not VariableUtils.can_export(new_type):
			variables_data[index]["exported"] = false
		# Update the display label
		name_display.text = "⠿  %s: %s" % [variables_data[index]["name"], new_type]
		_save_variables_to_metadata()
		# Refresh so min/max rows show/hide correctly for the new type
		_refresh_variables_ui()


func _vector_components_from_value(value, dimensions: int) -> Array[String]:
	var result: Array[String] = []
	var text := str(value).strip_edges()
	if text == "Vector2.ZERO" or text == "Vector3.ZERO" or text.is_empty():
		text = "0, 0" if dimensions == 2 else "0, 0, 0"
	elif text.begins_with("Vector2(") or text.begins_with("Vector3("):
		text = text.substr(text.find("(") + 1)
		if text.ends_with(")"):
			text = text.left(-1)
	var parts := text.split(",", false)
	for i in range(dimensions):
		var component := "0"
		if i < parts.size():
			component = str(parts[i]).strip_edges()
			if not component.is_valid_float():
				component = "0"
		result.append(component)
	return result


func _create_axis_value_editor(parent: VBoxContainer, index: int, var_data: Dictionary, is_global: bool) -> void:
	var var_type := str(var_data.get("type", "int"))
	if VariableUtils.is_reference_type(var_type) or var_type in ["Callable", "Signal", "Variant"]:
		var help := Label.new()
		help.text = "Assign at runtime with Set Variable."
		if not is_global and VariableUtils.can_export(var_type):
			help.text += " Or expose it and assign it in the Inspector."
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(help)
		return
	if var_type == "Array":
		_create_array_variable_value_editor(parent, index, var_data, is_global)
		return
	if var_type != "Vector2" and var_type != "Vector3":
		var row = HBoxContainer.new()
		parent.add_child(row)
		var label = Label.new()
		label.text = "Value:"
		row.add_child(label)
		var edit = LineEdit.new()
		edit.text = _value_to_line_edit_text(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_global:
			edit.text_changed.connect(_on_global_variable_value_changed.bind(index))
		else:
			edit.text_changed.connect(_on_variable_value_changed.bind(index))
		row.add_child(edit)
		return

	var dimensions := 2 if var_type == "Vector2" else 3
	var components := _vector_components_from_value(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), dimensions)
	var value_label = Label.new()
	value_label.text = "Value:"
	parent.add_child(value_label)
	var edits: Array[LineEdit] = []
	for axis_index in range(dimensions):
		var axis_row = HBoxContainer.new()
		parent.add_child(axis_row)
		var axis_label = Label.new()
		axis_label.text = ["X:", "Y:", "Z:"][axis_index]
		axis_label.custom_minimum_size = Vector2(24, 0)
		axis_row.add_child(axis_label)
		var axis_edit = LineEdit.new()
		axis_edit.text = components[axis_index]
		axis_edit.placeholder_text = "0"
		axis_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edits.append(axis_edit)
		axis_row.add_child(axis_edit)
	for axis_edit in edits:
		axis_edit.text_changed.connect(_on_vector_axis_value_changed.bind(index, var_type, edits, is_global))


func _create_array_variable_value_editor(parent: VBoxContainer, index: int, var_data: Dictionary, is_global: bool) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var label := Label.new()
	label.text = "Items:"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var add_btn := Button.new()
	add_btn.text = "+ Add Item"
	add_btn.pressed.connect(_on_array_variable_item_added.bind(index, is_global))
	header.add_child(add_btn)

	var items = var_data.get("value", [])
	if not (items is Array):
		items = []
	for item_index in range(items.size()):
		var item = items[item_index]
		if not (item is Dictionary):
			item = {"type":"String", "value":str(item)}
		var row := HBoxContainer.new()
		parent.add_child(row)
		var idx := Label.new()
		idx.text = "[%d]" % item_index
		idx.custom_minimum_size = Vector2(36, 0)
		row.add_child(idx)
		var type_option := OptionButton.new()
		var item_types = VariableUtils.get_supported_types().filter(func(t): return not VariableUtils.is_reference_type(t) and t not in ["Callable", "Signal"])
		for type_name in item_types:
			type_option.add_item(type_name)
		var selected := item_types.find(str(item.get("type", "String")))
		type_option.selected = selected if selected >= 0 else item_types.find("String")
		type_option.item_selected.connect(_on_array_variable_item_type_changed.bind(index, item_index, item_types, is_global))
		row.add_child(type_option)
		var edit := LineEdit.new()
		edit.text = str(item.get("value", ""))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(_on_array_variable_item_value_changed.bind(index, item_index, is_global))
		row.add_child(edit)
		var remove_btn := Button.new()
		remove_btn.text = "×"
		remove_btn.tooltip_text = "Remove item at index %d" % item_index
		remove_btn.pressed.connect(_on_array_variable_item_removed.bind(index, item_index, is_global))
		row.add_child(remove_btn)


func _on_array_variable_item_added(index: int, is_global: bool) -> void:
	var data = global_vars_data if is_global else variables_data
	if index < 0 or index >= data.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array):
		items = []
	items.append({"type":"String", "value":""})
	data[index]["value"] = items
	_save_array_variable_change(is_global)
	if is_global:
		_refresh_global_vars_ui()
	else:
		_refresh_variables_ui()


func _on_array_variable_item_removed(index: int, item_index: int, is_global: bool) -> void:
	var data = global_vars_data if is_global else variables_data
	if index < 0 or index >= data.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array) or item_index < 0 or item_index >= items.size():
		return
	items.remove_at(item_index)
	data[index]["value"] = items
	_save_array_variable_change(is_global)
	if is_global:
		_refresh_global_vars_ui()
	else:
		_refresh_variables_ui()


func _on_array_variable_item_type_changed(type_index: int, index: int, item_index: int, item_types: Array, is_global: bool) -> void:
	var data = global_vars_data if is_global else variables_data
	if index < 0 or index >= data.size() or type_index < 0 or type_index >= item_types.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array) or item_index < 0 or item_index >= items.size():
		return
	var old = items[item_index] if items[item_index] is Dictionary else {"type":"String", "value":str(items[item_index])}
	var new_type := str(item_types[type_index])
	items[item_index] = {"type":new_type, "value":VariableUtils.coerce_variable_value_for_type(old.get("value", ""), new_type)}
	data[index]["value"] = items
	_save_array_variable_change(is_global)
	if is_global:
		_refresh_global_vars_ui()
	else:
		_refresh_variables_ui()


func _on_array_variable_item_value_changed(new_value: String, index: int, item_index: int, is_global: bool) -> void:
	var data = global_vars_data if is_global else variables_data
	if index < 0 or index >= data.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array) or item_index < 0 or item_index >= items.size():
		return
	if not (items[item_index] is Dictionary):
		items[item_index] = {"type":"String", "value":""}
	items[item_index]["value"] = new_value
	data[index]["value"] = items
	_save_array_variable_change(is_global)


func _save_array_variable_change(is_global: bool) -> void:
	if is_global:
		_save_global_vars_to_metadata()
	else:
		_save_variables_to_metadata()


func _create_local_variable_value_editor(parent: VBoxContainer, index: int, var_data: Dictionary) -> void:
	_create_axis_value_editor(parent, index, var_data, false)


func _create_global_variable_value_editor(parent: VBoxContainer, index: int, var_data: Dictionary) -> void:
	_create_axis_value_editor(parent, index, var_data, true)


func _on_vector_axis_value_changed(_new_text: String, index: int, var_type: String, edits: Array[LineEdit], is_global: bool) -> void:
	var data = global_vars_data if is_global else variables_data
	if index < 0 or index >= data.size():
		return
	var values: Array[String] = []
	for edit in edits:
		var component := edit.text.strip_edges()
		if component.is_empty() or not component.is_valid_float():
			component = "0"
		values.append(component)
	data[index]["value"] = "%s(%s)" % [var_type, ", ".join(values)]
	if is_global:
		_save_global_vars_to_metadata()
	else:
		_save_variables_to_metadata()


func _on_variable_value_changed(new_value: String, index: int) -> void:
	# Handle variable value change
	if index < variables_data.size():
		variables_data[index]["value"] = new_value
		_save_variables_to_metadata()


func _on_variable_exported_changed(exported: bool, index: int) -> void:
	# Handle export checkbox change
	if index < variables_data.size():
		variables_data[index]["exported"] = exported
		_save_variables_to_metadata()


func _on_make_variable_global(index: int) -> void:
	if index < 0 or index >= variables_data.size():
		return
	var source: Dictionary = variables_data[index].duplicate(true)
	var global_data := {
		"id": _generate_global_var_id(),
		"name": str(source.get("name", "new_global")),
		"type": str(source.get("type", "int")),
		"value": source.get("value", "0"),
		"use_min": bool(source.get("use_min", false)),
		"min_val": str(source.get("min_val", "0")),
		"use_max": bool(source.get("use_max", false)),
		"max_val": str(source.get("max_val", "100")),
		"collapsed": bool(source.get("collapsed", false)),
		"debug_watch": source.get("debug_watch", false)
	}
	variables_data.remove_at(index)
	global_vars_data.append(global_data)
	_save_variables_to_metadata()
	_save_global_vars_to_metadata()
	_refresh_variables_ui()
	_refresh_global_vars_ui()
	_select_side_tab(1)


func _on_make_global_script_variable(index: int) -> void:
	if index < 0 or index >= global_vars_data.size():
		return
	var source: Dictionary = global_vars_data[index].duplicate(true)
	var local_data := {
		"name": str(source.get("name", "new_variable")),
		"type": str(source.get("type", "int")),
		"value": source.get("value", "0"),
		"exported": false,
		"use_min": bool(source.get("use_min", false)),
		"min_val": str(source.get("min_val", "0")),
		"use_max": bool(source.get("use_max", false)),
		"max_val": str(source.get("max_val", "100")),
		"collapsed": bool(source.get("collapsed", false)),
		"debug_watch": source.get("debug_watch", false)
	}
	var removed_id := str(source.get("id", ""))
	global_vars_data.remove_at(index)
	variables_data.append(local_data)
	if current_node and not removed_id.is_empty():
		var usage = current_node.get_meta("blueprints_for_godot_global_usage", {})
		if usage is Dictionary:
			usage.erase(removed_id)
			current_node.set_meta("blueprints_for_godot_global_usage", usage)
	_save_global_vars_to_metadata()
	_save_variables_to_metadata()
	_refresh_global_vars_ui()
	_refresh_variables_ui()
	_select_side_tab(0)


func _create_global_variable_ui(index: int, var_data: Dictionary) -> void:
	var panel = PanelContainer.new()
	global_vars_list.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var collapse_btn = Button.new()
	collapse_btn.text = "▼"
	collapse_btn.custom_minimum_size = Vector2(24, 0)
	header.add_child(collapse_btn)

	var name_display = VariableDragLabel.new()
	name_display.text = "⠿  %s: %s" % [var_data.get("name", ""), var_data.get("type", "int")]
	name_display.drag_payload = {"scope":"global", "index":index}
	name_display.tooltip_text = "Drag this global variable into the graph to choose Get or Set, like Unreal Blueprints"
	name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_display)

	var debug_btn = Button.new()
	debug_btn.button_pressed = _is_debug_watch_enabled(var_data.get("debug_watch", false))
	_style_debug_watch_button(debug_btn, debug_btn.button_pressed)
	debug_btn.toggled.connect(_on_global_variable_debug_watch_toggled.bind(index, debug_btn))
	header.add_child(debug_btn)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.pressed.connect(_on_delete_global_variable_pressed.bind(index))
	header.add_child(delete_btn)

	var details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.name = "Details"
	vbox.add_child(details)

	# Name
	var row1 = HBoxContainer.new()
	details.add_child(row1)
	var name_label = Label.new()
	name_label.text = "Name:"
	row1.add_child(name_label)
	var name_edit = LineEdit.new()
	name_edit.text = var_data.get("name", "")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_global_variable_name_changed.bind(index, name_display))
	row1.add_child(name_edit)

	# Type
	var row2 = HBoxContainer.new()
	details.add_child(row2)
	var type_label = Label.new()
	type_label.text = "Type:"
	row2.add_child(type_label)
	var type_option = OptionButton.new()
	var type_names = VariableUtils.get_supported_types()
	var current_type := str(var_data.get("type", "int"))
	if VariableUtils.is_supported_type(current_type) and current_type not in type_names:
		type_names.append(current_type)
	for type_i in range(type_names.size()):
		type_option.add_item(type_names[type_i], type_i)
	var type_index = type_names.find(str(var_data.get("type", "int")))
	type_option.selected = type_index
	type_option.item_selected.connect(_on_global_variable_type_changed.bind(index, name_display))
	row2.add_child(type_option)
	_add_type_expression(details, index, true)

	# Value
	_create_global_variable_value_editor(details, index, var_data)

	# Per-script usage
	var row_use = HBoxContainer.new()
	details.add_child(row_use)
	var use_check = CheckBox.new()
	use_check.text = "Use in this script"
	use_check.button_pressed = _is_global_used_in_current_script(var_data)
	use_check.toggled.connect(_on_global_variable_use_in_script_toggled.bind(index))
	row_use.add_child(use_check)

	var scope_row = HBoxContainer.new()
	details.add_child(scope_row)
	var make_local_btn = Button.new()
	make_local_btn.text = "Make Script Variable"
	make_local_btn.tooltip_text = "Move this value back into the current script instead of keeping it project-global."
	make_local_btn.pressed.connect(_on_make_global_script_variable.bind(index))
	scope_row.add_child(make_local_btn)

	# Min / Max (numeric types only)
	var is_numeric = var_data.get("type", "int") in ["int", "float"]

	var row_min = HBoxContainer.new()
	row_min.visible = is_numeric
	details.add_child(row_min)
	var min_check = CheckBox.new()
	min_check.text = "Min"
	min_check.button_pressed = var_data.get("use_min", false)
	row_min.add_child(min_check)
	var min_edit = LineEdit.new()
	min_edit.text = var_data.get("min_val", "0")
	min_edit.custom_minimum_size = Vector2(60, 0)
	min_edit.editable = var_data.get("use_min", false)
	min_edit.modulate.a = 1.0 if var_data.get("use_min", false) else 0.4
	min_edit.text_changed.connect(_on_global_variable_min_val_changed.bind(index))
	row_min.add_child(min_edit)
	min_check.toggled.connect(_on_global_variable_min_toggled.bind(index, min_edit))

	var row_max = HBoxContainer.new()
	row_max.visible = is_numeric
	details.add_child(row_max)
	var max_check = CheckBox.new()
	max_check.text = "Max"
	max_check.button_pressed = var_data.get("use_max", false)
	row_max.add_child(max_check)
	var max_edit = LineEdit.new()
	max_edit.text = var_data.get("max_val", "100")
	max_edit.custom_minimum_size = Vector2(60, 0)
	max_edit.editable = var_data.get("use_max", false)
	max_edit.modulate.a = 1.0 if var_data.get("use_max", false) else 0.4
	max_edit.text_changed.connect(_on_global_variable_max_val_changed.bind(index))
	row_max.add_child(max_edit)
	max_check.toggled.connect(_on_global_variable_max_toggled.bind(index, max_edit))

	_apply_variable_collapsed_state(collapse_btn, details, var_data.get("collapsed", false))
	collapse_btn.pressed.connect(_on_global_variable_collapse_toggled.bind(index, collapse_btn, details))


func _on_local_variable_debug_watch_toggled(enabled: bool, index: int, button: Button) -> void:
	if index < 0 or index >= variables_data.size():
		return
	variables_data[index]["debug_watch"] = enabled
	_style_debug_watch_button(button, enabled)
	_save_variables_to_metadata()


func _on_global_variable_debug_watch_toggled(enabled: bool, index: int, button: Button) -> void:
	if index < 0 or index >= global_vars_data.size():
		return
	global_vars_data[index]["debug_watch"] = enabled
	_style_debug_watch_button(button, enabled)
	_save_global_vars_to_metadata()


func _on_global_variable_name_changed(new_name: String, index: int, name_display: Label) -> void:
	if index < global_vars_data.size():
		global_vars_data[index]["name"] = new_name
		name_display.text = "⠿  %s: %s" % [new_name, global_vars_data[index].get("type", "int")]
		_save_global_vars_to_metadata()


func _on_global_variable_type_changed(type_index: int, index: int, name_display: Label) -> void:
	if index < global_vars_data.size():
		var type_names = VariableUtils.get_supported_types()
		if type_index < 0 or type_index >= type_names.size():
			return
		var new_type = type_names[type_index]
		global_vars_data[index]["type"] = new_type
		global_vars_data[index]["value"] = VariableUtils.coerce_variable_value_for_type(global_vars_data[index].get("value", VariableUtils.get_default_value_for_variable_type(new_type)), new_type)
		name_display.text = "⠿  %s: %s" % [global_vars_data[index].get("name", ""), new_type]
		_save_global_vars_to_metadata()
		_refresh_global_vars_ui()


func _on_global_variable_value_changed(new_value: String, index: int) -> void:
	if index < global_vars_data.size():
		global_vars_data[index]["value"] = new_value
		_save_global_vars_to_metadata()


func _on_global_variable_use_in_script_toggled(enabled: bool, index: int) -> void:
	_set_global_used_in_current_script(index, enabled)


func _on_global_variable_min_toggled(enabled: bool, index: int, min_edit: LineEdit) -> void:
	min_edit.editable = enabled
	min_edit.modulate.a = 1.0 if enabled else 0.4
	if index < global_vars_data.size():
		global_vars_data[index]["use_min"] = enabled
		_save_global_vars_to_metadata()


func _on_global_variable_min_val_changed(new_val: String, index: int) -> void:
	if index < global_vars_data.size():
		global_vars_data[index]["min_val"] = new_val
		_save_global_vars_to_metadata()


func _on_global_variable_max_toggled(enabled: bool, index: int, max_edit: LineEdit) -> void:
	max_edit.editable = enabled
	max_edit.modulate.a = 1.0 if enabled else 0.4
	if index < global_vars_data.size():
		global_vars_data[index]["use_max"] = enabled
		_save_global_vars_to_metadata()


func _on_global_variable_max_val_changed(new_val: String, index: int) -> void:
	if index < global_vars_data.size():
		global_vars_data[index]["max_val"] = new_val
		_save_global_vars_to_metadata()


func _on_delete_global_variable_pressed(index: int) -> void:
	if index < global_vars_data.size():
		var removed_id = str(global_vars_data[index].get("id", ""))
		global_vars_data.remove_at(index)
		if current_node and not removed_id.is_empty():
			var usage = _get_global_usage_map()
			if usage.has(removed_id):
				usage.erase(removed_id)
				current_node.set_meta("blueprints_for_godot_global_usage", usage)
		_refresh_global_vars_ui()
		_save_global_vars_to_metadata()


func _on_variable_min_toggled(enabled: bool, index: int, min_edit: LineEdit) -> void:
	min_edit.editable = enabled
	min_edit.modulate.a = 1.0 if enabled else 0.4
	if index < variables_data.size():
		variables_data[index]["use_min"] = enabled
		_save_variables_to_metadata()


func _on_variable_min_val_changed(new_val: String, index: int) -> void:
	if index < variables_data.size():
		variables_data[index]["min_val"] = new_val
		_save_variables_to_metadata()


func _on_variable_max_toggled(enabled: bool, index: int, max_edit: LineEdit) -> void:
	max_edit.editable = enabled
	max_edit.modulate.a = 1.0 if enabled else 0.4
	if index < variables_data.size():
		variables_data[index]["use_max"] = enabled
		_save_variables_to_metadata()


func _on_variable_max_val_changed(new_val: String, index: int) -> void:
	if index < variables_data.size():
		variables_data[index]["max_val"] = new_val
		_save_variables_to_metadata()


func _apply_variable_collapsed_state(collapse_btn: Button, details: VBoxContainer, collapsed: bool) -> void:
	details.visible = not collapsed
	collapse_btn.text = "▶" if collapsed else "▼"


func _on_local_variable_collapse_toggled(index: int, collapse_btn: Button, details: VBoxContainer) -> void:
	var collapsed = details.visible
	_apply_variable_collapsed_state(collapse_btn, details, collapsed)
	if index < variables_data.size():
		variables_data[index]["collapsed"] = collapsed
		_save_variables_to_metadata()


func _on_global_variable_collapse_toggled(index: int, collapse_btn: Button, details: VBoxContainer) -> void:
	var collapsed = details.visible
	_apply_variable_collapsed_state(collapse_btn, details, collapsed)
	if index < global_vars_data.size():
		global_vars_data[index]["collapsed"] = collapsed
		_save_global_vars_to_metadata()


func _on_delete_variable_pressed(index: int) -> void:
	# Delete a variable
	if index < variables_data.size():
		variables_data.remove_at(index)
		_refresh_variables_ui()
		_save_variables_to_metadata()


func _save_variables_to_metadata(record_change: bool = true, action_name: String = "Edit Blueprint Node Variable") -> void:
	if not current_node:
		return
	if _is_part_of_instance(current_node) and not _instance_override:
		return
	var target_node = current_node
	var before_snapshot = _take_graph_snapshot()
	target_node.set_meta("blueprints_for_godot_variables", variables_data.duplicate(true))
	_mark_scene_modified()
	_update_global_vars_script()
	if record_change:
		_record_undo(action_name, before_snapshot, _take_graph_snapshot(), target_node, true)


func _save_global_vars_to_metadata(record_change: bool = true, action_name: String = "Edit Global Blueprint Node Variable") -> void:
	if not editor_interface:
		return
	_ensure_global_var_ids()
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	var target_node = current_node
	var before_snapshot = _take_graph_snapshot() if target_node else {}
	scene_root.set_meta("blueprints_for_godot_global_vars", global_vars_data.duplicate(true))
	_mark_scene_modified()
	_update_global_vars_script()
	if record_change and target_node:
		_record_undo(action_name, before_snapshot, _take_graph_snapshot(), target_node, true)


func _update_global_vars_script() -> void:
	if not preload("res://addons/GDBlueprints/core/autoload_policy.gd").is_available("GlobalVars", "res://addons/GDBlueprints/global_vars.gd"):
		push_warning("GDBlueprints: GlobalVars name is owned by another script. Global changes were not written.")
		return
	var script_path = "res://addons/GDBlueprints/global_vars.gd"

	# Merge global_vars_data with whatever is already on disk.
	# This prevents a scene that has no globals metadata from wiping variables
	# that were defined in other scenes.
	var merged: Array[Dictionary] = []
	var merged_names: Array[String] = []

	# Start with current scene's data (highest priority — newest edit wins)
	for var_data in global_vars_data:
		var vname = var_data.get("name", "")
		if not vname.is_empty() and vname not in merged_names:
			merged.append(var_data.duplicate())
			merged_names.append(vname)

	# Fill in any variables from disk that this scene doesn't define
	for disk_var in _read_global_vars_from_script():
		var vname = disk_var.get("name", "")
		if not vname.is_empty() and vname not in merged_names:
			merged.append(disk_var)
			merged_names.append(vname)

	if merged.is_empty():
		var empty_lines: Array[String] = []
		empty_lines.append("extends Node")
		empty_lines.append("")
		empty_lines.append("## Auto-generated by GDBlueprints plugin")
		empty_lines.append("## Global variables shared across all scenes")
		empty_lines.append("")
		empty_lines.append("# === GDBLUEPRINTS GLOBALS START ===")
		empty_lines.append("# (no global variables)")
		empty_lines.append("# === GDBLUEPRINTS GLOBALS END ===")
		empty_lines.append("")
		var empty_file = FileAccess.open(script_path, FileAccess.WRITE)
		if empty_file:
			empty_file.store_string("\n".join(empty_lines))
			empty_file.close()
			if editor_interface:
				editor_interface.get_resource_filesystem().scan()
		return

	var lines: Array[String] = []
	lines.append("extends Node")
	lines.append("")
	lines.append("## Auto-generated by GDBlueprints plugin")
	lines.append("## Global variables shared across all scenes")
	lines.append("## Do not edit between the markers")
	lines.append("")
	lines.append("# === GDBLUEPRINTS GLOBALS START ===")

	for var_data in merged:
		var var_name  = var_data.get("name", "")
		var var_type  = VariableUtils.normalize_type(str(var_data.get("type", "int")))
		var var_value = VariableUtils.to_gdscript_value_literal(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), var_type)
		if not var_name.is_empty():
			lines.append("# GDBlueprints variable: " + '"' + var_to_str(var_data).c_escape() + '"')
			lines.append("var %s: %s = %s" % [var_name, VariableUtils.PinTypes.variable_type(var_type), var_value])

	lines.append("# === GDBLUEPRINTS GLOBALS END ===")
	lines.append("")

	var manager := preload("res://addons/GDBlueprints/core/gdblueprints_manager.gd").new()
	var region := preload("res://addons/GDBlueprints/core/generated_region.gd")
	var start_marker := "# === GDBLUEPRINTS GLOBALS START ==="
	var end_marker := "# === GDBLUEPRINTS GLOBALS END ==="
	var existing := FileAccess.get_file_as_string(script_path) if FileAccess.file_exists(script_path) else "extends Node\n"
	var normalized := existing.replace("# === LOGIC BRICKS GLOBALS START ===", start_marker).replace("# === LOGIC BRICKS GLOBALS END ===", end_marker)
	var check_source := normalized.replace(start_marker, manager.CODE_START_MARKER).replace(end_marker, manager.CODE_END_MARKER)
	var error := manager._validate_generated_markers(check_source)
	if error.is_empty(): error = region.edit_error(normalized, start_marker, end_marker)
	if not error.is_empty():
		push_error(error)
		return
	var generated := "\n".join(lines)
	var first := generated.find(start_marker) + start_marker.length()
	var body := generated.substr(first, generated.find(end_marker) - first).strip_edges()
	var collisions := manager._find_manual_symbol_collisions(check_source, body)
	if not collisions.is_empty():
		push_error("Handwritten globals conflict with generated variables: " + ", ".join(collisions))
		return
	var start := normalized.find(start_marker)
	var end := normalized.find(end_marker)
	var merged_code := normalized.substr(0, start) + start_marker + "\n" + region.seal(body) + normalized.substr(end) if start >= 0 else normalized + "\n" + start_marker + "\n" + region.seal(body) + end_marker + "\n"
	if merged_code == existing:
		_ensure_global_vars_autoload(script_path)
		return
	var buffer_error := preload("res://addons/GDBlueprints/core/script_edit_guard.gd").unsaved_error(editor_interface)
	if not buffer_error.is_empty():
		push_warning(buffer_error)
		return
	var validation := GDScript.new()
	validation.source_code = merged_code
	if validation.reload() != OK:
		push_error("Global variables did not compile; the previous file was preserved.")
		return
	if FileAccess.file_exists(script_path) and FileAccess.get_file_as_string(script_path) != existing:
		push_error("Global script changed during generation; retry after saving.")
		return
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write global variables.")
		return
	file.store_string(merged_code)
	file.close()

	if editor_interface:
		editor_interface.get_resource_filesystem().scan()

	_ensure_global_vars_autoload(script_path)


func _read_global_vars_from_script() -> Array[Dictionary]:
	return VariableUtils.read_global_declarations(FileAccess.get_file_as_string("res://addons/GDBlueprints/global_vars.gd"))


func _ensure_global_vars_autoload(script_path: String) -> void:
	# Use the EditorPlugin API to register autoload (takes effect immediately)
	if not ProjectSettings.has_setting("autoload/GlobalVars"):
		if plugin:
			plugin.ensure_global_vars_autoload(script_path)
		else:
			# Fallback: write to ProjectSettings directly (needs editor restart)
			ProjectSettings.set_setting("autoload/GlobalVars", "*" + script_path)
			ProjectSettings.save()
			print("GDBlueprints: Registered GlobalVars autoload (restart editor to activate)")


func _load_variables_from_metadata() -> void:
	variables_data.clear()
	global_vars_data.clear()

	if not current_node:
		return

	# Load local variables from this node's metadata (non-global only)
	if current_node.has_meta("blueprints_for_godot_variables"):
		var saved_vars = current_node.get_meta("blueprints_for_godot_variables")
		if saved_vars is Array:
			for var_data in saved_vars:
				if not var_data.get("global", false):
					variables_data.append(var_data.duplicate())

	# Load global variables — prefer scene root metadata, fall back to global_vars.gd on disk.
	# This ensures scenes that have never had their Globals tab opened still see all globals
	# defined in other scenes, so variables persist correctly across scene transitions.
	if editor_interface:
		var scene_root = editor_interface.get_edited_scene_root()
		if scene_root and scene_root.has_meta("blueprints_for_godot_global_vars"):
			var saved_globals = scene_root.get_meta("blueprints_for_godot_global_vars")
			if saved_globals is Array:
				for var_data in saved_globals:
					global_vars_data.append(var_data.duplicate())
		else:
			# This scene has no globals metadata yet — read whatever is already in global_vars.gd
			# so the tab shows (and preserves) variables created in other scenes.
			var disk_globals = _read_global_vars_from_script()
			for var_data in disk_globals:
				global_vars_data.append(var_data)
			# If we loaded anything from disk, seed this scene root's metadata so future
			# saves from this scene don't accidentally wipe variables set elsewhere.
			if not global_vars_data.is_empty() and scene_root:
				scene_root.set_meta("blueprints_for_godot_global_vars", global_vars_data.duplicate())

	_ensure_global_var_ids()

	# Backward compatibility: migrate any legacy globals stored on the node into the usage map.
	if current_node.has_meta("blueprints_for_godot_variables"):
		var legacy_vars = current_node.get_meta("blueprints_for_godot_variables")
		if legacy_vars is Array:
			var usage_map = _get_global_usage_map()
			var usage_changed = false
			for legacy_var in legacy_vars:
				if not legacy_var.get("global", false):
					continue
				var legacy_name = str(legacy_var.get("name", ""))
				if legacy_name.is_empty():
					continue
				for global_var in global_vars_data:
					if str(global_var.get("name", "")) == legacy_name:
						var gid = str(global_var.get("id", ""))
						if not gid.is_empty() and not usage_map.has(gid):
							usage_map[gid] = true
							usage_changed = true
						break
			if usage_changed:
				current_node.set_meta("blueprints_for_godot_global_usage", usage_map)

	_refresh_variables_ui()
	_refresh_global_vars_ui()


func _build_export_range_str(var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
	var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
	var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
	return "%s, %s" % [lo, hi]


func _build_clamp_expr(val_var: String, var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
	var fn = "clampi" if var_type == "int" else "clampf"
	var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
	var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
	return "%s(%s, %s, %s)" % [fn, val_var, lo, hi]


func _value_to_line_edit_text(value) -> String:
	return VariableUtils.value_to_line_edit_text(value)


func get_variables_code() -> String:
	var lines: Array[String] = []
	var used_globals: Array[Dictionary] = []
	for var_data in global_vars_data:
		if _is_global_used_in_current_script(var_data):
			used_globals.append(var_data)

	if not variables_data.is_empty() or not used_globals.is_empty():
		lines.append("# Variables")

	# Local variables only
	for var_data in variables_data:
		var var_name  = var_data.get("name", "")
		var var_type  = var_data.get("type", "int")
		var var_value = VariableUtils.to_gdscript_value_literal(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), var_type)
		var exported  = var_data.get("exported", false)
		var use_min   = var_data.get("use_min", false)
		var min_val   = var_data.get("min_val", "0")
		var use_max   = var_data.get("use_max", false)
		var max_val   = var_data.get("max_val", "100")
		var has_range = (var_type in ["int", "float"]) and (use_min or use_max)

		if has_range and exported:
			var range_str = _build_export_range_str(var_type, use_min, min_val, use_max, max_val)
			lines.append("@export_range(%s) var %s: %s = %s" % [range_str, var_name, var_type, var_value])
		elif has_range and not exported:
			var clamp_expr = _build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)
			lines.append("var _%s_raw: %s = %s" % [var_name, VariableUtils.PinTypes.variable_type(var_type), var_value])
			lines.append("var %s: %s:" % [var_name, VariableUtils.PinTypes.variable_type(var_type)])
			lines.append("\tget: return _%s_raw" % var_name)
			lines.append("\tset(val): _%s_raw = %s" % [var_name, clamp_expr])
		else:
			var declaration = ""
			if exported:
				declaration += VariableUtils.export_annotation(var_type)
			declaration += "var %s: %s = %s" % [var_name, VariableUtils.PinTypes.variable_type(var_type), var_value]
			lines.append(declaration)

	for var_data in used_globals:
		var var_name = var_data.get("name", "")
		var var_type = var_data.get("type", "int")
		var use_min = var_data.get("use_min", false)
		var min_val = var_data.get("min_val", "0")
		var use_max = var_data.get("use_max", false)
		var max_val = var_data.get("max_val", "100")
		if var_name.is_empty():
			continue
		lines.append("var %s: %s:" % [var_name, VariableUtils.PinTypes.variable_type(var_type)])
		lines.append("	get:")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		lines.append("		return _gv.%s if _gv else null" % var_name)
		lines.append("	set(val):")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		if var_type in ["int", "float"] and (use_min or use_max):
			var clamp_expr = _build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)
			lines.append("		if _gv: _gv.%s = %s" % [var_name, clamp_expr])
		else:
			lines.append("		if _gv: _gv.%s = val" % var_name)

	if lines.is_empty():
		return ""
	lines.append("")
	return "\n".join(lines)


## Add a new frame to the graph

## Frame tracking: maps frame names to arrays of node names
var frame_node_mapping: Dictionary = {}  # {"frame_name": ["node1", "node2", ...]}
var frame_titles: Dictionary = {}  # {"frame_name": "Custom Title"}
var frame_comments: Dictionary = {}  # {"frame_name": "Optional multiline comment"}


## Add a new frame to the graph
func _on_add_frame_pressed() -> void:
	_frames_helper.on_add_frame_pressed(self)


## Handle frame click to select it in side panel (DISABLED - was blocking editor input)
#func _on_frame_gui_input(event: InputEvent, frame: GraphFrame) -> void:
#    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
#        _select_frame_in_side_panel(frame)





## Handle brick node being dragged
func _on_brick_node_dragged(from: Vector2, to: Vector2, node: GraphNode) -> void:
	var warning = graph_edit.get_node_or_null(NodePath(_warning_node_name(node)))
	if warning is GraphNode:
		warning.position_offset = node.position_offset + Vector2(0, -warning.size.y - 10)
	# Check if node entered/left any frames
	_frames_helper.check_node_frame_membership(self, node)

	# Auto-resize frames that contain this node
	for frame_name in frame_node_mapping.keys():
		if node.name in frame_node_mapping[frame_name]:
			var frame = graph_edit.get_node_or_null(NodePath(frame_name))
			if frame and frame is GraphFrame:
				_frames_helper.auto_resize_frame(self, frame)

	# Save node positions
	_save_graph_to_metadata()


func _on_reroute_dragged(from: Vector2, to: Vector2, reroute: GraphNode) -> void:
	# Skip if the reroute already has connections
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		if conn["from_node"] == reroute.name or conn["to_node"] == reroute.name:
			_save_graph_to_metadata()
			return

	# Check if the reroute landed on top of an existing connection
	var reroute_center = reroute.position_offset + reroute.size / 2.0
	var best_conn = null
	var best_dist = 40.0  # Max distance in graph units to snap

	for conn in connections:
		var from_node = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
		var to_node = graph_edit.get_node_or_null(NodePath(conn["to_node"]))
		if not from_node or not to_node:
			continue

		# Get approximate port positions (output port on right side, input port on left side)
		var from_pos = from_node.position_offset + Vector2(from_node.size.x, from_node.size.y / 2.0)
		var to_pos = to_node.position_offset + Vector2(0, to_node.size.y / 2.0)

		# Distance from reroute center to the line segment
		var dist = _point_to_segment_distance(reroute_center, from_pos, to_pos)
		if dist < best_dist:
			best_dist = dist
			best_conn = conn

	if best_conn:
		# Remove the original connection
		graph_edit.disconnect_node(best_conn["from_node"], best_conn["from_port"], best_conn["to_node"], best_conn["to_port"])
		# Insert reroute: original_from → reroute → original_to
		graph_edit.connect_node(best_conn["from_node"], best_conn["from_port"], reroute.name, 0)
		graph_edit.connect_node(reroute.name, 0, best_conn["to_node"], best_conn["to_port"])

	_save_graph_to_metadata()


func _point_to_segment_distance(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab = seg_b - seg_a
	var ap = point - seg_a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq == 0.0:
		return ap.length()
	var t = clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest = seg_a + ab * t
	return point.distance_to(closest)


## Handle frame being dragged
func _on_frame_dragged(from: Vector2, to: Vector2, frame: GraphFrame) -> void:
	_frames_helper.on_frame_dragged(self, from, to, frame)

## Handle frame resize
func _on_frame_resize_request(new_size: Vector2, frame: GraphFrame) -> void:
	_frames_helper.on_frame_resize_request(self, new_size, frame)




## Frame Panel Callbacks

func _update_frames_list() -> void:
	_frames_helper.update_frames_list(self)


func _save_frames_to_metadata(record_change: bool = true, action_name: String = "Edit Blueprint Node Frame") -> void:
	_frames_helper.save_frames_to_metadata(self, record_change, action_name)


func _update_frame_settings_ui() -> void:
	_frames_helper.update_frame_settings_ui(self)


func _select_frame_in_side_panel(frame: GraphFrame) -> void:
	_frames_helper.select_frame_in_side_panel(self, frame)


func _on_frame_list_item_selected(index: int) -> void:
	_frames_helper.on_frame_list_item_selected(self, index)


func _on_frame_name_changed(new_name: String) -> void:
	_frames_helper.on_frame_name_changed(self, new_name)

func _on_frame_comment_changed() -> void:
	_frames_helper.on_frame_comment_changed(self)

func _on_frame_color_changed(new_color: Color) -> void:
	_frames_helper.on_frame_color_changed(self, new_color)

func _on_frame_resize_pressed() -> void:
	_frames_helper.on_frame_resize_pressed(self)

func _on_frame_width_changed(new_width: float) -> void:
	_frames_helper.on_frame_width_changed(self, new_width)

func _on_frame_height_changed(new_height: float) -> void:
	_frames_helper.on_frame_height_changed(self, new_height)

func _on_frame_delete_pressed() -> void:
	_frames_helper.on_frame_delete_pressed(self)



func _on_frame_list_item_activated(index: int) -> void:
	_frames_helper.on_frame_list_item_activated(self, index)

func _on_frame_rename_button_pressed() -> void:
	_frames_helper.on_frame_rename_button_pressed(self)

func _on_rename_dialog_confirmed(dialog: AcceptDialog, line_edit: LineEdit) -> void:
	_frames_helper.on_rename_dialog_confirmed(self, dialog, line_edit)

func _on_rename_dialog_canceled(dialog: AcceptDialog) -> void:
	_frames_helper.on_rename_dialog_canceled(self, dialog)

func _on_frame_list_color_changed(new_color: Color) -> void:
	_frames_helper.on_frame_list_color_changed(self, new_color)

## Mark the scene as modified so changes are saved
func _mark_scene_modified() -> void:
	if not editor_interface:
		return

	# Mark the currently edited scene as unsaved
	# This is the correct way to tell Godot the scene needs saving
	editor_interface.mark_scene_as_unsaved()


## Build, update, or remove scene nodes required by special actuators.
## Called after Apply Code so nodes exist in the scene before the script runs.
func _apply_scene_setup_create(node: Node, chains: Array) -> void:
	# Phase 1 of Apply Code scene setup: create scene nodes and clean up stale ones.
	# @export var assignments are done separately in _apply_scene_setup_assign(),
	# which must run AFTER set_script() so the assignments aren't wiped.
	var scene_root = node.get_tree().edited_scene_root if node.get_tree() else null
	if not scene_root:
		return

	# ── Waypoint Path: create Path3D helper nodes when Path3D mode is selected ──
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") != "WaypointPathActuator":
				continue
			var brick_script = load("res://addons/GDBlueprints/bricks/actuators/3d/waypoint_path_actuator.gd")
			if not brick_script:
				push_warning("GDBlueprints: Could not load waypoint_path_actuator.gd")
				continue
			var brick = brick_script.new()
			brick.deserialize(actuator_data)
			if node is Node3D:
				brick_script.sync_path3d_node(node, brick)

	# ── Waypoint Path 2D: create Path2D helper nodes when Path2D mode is selected ──
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") != "WaypointPath2DActuator":
				continue
			var brick_script_2d = load("res://addons/GDBlueprints/bricks/actuators/2d/waypoint_path_2d_actuator.gd")
			if not brick_script_2d:
				push_warning("GDBlueprints: Could not load waypoint_path_2d_actuator.gd")
				continue
			var brick_2d = brick_script_2d.new()
			brick_2d.deserialize(actuator_data)
			if node is Node2D:
				brick_script_2d.sync_path2d_node(node, brick_2d)

	# ── SplitScreen: free stale _ss_canvas_* nodes if the actuator was removed ──
	var has_split_screen := false
	for chain in chains:
		for actuator in chain.get("actuators", []):
			if actuator.get("type", "") == "SplitScreenActuator":
				has_split_screen = true
				break
		if has_split_screen:
			break

	if not has_split_screen:
		var stale_ss: Array = []
		for child in scene_root.get_children():
			if child is CanvasLayer and child.name.begins_with("_ss_canvas_"):
				stale_ss.append(child)
		for cl in stale_ss:
			cl.free()

	# ── ScreenFlash: create/update CanvasLayer + ColorRect nodes ────────────
	var active_flash_layers: Array = []

	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") != "ScreenFlashActuator":
				continue

			var brick_script = load("res://addons/GDBlueprints/bricks/actuators/common/screen_flash_actuator.gd")
			if not brick_script:
				push_warning("GDBlueprints: Could not load screen_flash_actuator.gd")
				continue
			var brick = brick_script.new()
			brick.deserialize(actuator_data)
			var gen = brick.generate_code(node, chain.get("name", "chain"))
			var setup = gen.get("scene_setup", {})
			if setup.get("type", "") != "ScreenFlash":
				continue

			var flash_var: String  = setup.get("flash_var", "")
			var cam_name: String   = setup.get("camera_name", "").strip_edges()
			if flash_var.is_empty():
				continue

			var layer_name := "__FlashLayer_%s" % flash_var
			active_flash_layers.append(layer_name)

			# Determine size to match the target camera's viewport
			var flash_size := Vector2(
				ProjectSettings.get_setting("display/window/size/viewport_width",  1280),
				ProjectSettings.get_setting("display/window/size/viewport_height", 720)
			)

			if not cam_name.is_empty():
				var cam := _find_camera_by_name(scene_root, cam_name)
				if is_instance_valid(cam):
					var p := cam.get_parent()
					while is_instance_valid(p):
						if p is SubViewportContainer:
							flash_size = (p as SubViewportContainer).size
							break
						elif p is SubViewport:
							flash_size = Vector2((p as SubViewport).size)
							break
						p = p.get_parent()
				else:
					push_warning("Screen Flash Action: Camera '%s' not found — using full window size" % cam_name)

			# Find or create the CanvasLayer
			var canvas_layer: CanvasLayer = null
			for child in scene_root.get_children():
				if child is CanvasLayer and child.name == layer_name:
					canvas_layer = child as CanvasLayer
					break
			if not is_instance_valid(canvas_layer):
				canvas_layer = CanvasLayer.new()
				canvas_layer.name = layer_name
				canvas_layer.layer = 128
				scene_root.add_child(canvas_layer)
				canvas_layer.owner = scene_root

			# Find or create the ColorRect inside the CanvasLayer
			var color_rect: ColorRect = canvas_layer.get_node_or_null("ColorRect") as ColorRect
			if not is_instance_valid(color_rect):
				color_rect = ColorRect.new()
				color_rect.name = "ColorRect"
				canvas_layer.add_child(color_rect)
				color_rect.owner = scene_root

			# Full-screen flash layers should stretch with the viewport instead of
			# relying on a one-time editor size snapshot.
			color_rect.anchor_left   = 0.0
			color_rect.anchor_top    = 0.0
			color_rect.anchor_right  = 1.0
			color_rect.anchor_bottom = 1.0
			color_rect.offset_left   = 0.0
			color_rect.offset_top    = 0.0
			color_rect.offset_right  = 0.0
			color_rect.offset_bottom = 0.0
			color_rect.position      = Vector2.ZERO
			color_rect.color         = Color(0, 0, 0, 0)
			color_rect.visible       = false
			color_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# Free stale flash layers from removed ScreenFlashActuator bricks
	var stale_flash: Array = []
	for child in scene_root.get_children():
		if child is CanvasLayer and child.name.begins_with("__FlashLayer_")                 and child.name not in active_flash_layers:
			stale_flash.append(child)
	for cl in stale_flash:
		cl.free()



func _apply_scene_setup_assign(node: Node, chains: Array) -> void:
	# Phase 2 of Apply Code scene setup: assign @export vars to the pre-created nodes.
	# Must run AFTER set_script() — set_script() resets all properties, so any
	# assignment done before it would be silently discarded.
	#
	# NOTE: ScreenFlash no longer uses @export vars. The generated actuator code
	# resolves the ColorRect by node path at runtime via get_tree().root.get_node_or_null().
	# No assignment is needed here for that actuator type.
	pass

func _find_camera_by_name(root: Node, cam_name: String) -> Camera3D:
	if not is_instance_valid(root): return null
	for child in root.get_children():
		if not is_instance_valid(child): continue
		if child is Camera3D and child.name == cam_name:
			return child
		elif not child is SubViewport:
			var found = _find_camera_by_name(child, cam_name)
			if found:
				return found
	return null


func _add_type_expression(parent: Control, index: int, global_value: bool) -> void:
	var data: Array = global_vars_data if global_value else variables_data
	var field := LineEdit.new()
	field.name = "TypeExpression"
	field.text = str(data[index].type)
	field.placeholder_text = "Array[int], Dictionary[String, int], Enum[Idle=0, Running=10]"
	field.tooltip_text = "Advanced type. Press Enter to apply. Existing initial values must fit the new type; edit the value first if needed."
	field.text_submitted.connect(func(text: String):
		var error := _apply_type_expression(text, index, global_value)
		if not error.is_empty():
			field.tooltip_text = error
			push_warning(error)
	)
	parent.add_child(field)

func _apply_type_expression(text: String, index: int, global_value: bool) -> String:
	var type_name := text.strip_edges()
	if not VariableUtils.is_supported_type(type_name): return "Unsupported type. Use a Godot type, Array[T], Dictionary[K, V], or Enum[Name=integer, ...]. Nested typed containers are unsupported by GDScript."
	var data: Array = global_vars_data if global_value else variables_data
	if index < 0 or index >= data.size(): return "Variable no longer exists."
	var value: Variant = VariableUtils.coerce_variable_value_for_type(data[index].value, type_name)
	if not VariableUtils.Collections.parse(type_name).is_empty() and not VariableUtils.Collections.accepts(value, type_name):
		return "The current initial value does not fit this type. Edit it first; the original type and value have been preserved."
	data[index].type = type_name
	data[index].value = value
	if global_value:
		_save_global_vars_to_metadata()
		_refresh_global_vars_ui()
	else:
		if not VariableUtils.can_export(type_name): data[index].exported = false
		_save_variables_to_metadata()
		_refresh_variables_ui()
	return ""

