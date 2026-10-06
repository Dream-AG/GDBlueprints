extends RefCounted
## One bound tween per camera; repeated shakes replace rather than accumulate.
const STATE := &"_gdblueprints_camera_shake"

static func shake_2d(camera: Variant, intensity: float, duration: float, rotation_degrees: float) -> bool:
	if not is_instance_valid(camera) or not camera is Camera2D or not camera.is_inside_tree() or camera.is_queued_for_deletion(): return false
	if not is_finite(intensity) or not is_finite(duration) or not is_finite(rotation_degrees) or duration <= 0.0: return false
	var previous: Dictionary = camera.get_meta(STATE, {})
	if not previous.is_empty():
		var active: Tween = previous.tween
		if active != null and active.is_valid(): active.kill()
		camera.offset = previous.offset
		camera.rotation = previous.rotation
	var offset: Vector2 = camera.offset
	var rotation: float = camera.rotation
	var tween: Tween = camera.create_tween()
	camera.set_meta(STATE, {"tween":tween, "offset":offset, "rotation":rotation})
	tween.tween_method(_shake_step.bind(camera, offset, rotation, absf(intensity), deg_to_rad(absf(rotation_degrees))), 0.0, 1.0, duration)
	tween.tween_callback(_finish.bind(camera, offset, rotation))
	return true

static func _shake_step(progress: float, camera: Camera2D, offset: Vector2, rotation: float, intensity: float, angle: float) -> void:
	var amplitude := 1.0 - progress
	camera.offset = offset + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * amplitude
	camera.rotation = rotation + randf_range(-angle, angle) * amplitude

static func _finish(camera: Camera2D, offset: Vector2, rotation: float) -> void:
	camera.offset = offset
	camera.rotation = rotation
	camera.remove_meta(STATE)
