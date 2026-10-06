extends "res://addons/GDBlueprints/examples/gameplay/game_base.gd"

# === GDBLUEPRINTS START ===
# GDBlueprints generated SHA256: b985aaa3fd5ed39e6605ddc9b25b5b42e1483ab2c070026ea4bab8b150eb97c8
func _ready() -> void:
	if not tree_exiting.is_connected(_gdb_cancel_execution): tree_exiting.connect(_gdb_cancel_execution)

func _physics_process(delta: float) -> void:
	_blueprint_exec_tick(delta)

func start_round() -> void:
	var _gdb_previous_meter := _gdb_dispatch_meter
	var _flow := _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter)
	_flow.event_arguments["start_round"] = {}
	_gdb_dispatch_meter = _flow.meter
	_blueprint_exec_start_round(0.0, _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter, _flow.event_arguments))
	_gdb_dispatch_meter = _gdb_previous_meter

func pickup(body: Node) -> void:
	if not _GDBFunctions.accepts(body, "Node"):
		push_warning("GDBlueprints: event argument does not match its declared type.")
		return
	var _gdb_previous_meter := _gdb_dispatch_meter
	var _flow := _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter)
	_flow.event_arguments["pickup"] = {"body": body}
	_gdb_dispatch_meter = _flow.meter
	_blueprint_exec_pickup(0.0, _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter, _flow.event_arguments))
	_gdb_dispatch_meter = _gdb_previous_meter

func damage(body: Node) -> void:
	if not _GDBFunctions.accepts(body, "Node"):
		push_warning("GDBlueprints: event argument does not match its declared type.")
		return
	var _gdb_previous_meter := _gdb_dispatch_meter
	var _flow := _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter)
	_flow.event_arguments["damage"] = {"body": body}
	_gdb_dispatch_meter = _flow.meter
	_blueprint_exec_damage(0.0, _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter, _flow.event_arguments))
	_gdb_dispatch_meter = _gdb_previous_meter

func reach_goal(body: Node) -> void:
	if not _GDBFunctions.accepts(body, "Node"):
		push_warning("GDBlueprints: event argument does not match its declared type.")
		return
	var _gdb_previous_meter := _gdb_dispatch_meter
	var _flow := _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter)
	_flow.event_arguments["reach_goal"] = {"body": body}
	_gdb_dispatch_meter = _flow.meter
	_blueprint_exec_reach_goal(0.0, _GDBFlow.context(_gdb_execution_epoch, _gdb_dispatch_meter, _flow.event_arguments))
	_gdb_dispatch_meter = _gdb_previous_meter

func _blueprint_exec_tick(_delta: float, _flow: Dictionary = {}) -> void:
	# Sensor and controller input evaluation
	var sensor_0_active = false
	sensor_0_active = true
	
	# Controller logic
	var controller_active = sensor_0_active
	if controller_active:
		if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_76656c6f63697479("in", _delta, _flow)
		pass

func _blueprint_exec_start_round(_delta: float, _flow: Dictionary = {}) -> void:
	# Sensor and controller input evaluation
	var sensor_0_active = false
	sensor_0_active = true
	
	# Controller logic
	var controller_active = sensor_0_active
	if controller_active:
		if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_737061776e5f6c6f6f70("in", _delta, _flow)
		pass

func _blueprint_exec_pickup(_delta: float, _flow: Dictionary = {}) -> void:
	# Sensor and controller input evaluation
	var sensor_0_active = false
	sensor_0_active = true
	
	# Controller logic
	var controller_active = sensor_0_active
	if controller_active:
		if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_76616c69645f7069636b7570("in", _delta, _flow)
		pass

func _blueprint_exec_damage(_delta: float, _flow: Dictionary = {}) -> void:
	# Sensor and controller input evaluation
	var sensor_0_active = false
	sensor_0_active = true
	
	# Controller logic
	var controller_active = sensor_0_active
	if controller_active:
		if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_68757274("in", _delta, _flow)
		pass

func _blueprint_exec_reach_goal(_delta: float, _flow: Dictionary = {}) -> void:
	# Sensor and controller input evaluation
	var sensor_0_active = false
	sensor_0_active = true
	
	# Controller logic
	var controller_active = sensor_0_active
	if controller_active:
		if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_756e6c6f636b6564("in", _delta, _flow)
		pass


const _GDBFlow = preload("res://addons/GDBlueprints/core/execution_runtime.gd")
const _GDBFunctions = preload("res://addons/GDBlueprints/core/function_runtime.gd")
const _GDBDebugSnapshot = preload("res://addons/GDBlueprints/core/debug_snapshot.gd")
var _gdb_execution_epoch: int = 0
var _gdb_dispatch_meter: Dictionary = {}
func _gdb_cancel_execution() -> void:
	_gdb_execution_epoch += 1

