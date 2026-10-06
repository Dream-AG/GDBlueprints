extends Node
## Handwritten helpers deliberately live outside generated regions.
## Open the scene root's graph to change movement, spawning and event routing.

@export_enum("2D:2", "3D:3") var dimension: int = 2
@export var speed_2d := 210.0
@export var speed_3d := 6.0
var score := 0
var health := 3
var won := false
var invulnerability := 0.0
var spawn_transforms: Array = []
var pickup_scene: PackedScene
var player: Node
var start_position: Variant

func _enter_tree() -> void:
	ready.connect(_start, CONNECT_ONE_SHOT)

func _start() -> void:
	player = get_node("Player")
	start_position = player.position
	pickup_scene = load("res://addons/GDBlueprints/examples/gameplay/pickup_%dd.tscn" % dimension)
	if dimension == 2:
		layout_2d()
		get_viewport().size_changed.connect(layout_2d)
		for point in [Vector2(260, 180), Vector2(480, 440), Vector2(720, 180)]: spawn_transforms.append(Transform2D(0.0, point))
	else:
		for point in [Vector3(-5, 0.7, -3), Vector3(0, 0.7, 4), Vector3(5, 0.7, -3)]: spawn_transforms.append(Transform3D(Basis.IDENTITY, point))
	call_deferred("start_round")

func layout_2d() -> void:
	var size := get_viewport().get_visible_rect().size
	var zoom := maxf(0.1, minf((size.x - 40.0) / 900.0, (size.y - 204.0) / 502.0))
	var camera: Camera2D = get_node("DemoCamera")
	camera.zoom = Vector2(zoom, zoom)
	camera.position = Vector2(480, 299 - 78.0 / zoom)

func advance_state(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	if dimension == 3 and player.position.y < -8: apply_damage(player)

func desired_2d(input: Vector2, delta: float) -> Vector2:
	advance_state(delta)
	return input * speed_2d if not won and health > 0 else Vector2.ZERO

func desired_3d(input: Vector2, delta: float) -> Vector3:
	advance_state(delta)
	var velocity: Vector3 = player.velocity
	velocity.x = input.x * speed_3d if not won and health > 0 else 0.0
	velocity.z = input.y * speed_3d if not won and health > 0 else 0.0
	if not player.is_on_floor(): velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("ui_accept") and not won and health > 0: velocity.y = 7.0
	else: velocity.y = 0.0
	return velocity

func collect_bodies(bodies: Array[Node]) -> void:
	if won or health <= 0: return
	for body in bodies: call("pickup", body)

func add_score() -> void:
	score += 1

func apply_damage(body: Node) -> void:
	if body != player or invulnerability > 0.0 or won or health <= 0: return
	health -= 1
	invulnerability = 1.0
	player.position = start_position
	player.velocity = Vector2.ZERO if dimension == 2 else Vector3.ZERO
	update_hud()

func finish_game() -> void:
	won = true
	update_hud()

func update_hud() -> void:
	var status := "Collect all three gold pickups, then enter the green exit."
	if won: status = "You won! Restart to play again."
	elif health <= 0: status = "Out of health. Restart to try again."
	get_node("HUD/Panel/Rows/Status").text = "%s demo  |  Pickups %d / 3  |  Health %d\n%s" % ["2D" if dimension == 2 else "3D", score, health, status]

func restart() -> void:
	for child in get_node("Pickups").get_children(): child.queue_free()
	score = 0
	health = 3
	won = false
	invulnerability = 1.0
	player.position = start_position
	player.velocity = Vector2.ZERO if dimension == 2 else Vector3.ZERO
	call_deferred("start_round")
