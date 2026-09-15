extends CharacterBody2D

@export var roll_speed: float = 360.0
@export var damage: int = 1
@export var max_health: int = 2
@export var stun_time: float = 1.5
@export var stomp_bounce: float = 260.0
## Tremor de tela quando o tatu bate numa parede rolando.
@export var wall_shake_strength: float = 6.0
@export var wall_shake_duration: float = 0.25
## Margem (px) alem da borda da tela: so treme se o tatu estiver visivel.
@export var wall_shake_margin: float = 96.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var killzone: Area2D = $Killzone
@onready var activation_zone: Area2D = $ActivationZone
@onready var head: Area2D = $Head

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var health: int = max_health
var rolling: bool = false
var roll_dir: float = 0.0
var facing: String = "A"
var stun_timer: float = 0.0
var _killzone_hit: bool = false

static var _death_particle_texture: ImageTexture

func _ready() -> void:
	add_to_group("enemy")
	sprite.play("idle_" + facing)
	activation_zone.body_entered.connect(_on_activation_body_entered)
	killzone.body_entered.connect(_on_killzone_body_entered)
	killzone.body_exited.connect(_on_killzone_body_exited)
	head.body_entered.connect(_on_head_body_entered)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is CollisionObject2D:
		# The player shares the "parede" collision bit with walls, so without
		# this exception Tatuazul's own move_and_slide fights the player
		# physically every frame they overlap, which can punch both through
		# the floor. Standing on him is simulated by the Head area instead.
		add_collision_exception_with(player)

func take_damage(amount: int) -> bool:
	# Rolando ele está blindado — o golpe não conta.
	if rolling:
		return false
	health = max(health - amount, 0)
	_play_damage_flash()
	if health <= 0:
		die()
	return true

func die() -> void:
	_spawn_death_particles()
	queue_free()

func _spawn_death_particles() -> void:
	if _death_particle_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		_death_particle_texture = ImageTexture.create_from_image(image)

	var particles := CPUParticles2D.new()
	particles.texture = _death_particle_texture
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.7
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = Color(0.3, 0.55, 0.9)

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = true

	var timer := get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(particles.queue_free)

func _play_damage_flash() -> void:
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(sprite, "modulate", Color(1, 0.25, 0.25), 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _on_activation_body_entered(body: Node) -> void:
	if rolling or stun_timer > 0.0 or not body.is_in_group("player"):
		return
	roll_dir = signf(body.global_position.x - global_position.x)
	if roll_dir == 0.0:
		return
	facing = "D" if roll_dir > 0.0 else "A"
	rolling = true
	_killzone_hit = false

func _on_killzone_body_entered(body: Node) -> void:
	if not rolling or _killzone_hit:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_killzone_hit = true

func _on_killzone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_killzone_hit = false

func _on_head_body_entered(body: Node) -> void:
	if rolling or not body.is_in_group("player"):
		return
	take_damage(1)
	if body is CharacterBody2D:
		body.velocity.y = -stomp_bounce

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer <= 0.0:
			roll_dir = -roll_dir
			facing = "D" if roll_dir > 0.0 else "A"
			rolling = true
			_killzone_hit = false

	if rolling:
		velocity.x = roll_dir * roll_speed
		sprite.play("roll_" + facing)
	else:
		velocity.x = 0.0
		sprite.play("idle_" + facing)

	move_and_slide()

	if rolling and is_on_wall():
		rolling = false
		stun_timer = stun_time
		velocity.x = 0.0
		_shake_camera()

func _shake_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not _visible_on_camera(cam):
		return
	var steps := 6
	var tween := create_tween()
	for i in steps:
		var off := Vector2(
			randf_range(-wall_shake_strength, wall_shake_strength),
			randf_range(-wall_shake_strength, wall_shake_strength)
		)
		tween.tween_property(cam, "offset", off, wall_shake_duration / steps)
	tween.tween_property(cam, "offset", Vector2.ZERO, wall_shake_duration / steps)

func _visible_on_camera(cam: Camera2D) -> bool:
	var view_size := get_viewport_rect().size / cam.zoom
	var view_rect := Rect2(cam.get_screen_center_position() - view_size * 0.5, view_size)
	return view_rect.grow(wall_shake_margin).has_point(global_position)
