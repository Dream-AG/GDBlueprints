extends RefCounted
## Runtime target resolution. Explicit references and NodePaths avoid tree scans.
## Name lookup remains a compatibility fallback; no persistent cache can go stale.

static func resolve(owner: Node, target: Variant, scope: String = "scene") -> Node:
	if not is_instance_valid(owner) or owner.is_queued_for_deletion(): return null
	if typeof(target) == TYPE_OBJECT:
		return target if is_instance_valid(target) and target is Node and not target.is_queued_for_deletion() else null
	if not (target is String or target is StringName or target is NodePath): return null
	var path := str(target).strip_edges()
	if path.is_empty() or path.to_lower() == "self": return owner
	if path.begins_with("/") and not owner.is_inside_tree(): return null
	var direct := owner.get_node_or_null(NodePath(path))
	if is_instance_valid(direct):
		return direct if not direct.is_queued_for_deletion() else null
	# An explicit path must never silently fall back to an unrelated named node.
	if target is NodePath or path.contains("/") or path.begins_with("."): return null
	if not owner.is_inside_tree(): return null
	var tree := owner.get_tree()
	var scene := tree.current_scene
	var found: Node
	if scope == "owner":
		found = owner.find_child(path, true, false)
	else:
		if scene != null:
			found = scene if str(scene.name) == path else scene.find_child(path, true, false)
		if found == null and scope == "tree": found = tree.root.find_child(path, true, false)
	return found if is_instance_valid(found) and not found.is_queued_for_deletion() else null

static func first_of_type(owner: Node, type: String) -> Node:
	if not is_instance_valid(owner) or owner.is_queued_for_deletion(): return null
	if owner.is_class(type): return owner
	for child in owner.get_children():
		var found := first_of_type(child, type)
		if found != null: return found
	return null

static func animation_player(owner: Node, animation: StringName) -> AnimationPlayer:
	if not is_instance_valid(owner) or owner.is_queued_for_deletion(): return null
	if owner is AnimationPlayer and owner.has_animation(animation): return owner
	for child in owner.get_children():
		var found := animation_player(child, animation)
		if found != null: return found
	return null
