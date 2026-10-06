@tool
extends RefCounted

## Legacy vocabulary and saved-ID migrations. New nodes declare their own metadata.
# GDBlueprints transition vocabulary.  The class/type stays native to the
# generator, while the editor presents terminology Unreal Blueprint users know.
# `godot_term` is deliberately shown under the familiar name so the plugin
# teaches the real Godot/GDScript API instead of hiding it.
const UI_OVERRIDES: Dictionary = {
    "AlwaysSensor": {
        "name": "Event Tick",
        "godot_term": "Godot/GDScript: _process(delta)",
        "aliases": ["Tick", "Event Tick", "Process", "_process"],
        "description": "Runs every rendered frame. Unreal: Event Tick. Godot: _process(delta)."
    },
    "InputMapSensor": {
        "name": "Input Action",
        "godot_term": "Godot/GDScript: Input Map / Input.is_action_*",
        "aliases": ["Enhanced Input Action", "InputAction", "Input Event", "Keyboard Input"],
        "description": "Reads a Godot Input Map action. Similar role to an Unreal Enhanced Input Action event."
    },
    "DelaySensor": {
        "name": "Timer Event",
        "godot_term": "Godot/GDScript: elapsed delta / SceneTreeTimer",
        "aliases": ["Delay", "Wait", "Timer"],
        "description": "Starts a timer when its chain is evaluated, then activates for the configured duration. Zero duration fires for one update. This event has no incoming execution pin."
    },
    "Controller": {
        "name": "Combine Conditions",
        "godot_term": "GDScript: boolean AND / OR / NAND / NOR / XOR",
        "aliases": ["AND", "OR", "NAND", "NOR", "XOR", "Combine Conditions"],
        "description": "Combines event conditions using AND, OR, NAND, NOR, or XOR. Use Branch for separate True and False execution paths."
    },
    "TransformsActuator": {
        "name": "Set Actor Transform",
        "godot_term": "Godot: position / rotation / scale on Node2D or Node3D",
        "aliases": ["Set Actor Transform", "Set Transform", "Set World Transform", "Player Transform"],
        "description": "Sets position, rotation and scale. Its variable rows accept value-pin connections in GDBlueprints."
    },
    "VariableSensor": {
        "name": "Branch Condition / Compare",
        "godot_term": "GDScript: ==, !=, <, <=, >, >=",
        "aliases": ["Compare", "Branch Condition", "Equal", "Greater", "Less"],
        "description": "Compares a GDBlueprints variable and produces a boolean condition."
    },
    "VariableActuator": {
        "name": "Set Variable",
        "godot_term": "GDScript: variable = value",
        "aliases": ["Set Variable", "Set", "Assign Variable"],
        "description": "Changes a local or global variable."
    },
    "GetVariableActuator": {
        "name": "Get Variable",
        "godot_term": "GDScript: read variable value",
        "aliases": ["Get Variable", "Read Variable"],
        "description": "Reads a variable into another value supported by the generated graph."
    },
    "SceneActuator": {
        "name": "Open Level / Restart Level",
        "godot_term": "Godot: SceneTree.change_scene_to_file()",
        "aliases": ["Open Level", "Load Level", "Change Level", "Restart Level", "Change Scene"],
        "description": "Changes or restarts the current Godot scene. Unreal users know this as Open Level."
    },
    "VisibilityActuator": {
        "name": "Set Visibility",
        "godot_term": "Godot: CanvasItem/Node3D.visible",
        "aliases": ["Set Visibility", "Toggle Visibility", "Show", "Hide"],
        "description": "Shows, hides, or toggles a Godot node."
    },
    "PositionActuator": {
        "name": "Set Actor Location (3D)",
        "godot_term": "Godot: Node3D.global_position / position",
        "aliases": ["Set Actor Location", "Set World Location", "Set Location", "Set Position"],
        "description": "Moves a Node3D. Unreal Actor Location maps most closely to Node3D.global_position."
    },
    "Position2DActuator": {
        "name": "Set Actor Location (2D)",
        "godot_term": "Godot: Node2D.global_position / position",
        "aliases": ["Set Actor Location 2D", "Set World Location 2D", "Set Position 2D"],
        "description": "Moves a Node2D using Godot position/global_position."
    },
    "RotationActuator": {
        "name": "Set Actor Rotation (3D)",
        "godot_term": "Godot: Node3D.rotation / rotation_degrees",
        "aliases": ["Set Actor Rotation", "Set World Rotation", "Set Rotation"],
        "description": "Sets Node3D rotation."
    },
    "Rotation2DActuator": {
        "name": "Set Actor Rotation (2D)",
        "godot_term": "Godot: Node2D.rotation / rotation_degrees",
        "aliases": ["Set Actor Rotation 2D", "Set Rotation 2D"],
        "description": "Sets Node2D rotation."
    },
    "ScaleActuator": {
        "name": "Set Actor Scale (3D)",
        "godot_term": "Godot: Node3D.scale",
        "aliases": ["Set Actor Scale", "Set World Scale", "Set Scale"],
        "description": "Sets Node3D scale."
    },
    "EditObjectActuator": {
        "name": "Spawn / Destroy Actor",
        "godot_term": "Godot: PackedScene.instantiate() / Node.queue_free()",
        "aliases": ["Spawn Actor From Class", "Spawn Actor", "Destroy Actor", "Instantiate Scene", "Queue Free"],
        "description": "Creates or removes Godot nodes. PackedScene.instantiate() is the closest Godot equivalent to Spawn Actor From Class."
    },
    "RaycastSensor": {
        "name": "Line Trace (3D)",
        "godot_term": "Godot: PhysicsRayQueryParameters3D / ray query",
        "aliases": ["Line Trace", "Line Trace By Channel", "Raycast", "Ray Cast"],
        "description": "Performs a 3D ray query. Unreal calls this family of operations Line Trace."
    },
    "Raycast2DSensor": {
        "name": "Line Trace (2D)",
        "godot_term": "Godot: PhysicsRayQueryParameters2D / ray query",
        "aliases": ["Line Trace 2D", "Raycast 2D", "Ray Cast 2D"],
        "description": "Performs a 2D ray query."
    },
    "AnimationActuator": {
        "name": "Play Animation",
        "godot_term": "Godot: AnimationPlayer.play()",
        "aliases": ["Play Animation", "Animation", "Montage"],
        "description": "Controls a Godot AnimationPlayer."
    },
    "AnimationTreeActuator": {
        "name": "Animation Blueprint Parameters",
        "godot_term": "Godot: AnimationTree parameters",
        "aliases": ["Animation Blueprint", "Anim Blueprint", "Animation State Machine", "Animation Tree"],
        "description": "Controls Godot AnimationTree parameters and playback."
    },
    "MessageActuator": {
        "name": "Send Message",
        "godot_term": "SceneTree listener group / generated message handler",
        "aliases": ["Event Dispatcher", "Call Dispatcher", "Emit Signal", "Broadcast"],
        "description": "Sends a subject and body through the GDBlueprints message listener group. For native Godot signals, use Emit Signal."
    },
    "MessageSensor": {
        "name": "Message Received",
        "godot_term": "SceneTree listener group / generated message handler",
        "aliases": ["Event Dispatcher Event", "Bind Event", "Signal Event", "Receive Message"],
        "description": "Receives a subject/body message from Send Message. This is separate from native Godot signals."
    },
    "ForceActuator": {
        "name": "Add Force",
        "godot_term": "Godot: RigidBody3D.apply_force()",
        "aliases": ["Add Force", "Apply Force"],
        "description": "Applies force to a RigidBody3D."
    },
    "ImpulseActuator": {
        "name": "Add Impulse",
        "godot_term": "Godot: RigidBody3D.apply_impulse()",
        "aliases": ["Add Impulse", "Apply Impulse"],
        "description": "Applies an impulse to a RigidBody3D."
    },
    "SetCameraActuator": {
        "name": "Set View Target / Active Camera",
        "godot_term": "Godot: Camera3D.current",
        "aliases": ["Set View Target", "Set View Target with Blend", "Set Camera", "Active Camera"],
        "description": "Makes a Godot Camera3D active."
    },
}

