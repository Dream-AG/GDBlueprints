@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

## Sprite Animation 2D Actuator - Play, stop, or pause AnimatedSprite2D animations.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Sprite Animation"

func get_brick_info() -> Dictionary:
	return {"godot_term": "AnimatedSprite2D.play() / stop() / pause()", 
		"class": "SpriteAnimation2DActuator",
		"name": "Sprite Animation",
		"type": "actuator",
		"category": "Animation",
		"description": "Play, stop, or pause AnimatedSprite2D animations.",
		"menu_order": 300,
		"domain": "2d",
	}

func _initialize_properties() -> void:
	properties = {
		"mode": "play",
		"animation_name": "",
		"speed_scale": "1.0",
		"target_node": "",
	}

func get_property_definitions() -> Array:
	return [
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Play,Stop,Pause", "default": "play"},
		{"name": "animation_name", "type": TYPE_STRING, "hint": PROPERTY_HINT_NONE, "default": ""},
		{"name": "speed_scale", "type": TYPE_STRING, "default": "1.0"},
		{"name": "target_node", "type": TYPE_STRING, "hint": PROPERTY_HINT_NONE, "default": ""},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play, stop, or pause AnimatedSprite2D animations. Leave Target Node empty to use the node this script is on.",
		"mode": "Play: start or resume the animation.\nStop: stop playback and reset.\nPause: freeze at the current frame.",
		"animation_name": "Name of the animation in the AnimatedSprite2D SpriteFrames resource. Leave blank to play the default/current animation.",
		"speed_scale": "Playback speed multiplier. Accepts a number, variable, or expression.",
		"target_node": "Name of the AnimatedSprite2D node to control. Leave empty to target self.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = str(properties.get("mode", "play")).to_lower()
	var anim_name = str(properties.get("animation_name", ""))
	var speed_raw = properties.get("speed_scale", "1.0")
	var target_name = str(properties.get("target_node", "")).strip_edges()
	var speed_expr = _speed_to_expr(speed_raw)
	var label = _safe_label(chain_name)
	var sprite_var = "_sprite_anim_2d_%s" % label

	var member_vars: Array[String] = []

	var code_lines: Array[String] = []
	if target_name.is_empty():
		code_lines.append("# Sprite Animation 2D Actuator: target is self")
		code_lines.append("var %s = preload(\"res://addons/GDBlueprints/core/node_targets.gd\").first_of_type(self, \"AnimatedSprite2D\") as AnimatedSprite2D" % sprite_var)
	else:
		code_lines.append("# Sprite Animation 2D Actuator: find '%s'" % _gd_string(target_name))
		code_lines.append("var %s = preload(\"res://addons/GDBlueprints/core/node_targets.gd\").resolve(self, \"%s\", \"tree\") as AnimatedSprite2D" % [sprite_var, _gd_string(target_name)])

	code_lines.append("if %s:" % sprite_var)
	match mode:
		"stop":
			code_lines.append("\t%s.stop()" % sprite_var)
		"pause":
			code_lines.append("\t%s.pause()" % sprite_var)
		_:
			code_lines.append("\t%s.speed_scale = %s" % [sprite_var, speed_expr])
			if anim_name.strip_edges().is_empty():
				code_lines.append("\t%s.play()" % sprite_var)
			else:
				code_lines.append("\t%s.play(\"%s\")" % [sprite_var, _gd_string(anim_name)])
	code_lines.append("else:")
	if target_name.is_empty():
		code_lines.append("\tpush_warning(\"Sprite Animation 2D Actuator: self is not AnimatedSprite2D. Set Target Node to an AnimatedSprite2D name.\")")
	else:
		code_lines.append("\tpush_warning(\"Sprite Animation 2D Actuator: Could not find AnimatedSprite2D named '%s'\")" % _gd_string(target_name))

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}

func _speed_to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty():
		return "1.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s

func _safe_label(chain_name: String) -> String:
	var label = chain_name.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else "sprite_animation_2d"

