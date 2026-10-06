extends SceneTree

const Registry = preload("res://addons/GDBlueprints/core/brick_registry.gd")
const Docs = preload("res://addons/GDBlueprints/core/documentation_helper.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var text := FileAccess.get_file_as_string(Docs.DOC_ROOT + "/nodes.html")
	for info in Registry.get_registered_bricks():
		if not str(info.script_path).begins_with(Registry.BRICK_ROOT + "/"): continue
		var path := Docs.get_node_page(str(info["class"]))
		var anchor := path.get_slice("#", 1).uri_decode()
		if not text.contains('id="%s"' % anchor): failures.append(str(info["class"]))
		for alias in info.aliases:
			var resolved := Registry.get_brick_info(str(alias))
			if resolved.is_empty(): continue
			var alias_anchor := Docs.get_node_page(str(alias)).get_slice("#", 1).uri_decode()
			if not text.contains('id="%s"' % alias_anchor): failures.append(str(alias))
	print("Documentation link failures: %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
