@tool
extends RefCounted

## Runtime registry for Blueprint Node scripts.
##
## New bricks can be added by dropping a single .gd file anywhere under:
##   res://addons/GDBlueprints/bricks/sensors/
##   res://addons/GDBlueprints/bricks/controllers/
##   res://addons/GDBlueprints/bricks/actuators/
##
## Minimum brick file requirements:
##   - extends res://addons/GDBlueprints/core/blueprint_node.gd
##   - _init() sets brick_type and brick_name
##
## Optional per-brick metadata:
##   func get_brick_info() -> Dictionary:
##       return {
##           "class": "GridMapActuator",
##           "name": "Grid Map",
##           "type": "actuator",
##           "category": "Grid",
##           "description": "Set, clear, or read cells in a GridMap.",
##           "menu_order": 360,
##           "aliases": []
##       }

const BRICK_ROOT := "res://addons/GDBlueprints/bricks"
const BlueprintNodeBase = preload("res://addons/GDBlueprints/core/blueprint_node.gd")
# Path shims remain loadable for old scenes, but must not register twice.
const COMPATIBILITY_SHIMS := [
	BRICK_ROOT + "/actuators/common/scale_actuator.gd",
	BRICK_ROOT + "/actuators/2d/property_actuator.gd",
	BRICK_ROOT + "/actuators/3d/rotation_actuator.gd",
	BRICK_ROOT + "/actuators/3d/scale_actuator.gd",
]
# Optional project-local extension roots. Contributors can keep custom/community
# nodes outside the addon itself so upgrading GDBlueprints does not overwrite
# them. Modern external nodes should declare their type in get_blueprint_definition()
# or get_brick_info(), because their folder name is not used for type inference.
const EXTERNAL_NODE_ROOTS := [
	"res://gdblueprints_nodes",
	"res://addons/gdblueprints_nodes",
	"res://blueprints_for_godot_nodes",
	"res://addons/blueprints_for_godot_nodes",
]

static var _scanned: bool = false
static var _bricks_by_class: Dictionary = {}
static var _bricks_by_type: Dictionary = {"sensor": [], "controller": [], "actuator": [], "value": []}
static var _aliases: Dictionary = {}
static var _next_menu_id: int = 1000
static var _discovery_errors: Array[String] = []


const LegacyCatalog = preload("res://addons/GDBlueprints/core/legacy_node_catalog.gd")

static func refresh() -> void:
	_scanned = false
	_bricks_by_class.clear()
	_bricks_by_type = {"sensor": [], "controller": [], "actuator": [], "value": []}
	_aliases.clear()
	_next_menu_id = 1000
	_discovery_errors.clear()
	ensure_scanned()

static func invalidate() -> void:
	_scanned = false
	_bricks_by_class.clear()
	_bricks_by_type = {"sensor": [], "controller": [], "actuator": [], "value": []}
	_aliases.clear()
	_next_menu_id = 1000
	_discovery_errors.clear()

static func get_discovery_errors() -> Array[String]:
	ensure_scanned()
	return _discovery_errors.duplicate()

static func get_registered_bricks() -> Array:
	ensure_scanned()
	return _bricks_by_class.values().filter(func(info): return not info.has("alias_for")).duplicate(true)

static func ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	_scan_dir(BRICK_ROOT)
	for external_root in EXTERNAL_NODE_ROOTS:
		# _scan_dir() safely no-ops when the optional directory does not exist.
		_scan_dir(external_root)
	for alias_name in LegacyCatalog.ALIASES.keys():
		var target = LegacyCatalog.ALIASES[alias_name]
		if alias_name == target or _bricks_by_class.has(alias_name):
			continue
		if _bricks_by_class.has(target):
			_aliases[alias_name] = target
			var alias_info: Dictionary = _bricks_by_class[target].duplicate(true)
			alias_info["class"] = alias_name
			alias_info["alias_for"] = target
			_bricks_by_class[alias_name] = alias_info
	for t in _bricks_by_type.keys():
		_bricks_by_type[t].sort_custom(func(a, b):
			var ac: String = str(a.get("category", ""))
			var bc: String = str(b.get("category", ""))
			if ac == bc:
				var ao: int = int(a.get("menu_order", 9999))
				var bo: int = int(b.get("menu_order", 9999))
				if ao == bo:
					return str(a.get("name", "")) < str(b.get("name", ""))
				return ao < bo
			return ac < bc
		)

static func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	if FileAccess.file_exists(path.path_join(".gdignore")):
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if file_name.ends_with(".gd") and not file_name.begins_with("."):
			_register_script(path.path_join(file_name))
	var directories := dir.get_directories()
	directories.sort()
	for child in directories:
		if not child.begins_with("."):
			_scan_dir(path.path_join(child))