func _gdb_exec_76656c6f63697479(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "velocity"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "velocity", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_76656c6f63697479_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_76656c6f63697479_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values.erase("velocity")
	var result := _GDBFunctions.invoke(self, "desired_2d", [preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").input_vector("ui_left", "ui_right", "ui_up", "ui_down", -1.0), _delta], "Vector2", _flow.meter)
	if bool(result.get("ok", false)):
		_flow.values["velocity"] = result
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_6d6f7665("in", _delta, _flow)
	else:
		pass
	pass

func _gdb_exec_6d6f7665(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "move"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "move", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_6d6f7665_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_6d6f7665_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").move_2d($Player, _flow.values["velocity"]["result"])
	if _GDBFlow.stopped(self, _flow): return
	await _gdb_exec_636f6c6c656374("in", _delta, _flow)
	pass

func _gdb_exec_636f6c6c656374(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "collect"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "collect", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_636f6c6c656374_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_636f6c6c656374_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values.erase("collect")
	var result := _GDBFunctions.invoke(self, "collect_bodies", [preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").overlapping_bodies($Player/Detector)], "void", _flow.meter)
	if bool(result.get("ok", false)):
		_flow.values["collect"] = result
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_687564("in", _delta, _flow)
	else:
		pass
	pass

func _gdb_exec_687564(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "hud"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "hud", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_687564_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_687564_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values.erase("hud")
	var result := _GDBFunctions.invoke(self, "update_hud", [], "void", _flow.meter)
	if bool(result.get("ok", false)):
		_flow.values["hud"] = result
	else:
		pass
	pass

func _gdb_exec_737061776e5f6c6f6f70(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "spawn_loop"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "spawn_loop", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_737061776e5f6c6f6f70_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_737061776e5f6c6f6f70_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	var source = spawn_transforms
	if not source is Array:
		_flow.cancelled = true
		push_error("GDBlueprints: For Each requires an Array.")
		return
	var items: Array = source.duplicate()
	var index := 0
	var frame := {"control":""}
	_flow.loops.append(frame)
	var previous_value = _flow.values.get("spawn_loop")
	while index < items.size():
		if not _GDBFlow.enter(self, _flow, "spawn_loop"): break
		_flow.meter.depth -= 1
		frame.control = ""
		_flow.values["spawn_loop"] = {"index":index,"item":items[index]}
		await _gdb_exec_737061776e5f6c6f6f70_loop_body(_delta, _flow)
		if _flow.returned or not _GDBFlow.valid(self, _flow) or frame.control == "break": break
		index += 1
	_flow.loops.pop_back()
	if previous_value == null: _flow.values.erase("spawn_loop")
	else: _flow.values["spawn_loop"] = previous_value
	if _GDBFlow.stopped(self, _flow): return
	await _gdb_exec_687564("in", _delta, _flow)
func _gdb_exec_737061776e5f6c6f6f70_loop_body(_delta: float, _flow: Dictionary) -> void:
	if _GDBFlow.stopped(self, _flow): return
	await _gdb_exec_737061776e("in", _delta, _flow)
	pass

func _gdb_exec_737061776e(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "spawn"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "spawn", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_737061776e_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_737061776e_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values["spawn"] = {"instance": preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").spawn_scene(pickup_scene, $Pickups, _flow.values.get("spawn_loop", {}).get("item"))}
	pass

func _gdb_exec_76616c69645f7069636b7570(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "valid_pickup"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "valid_pickup", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_76616c69645f7069636b7570_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_76616c69645f7069636b7570_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	if is_instance_valid(_flow.event_arguments["pickup"]["body"]) and not _flow.event_arguments["pickup"]["body"].is_queued_for_deletion() and _flow.event_arguments["pickup"]["body"].is_in_group("gdb_demo_pickup"):
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_73636f7265("in", _delta, _flow)
	else:
		pass
	pass

func _gdb_exec_73636f7265(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "score"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "score", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_73636f7265_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_73636f7265_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values.erase("score")
	var result := _GDBFunctions.invoke(self, "add_score", [], "void", _flow.meter)
	if bool(result.get("ok", false)):
		_flow.values["score"] = result
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_64657374726f79("in", _delta, _flow)
	else:
		pass
	pass

func _gdb_exec_64657374726f79(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "destroy"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "destroy", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_64657374726f79_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_64657374726f79_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	preload("res://addons/GDBlueprints/core/gameplay_runtime.gd").destroy_node(_flow.event_arguments["pickup"]["body"])
	pass

func _gdb_exec_68757274(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "hurt"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "hurt", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_68757274_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_68757274_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values.erase("hurt")
	var result := _GDBFunctions.invoke(self, "apply_damage", [_flow.event_arguments["damage"]["body"]], "void", _flow.meter)
	if bool(result.get("ok", false)):
		_flow.values["hurt"] = result
	else:
		pass
	pass

func _gdb_exec_756e6c6f636b6564(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "unlocked"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "unlocked", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_756e6c6f636b6564_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_756e6c6f636b6564_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	if score == 3 and health > 0 and _flow.event_arguments["reach_goal"]["body"] == player:
		if _GDBFlow.stopped(self, _flow): return
		await _gdb_exec_77696e("in", _delta, _flow)
	else:
		pass
	pass

func _gdb_exec_77696e(_entry: String = "in", _delta: float = 0.0, _flow: Dictionary = {}) -> void:
	if _flow.is_empty(): _flow = _GDBFlow.context(_gdb_execution_epoch)
	if not _GDBFlow.enter(self, _flow, "win"): return
	if has_node("/root/GDBlueprintsDebugger"): await get_node("/root/GDBlueprintsDebugger").before_node(self, "win", _entry, _flow, false)
	if _GDBFlow.valid(self, _flow): await _gdb_exec_77696e_body(_entry, _delta, _flow)
	_flow.meter.depth -= 1
func _gdb_exec_77696e_body(_entry: String, _delta: float, _flow: Dictionary) -> void:
	_flow.values.erase("win")
	var result := _GDBFunctions.invoke(self, "finish_game", [], "void", _flow.meter)
	if bool(result.get("ok", false)):
		_flow.values["win"] = result
	else:
		pass
	pass
# === GDBLUEPRINTS END ===