const ALIASES: Dictionary = {
	# Legacy 2D shared bricks now resolve to the common implementation.
	"Always2DSensor": "AlwaysSensor",
	"Delay2DSensor": "DelaySensor",
	"InputMap2DSensor": "InputMapSensor",
	"Message2DSensor": "MessageSensor",
	"Mouse2DSensor": "MouseSensor",
	"Mouse2DActuator": "Mouse2DActuator",
	"Random2DSensor": "RandomSensor",
	"Variable2DSensor": "VariableSensor",
	"Animation2DActuator": "SpriteAnimation2DActuator",
	"Audio2D2DActuator": "Audio2DActuator",
	"Game2DActuator": "GameActuator",
	"HitStop2DActuator": "HitStopActuator",
	"Message2DActuator": "MessageActuator",
	"Modulate2DActuator": "ModulateActuator",
	"Music2DActuator": "MusicActuator",
	"Preload2DActuator": "PreloadActuator",
	"Property2DActuator": "PropertyActuator",
	"Random2DActuator": "RandomActuator",
	"Rumble2DActuator": "RumbleActuator",
	"Scene2DActuator": "SceneActuator",
	"ScreenFlash2DActuator": "ScreenFlashActuator",
	"State2DActuator": "StateActuator",
	"TweenAnimation2DActuator": "Tween2DActuator",
	"Tween2DActuator": "Tween2DActuator",
	"Variable2DActuator": "VariableActuator",
	"Visibility2DActuator": "VisibilityActuator",
	# UI Button was briefly serialized from its file name before UI bricks
	# were taught to serialize with their registry class name.
	"ButtonSensor": "UIButtonSensor",
	# UI actuator files serialize from their file names unless the base class
	# uses get_brick_info(). Keep these aliases so saved scenes and metadata
	# written as FocusActuator/ButtonActuator/etc. resolve correctly.
	"FocusActuator": "UIFocusActuator",
	"ButtonActuator": "UIButtonActuator",
	"PopupActuator": "UIPopupActuator",
	"ScrollActuator": "UIScrollActuator",
	"TabActuator": "UITabActuator",
	"SliderActuator": "UISliderActuator",
	"WindowActuator": "UIWindowActuator",
	"ANDController": "Controller",
	"LocationActuator": "MotionActuator",
	# Ghost classes produced by panel_script_rebuild_helper pattern detection.
	# These bricks no longer exist; map to the nearest current equivalent so that
	# "Rebuild from Script" does not write unresolvable class names into metadata.
	"CameraActuator": "SetCameraActuator",
	"Set2DCameraActuator": "SetCamera2DActuator",
	"ShaderParamActuator": "PropertyActuator",
	"SaveGameActuator": "SaveLoadActuator",
}