static func _register_script(script_path: String) -> void:
	if script_path in COMPATIBILITY_SHIMS:
		return
	var script = load(script_path)
	if script == null or not script.can_instantiate():
		_discovery_errors.append("Cannot load node script: " + script_path)
		return
	var base = script
	while base != null and base != BlueprintNodeBase:
		base = base.get_base_script()
	if base == null:
		# Extension folders may also contain helper scripts; don't execute them.
		return
	var instance = script.new()
	if instance == null:
		return
	var info := _build_info_from_instance(instance, script_path)
	if info.is_empty():
		return
	_register_info(info)

static func _build_info_from_instance(instance, script_path: String) -> Dictionary:
	var info: Dictionary = {}
	if instance.has_method("get_brick_info"):
		var custom = instance.call("get_brick_info")
		if typeof(custom) == TYPE_DICTIONARY:
			info = custom.duplicate(true)

	# New contributor API: get_blueprint_definition() can centralize searchable
	# metadata and pin declarations. Legacy get_brick_info() remains supported.
	if instance.has_method("get_blueprint_definition"):
		var definition = instance.call("get_blueprint_definition")
		if definition is Dictionary:
			if not info.has("class") and not str(definition.get("class", definition.get("id", ""))).is_empty():
				info["class"] = str(definition.get("class", definition.get("id", "")))
			if not info.has("name") and not str(definition.get("display_name", "")).is_empty():
				info["name"] = str(definition.get("display_name", ""))
			for key in ["category", "description", "godot_term", "aliases", "menu_order", "domain", "hidden_menu", "requires_physics"]:
				if not info.has(key) and definition.has(key):
					info[key] = definition[key]
			if not info.has("type"):
				var kind := str(definition.get("kind", ""))
				info["type"] = {"event":"sensor", "flow":"controller", "action":"actuator", "value":"value"}.get(kind, "")

	var brick_type := str(info.get("type", ""))
	if brick_type.is_empty():
		brick_type = _infer_type_from_path(script_path)
	if not ["sensor", "controller", "actuator", "value"].has(brick_type):
		return {}

	var brick_class_name: String = str(info.get("class", ""))
	if brick_class_name.is_empty():
		brick_class_name = _class_name_from_file(script_path, brick_type)

	var display_name := str(info.get("name", ""))
	if display_name.is_empty():
		var bn = instance.get("brick_name")
		if bn != null:
			display_name = str(bn)
	if display_name.is_empty():
		display_name = _display_name_from_class(brick_class_name)

	var tooltips: Dictionary = {}
	if instance.has_method("get_tooltip_definitions"):
		var tip_defs = instance.call("get_tooltip_definitions")
		if typeof(tip_defs) == TYPE_DICTIONARY:
			tooltips = tip_defs

	var category := str(info.get("category", ""))
	if category.is_empty():
		category = str(LegacyCatalog.CATEGORIES.get(brick_class_name, "General"))
	if brick_type != "actuator" and category == "General":
		category = ""

	var description := str(info.get("description", ""))
	if description.is_empty() and tooltips.has("_description"):
		description = str(tooltips["_description"])

	var godot_term := str(info.get("godot_term", ""))
	if LegacyCatalog.UI_OVERRIDES.has(brick_class_name):
		var ui: Dictionary = LegacyCatalog.UI_OVERRIDES[brick_class_name]
		display_name = str(ui.get("name", display_name))
		godot_term = str(ui.get("godot_term", godot_term))
		description = str(ui.get("description", description))
		var merged_aliases: Array = []
		for a in info.get("aliases", []):
			merged_aliases.append(a)
		for a in ui.get("aliases", []):
			if a not in merged_aliases:
				merged_aliases.append(a)
		info["aliases"] = merged_aliases

	return {
		"class": brick_class_name,
		"name": display_name,
		"type": brick_type,
		"category": category,
		"description": description,
		"menu_order": int(info.get("menu_order", 9999)),
		"hidden_menu": bool(info.get("hidden_menu", false)),
		"script_path": script_path,
		"requires_physics": info.get("requires_physics", false) == true,
		"menu_id": int(info.get("menu_id", _allocate_menu_id())),
		"aliases": info.get("aliases", []),
		"godot_term": godot_term,
		"domain": str(info.get("domain", "")) if not str(info.get("domain", "")).is_empty() else _infer_domain_from_path(script_path),
	}

