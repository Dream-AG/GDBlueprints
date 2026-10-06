@tool
extends RefCounted

const DOC_ROOT := "res://addons/GDBlueprints/documentation"

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")

static func open_home() -> void:
	_open_local_page("index.html")

static func open_value(info: Dictionary) -> void:
	if not str(info.get("brick_class", "")).is_empty():
		open_brick(str(info.brick_class), "")
	elif str(info.get("kind", "")) == "node":
		_open_local_page("references-and-scenes.html#browse-properties")
	elif str(info.get("kind", "")) == "variable":
		_open_local_page("user-guide.html#variables-and-states")
	else:
		_open_local_page("user-guide.html#events-flow-actions-and-values")

static func get_node_page(node_id: String) -> String:
	var info := Registry.get_brick_info(node_id)
	var canonical := str(info.get("alias_for", info.get("class", node_id)))
	return "nodes.html#" + canonical.uri_encode()

static func open_brick(brick_class: String, _domain: String) -> void:
	var info := Registry.get_brick_info(brick_class)
	if str(info.get("script_path", "")).begins_with(Registry.BRICK_ROOT + "/"):
		_open_local_page(get_node_page(brick_class))
	else:
		_open_local_page("contributing.html#project-nodes")

static func _open_local_page(relative_path: String) -> void:
	var anchor: String = ""
	var file_part: String = relative_path
	var hash_pos: int = relative_path.find("#")
	if hash_pos >= 0:
		file_part = relative_path.substr(0, hash_pos)
		anchor = relative_path.substr(hash_pos)

	var local_path: String = ProjectSettings.globalize_path(DOC_ROOT.path_join(file_part)).replace("\\", "/")
	var target_url: String = _file_url(local_path) + anchor

	# Some desktop file handlers drop a URL fragment when OS.shell_open() is
	# given file:///page.html#section directly. Use a tiny local redirect page
	# when deep-linking so the browser itself applies the fragment reliably.
	var open_url: String = target_url
	if not anchor.is_empty():
		var redirect_path: String = ProjectSettings.globalize_path("user://blueprints_for_godot_doc_jump.html").replace("\\", "/")
		var redirect_file: FileAccess = FileAccess.open(redirect_path, FileAccess.WRITE)
		if redirect_file:
			var escaped_target: String = target_url.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")
			redirect_file.store_string("<!doctype html><html><head><meta charset=\"utf-8\"><meta http-equiv=\"refresh\" content=\"0; url=" + escaped_target + "\"></head><body><p>Opening GDBlueprints documentation...</p><p><a href=\"" + escaped_target + "\">Continue</a></p></body></html>")
			redirect_file.close()
			open_url = _file_url(redirect_path)

	var err: int = OS.shell_open(open_url)
	if err != OK:
		push_warning("GDBlueprints: Could not open documentation: %s" % open_url)


static func _file_url(local_path: String) -> String:
	var encoded_path: String = local_path.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("\"", "%22")
	var url: String = "file://"
	if not encoded_path.begins_with("/"):
		url += "/"
	return url + encoded_path

