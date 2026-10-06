extends RefCounted
const Targets = preload("res://addons/GDBlueprints/core/node_targets.gd")

static func execute(owner: Node, animation: StringName, mode: String, speed: float, blend: float, backwards: bool, from_end: bool, target: Variant = "") -> bool:
	if not is_finite(speed) or not is_finite(blend): return false
	var player: AnimationPlayer
	if target is String and target.is_empty():
		player = Targets.animation_player(owner, animation)
	else:
		player = Targets.resolve(owner, target, "tree") as AnimationPlayer
	if player == null or not player.has_animation(animation):
		push_warning("Animation: no matching AnimationPlayer/animation; specify a player reference or path.")
		return false
	match mode:
		"play":
			# Apply speed exactly once; stale speed_scale must not multiply it again.
			player.speed_scale = 1.0
			player.play(animation, blend, -absf(speed) if backwards else speed, from_end or backwards)
		"pause": player.pause()
		"stop": player.stop()
		"queue":
			player.speed_scale = speed
			player.queue(animation)
		_: return false
	return true