static func _register_info(info: Dictionary) -> void:
	var brick_class_name: String = str(info.get("class", ""))
	var brick_type := str(info.get("type", ""))
	if brick_class_name.is_empty() or brick_type.is_empty():
		return

	# Never silently replace a saved node ID with another implementation.
	if _bricks_by_class.has(brick_class_name):
		var previous: Dictionary = _bricks_by_class[brick_class_name]
		_discovery_errors.append("Duplicate node ID '%s': %s and %s" % [brick_class_name, previous.get("script_path", ""), info.get("script_path", "")])
		return

	_bricks_by_class[brick_class_name] = info
	var filename_id := str(info.get("script_path", "")).get_file().get_basename()
	if not _aliases.has(filename_id):
		_aliases[filename_id] = brick_class_name
	if _bricks_by_type.has(brick_type) and not bool(info.get("hidden_menu", false)):
		_bricks_by_type[brick_type].append(info)
	for alias_name in info.get("aliases", []):
		_aliases[str(alias_name)] = brick_class_name

static func get_script_path(brick_class: String) -> String:
	ensure_scanned()
	var resolved = brick_class if _bricks_by_class.has(brick_class) else str(_aliases.get(brick_class, brick_class))
	var info: Dictionary = _bricks_by_class.get(resolved, _bricks_by_class.get(brick_class, {}))
	return str(info.get("script_path", ""))

static func get_brick_info(brick_class: String) -> Dictionary:
	ensure_scanned()
	var resolved = brick_class if _bricks_by_class.has(brick_class) else str(_aliases.get(brick_class, brick_class))
	return _bricks_by_class.get(resolved, _bricks_by_class.get(brick_class, {})).duplicate(true)

static func get_bricks_by_type(brick_type: String, domain: String = "") -> Array:
	ensure_scanned()
	var bricks: Array = _bricks_by_type.get(brick_type, [])
	if domain.is_empty():
		return bricks.duplicate(true)
	var filtered: Array = []
	for info in bricks:
		var brick_class := str(info.get("class", ""))
		# 2D uses Sprite Animation and Tween Animation instead of the generic
		# AnimationPlayer/Tween entries from the common folder.
		if domain == "2d" and ["AnimationActuator", "TweenActuator"].has(brick_class):
			continue
		# Common nodes are available on UI children too. Only hide common
		# implementations that have a dedicated UI replacement.
		# This avoids duplicate entries for Visibility,
		# Screen Flash, 2D Audio, Modulate, and Tween.
		if domain == "ui" and brick_class in ["VisibilityActuator", "Audio2DActuator", "ModulateActuator", "TweenActuator", "ScreenFlashActuator"]:
			continue
		if _is_domain_compatible(str(info.get("domain", "common")), domain):
			filtered.append(info)
	return filtered

static func get_all_bricks(domain: String = "") -> Array:
	ensure_scanned()
	var result: Array = []
	for t in ["sensor", "controller", "actuator", "value"]:
		result.append_array(get_bricks_by_type(t, domain))
	return result

static func _is_domain_compatible(brick_domain: String, target_domain: String) -> bool:
	if brick_domain.is_empty():
		brick_domain = "common"
	if target_domain.is_empty():
		return true
	if brick_domain == "common":
		return true
	return brick_domain == target_domain

static func _infer_type_from_path(path: String) -> String:
	if path.find("/sensors/") >= 0:
		return "sensor"
	if path.find("/controllers/") >= 0:
		return "controller"
	if path.find("/actuators/") >= 0:
		return "actuator"
	if path.find("/values/") >= 0:
		return "value"
	return ""


static func _infer_domain_from_path(path: String) -> String:
	if path.find("/ui/") >= 0:
		return "ui"
	if path.find("/2d/") >= 0:
		return "2d"
	if path.find("/3d/") >= 0:
		return "3d"
	return "common"

static func _class_name_from_file(path: String, brick_type: String) -> String:
	var base := path.get_file().get_basename()
	var parts := base.split("_")
	var result := ""
	for p in parts:
		if p.is_empty():
			continue
		result += p.substr(0, 1).to_upper() + p.substr(1)
	if brick_type == "controller" and not result.ends_with("Controller"):
		result += "Controller"
	return result

static func _display_name_from_class(cls_name: String) -> String:
	var s := cls_name
	for suffix in ["Sensor", "Controller", "Actuator"]:
		if s.ends_with(suffix):
			s = s.substr(0, s.length() - suffix.length())
	var out := ""
	for i in range(s.length()):
		var c := s.substr(i, 1)
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			out += " "
		out += c
	return out

static func _allocate_menu_id() -> int:
	_next_menu_id += 1
	return _next_menu_id
