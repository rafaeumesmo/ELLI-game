extends CharacterBody2D

@export var chase_speed: float = 230.0
@export var fall_delay: float = 1.0
@export var radius: float = 10.0:
	set(value):
		radius = value
		_apply_radius()

@onready var visual: Polygon2D = $Visual
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var activation_zone: Area2D = $ActivationZone
@onready var killzone: Area2D = $Killzone

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var target: Node2D = null
var falling: bool = false
var chasing: bool = false
var deactivated: bool = false
var roll_dir: float = 1.0
var was_climbing: bool = false

func _ready() -> void:
	_apply_radius()
	activation_zone.body_entered.connect(_on_activation_body_entered)
	killzone.body_entered.connect(_on_killzone_body_entered)

func deactivate() -> void:
	if deactivated:
		return
	deactivated = true
	falling = false
	chasing = false
	killzone.set_deferred("monitoring", false)
	collision_layer = 2

func _apply_radius() -> void:
	if not is_node_ready():
		return
	body_shape.shape.radius = radius
	visual.scale = Vector2.ONE * (radius / 16.0)

func _on_activation_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	target = body
	activation_zone.set_deferred("monitoring", false)
	await get_tree().create_timer(fall_delay).timeout
	falling = true

func _on_killzone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(body.max_health)

func _physics_process(delta: float) -> void:
	if deactivated:
		if not is_on_floor():
			velocity.y += gravity * delta
			velocity.x = 0.0
			move_and_slide()
		return

	if falling:
		velocity.y += gravity * delta
		velocity.x = 0.0
		move_and_slide()
		if is_on_floor():
			falling = false
			chasing = true
			roll_dir = _dir_to_target()
		_spin(delta)
		return

	if chasing and target:
		_chase(delta)
		_spin(delta)

func _dir_to_target() -> float:
	var dir: float = signf(target.global_position.x - global_position.x)
	return dir if dir != 0.0 else roll_dir

func _chase(delta: float) -> void:
	var climbing: bool = is_on_wall() and target.global_position.y < global_position.y - 4.0

	if climbing:
		velocity.y = -chase_speed
		velocity.x = roll_dir * 10.0
		was_climbing = true
	else:
		if was_climbing:
			roll_dir = _dir_to_target()
			was_climbing = false
		elif is_on_wall():
			roll_dir = _dir_to_target()

		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		velocity.x = roll_dir * chase_speed

	move_and_slide()

func _spin(delta: float) -> void:
	if velocity.length() < 0.1:
		return
	var spin_speed: float = velocity.x if absf(velocity.x) > 1.0 else velocity.length()
	visual.rotation += (spin_speed / radius) * delta
