extends RefCounted
## Small, direct-reference operations shared by generated graphs and GDScript.
## These helpers never search the scene tree or alter project input settings.

static func input_vector(left: StringName, right: StringName, up: StringName, down: StringName, deadzone: float = -1.0) -> Vector2:
	for action in [left, right, up, down]:
		if not InputMap.has_action(action): return Vector2.ZERO
	return Input.get_vector(left, right, up, down, clampf(deadzone, -1.0, 1.0))

static func move_2d(body: Variant, velocity: Vector2) -> bool:
	if not velocity.is_finite(): return false
	if typeof(body) != TYPE_OBJECT or not is_instance_valid(body) or not body is CharacterBody2D or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	body.velocity = velocity
	body.move_and_slide()
	return true

static func move_3d(body: Variant, velocity: Vector3) -> bool:
	if not velocity.is_finite(): return false
	if typeof(body) != TYPE_OBJECT or not is_instance_valid(body) or not body is CharacterBody3D or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	body.velocity = velocity
	body.move_and_slide()
	return true

static func spawn_scene(scene: Variant, parent: Variant, local_transform: Variant = null) -> Node:
	if typeof(scene) != TYPE_OBJECT or not is_instance_valid(scene) or not scene is PackedScene or not scene.can_instantiate(): return null
	if typeof(parent) != TYPE_OBJECT or not is_instance_valid(parent) or not parent is Node or not parent.is_inside_tree() or parent.is_queued_for_deletion(): return null
	var instance: Node = scene.instantiate()
	if instance == null: return null
	if local_transform != null:
		if instance is Node2D and local_transform is Transform2D: instance.transform = local_transform
		elif instance is Node3D and local_transform is Transform3D: instance.transform = local_transform
		else:
			instance.free()
			return null
	# Set the local transform before _enter_tree/_ready observe the new instance.
	parent.add_child(instance)
	if not is_instance_valid(instance): return null
	if instance.get_parent() != parent or instance.is_queued_for_deletion(): return null
	return instance

static func destroy_node(target: Variant) -> bool:
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target) or not target is Node or target.is_queued_for_deletion(): return false
	target.queue_free()
	return true

static func overlapping_bodies(area: Variant) -> Array[Node]:
	var bodies: Array[Node] = []
	if typeof(area) != TYPE_OBJECT or not is_instance_valid(area) or not area is Node or not area.is_inside_tree() or area.is_queued_for_deletion(): return bodies
	if area is Area2D or area is Area3D:
		for body in area.get_overlapping_bodies(): bodies.append(body)
	return bodies