const CATEGORIES: Dictionary = {
	"MotionActuator": "Motion", "CharacterActuator": "Motion", "JumpActuator": "Motion", "PositionActuator": "Motion", "RotationActuator": "Motion", "ScaleActuator": "Motion",
	"LookAtMovementActuator": "Motion", "LookAtInputActuator": "Motion", "RotateTowardsActuator": "Motion",
	"WaypointPathActuator": "Motion", "MoveTowardsActuator": "Motion", "TeleportActuator": "Motion",
	"MouseActuator": "Motion", "Mouse2DActuator": "Motion",
	"PhysicsActuator": "Physics", "ForceActuator": "Physics", "GravityActuator": "Physics",
	"TorqueActuator": "Physics", "LinearVelocityActuator": "Physics", "ImpulseActuator": "Physics",
	"CollisionActuator": "Physics", "EditObjectActuator": "Object", "ObjectPoolActuator": "Object",
	"ParentActuator": "Object", "PropertyActuator": "Object", "GetTransformsActuator": "Object", "TransformsActuator": "Object", "VisibilityActuator": "Object",
	"EnvironmentActuator": "Environment", "LightActuator": "Environment", "SetCameraActuator": "Camera",
	"SmoothFollowCameraActuator": "Camera", "CameraZoomActuator": "Camera", "ThirdPersonCameraActuator": "Camera",
	"SetCamera2DActuator": "Camera", "SmoothFollowCamera2DActuator": "Camera", "CameraZoom2DActuator": "Camera",
	"SplitScreenActuator": "Camera", "SoundActuator": "Audio", "Audio2DActuator": "Audio",
	"MusicActuator": "Audio", "ScreenFlashActuator": "Game Feel", "ScreenShakeActuator": "Game Feel",
	"ObjectFlashActuator": "Game Feel", "ObjectShakeActuator": "Game Feel", "HitStopActuator": "Game Feel",
	"RumbleActuator": "Game Feel", "TextActuator": "UI", "ModulateActuator": "UI",
	"ProgressBarActuator": "UI", "TweenActuator": "UI", "StateActuator": "Logic",
	"RandomActuator": "Logic", "MessageActuator": "Logic", "VariableActuator": "Logic",
	"GameActuator": "Game", "SceneActuator": "Game", "SaveLoadActuator": "Game", "PreloadActuator": "Game",
	"AnimationActuator": "Animation", "AnimationTreeActuator": "Animation", "SpriteFramesActuator": "Animation", "SpriteAnimation2DActuator": "Animation", "TweenAnimation2DActuator": "Animation"
}

