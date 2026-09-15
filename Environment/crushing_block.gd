extends AnimatableBody2D

@export var move_offset: Vector2 = Vector2(0, 64)
@export var move_time: float = 1.2
@export var pause_time: float = 0.5

@onready var killzone: Area2D = $Killzone

var _base_pos: Vector2

func _ready() -> void:
	_base_pos = position
	killzone.body_entered.connect(_on_body_entered)
	_start_loop()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(body.max_health)

func _start_loop() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position", _base_pos + move_offset, move_time)
	tween.tween_interval(pause_time)
	tween.tween_property(self, "position", _base_pos, move_time)
	tween.tween_interval(pause_time)
