extends Node2D

@export var rise_height: float = 48.0
@export var move_time: float = 0.4

@onready var platform_a: AnimatableBody2D = $PlatformA
@onready var platform_b: AnimatableBody2D = $PlatformB
@onready var trigger_a: Area2D = $PlatformA/Trigger
@onready var trigger_b: Area2D = $PlatformB/Trigger

var _base_pos_a: Vector2
var _base_pos_b: Vector2
var _riders: int = 0
var _raised: bool = false

func _ready() -> void:
	_base_pos_a = platform_a.position
	_base_pos_b = platform_b.position
	trigger_a.body_entered.connect(_on_body_entered)
	trigger_a.body_exited.connect(_on_body_exited)
	trigger_b.body_entered.connect(_on_body_entered)
	trigger_b.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_riders += 1
	if not _raised:
		_raised = true
		_move_to(_base_pos_a + Vector2(0, -rise_height), _base_pos_b + Vector2(0, -rise_height))

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_riders = max(_riders - 1, 0)
	if _riders == 0 and _raised:
		_raised = false
		_move_to(_base_pos_a, _base_pos_b)

func _move_to(pos_a: Vector2, pos_b: Vector2) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(platform_a, "position", pos_a, move_time)
	tween.tween_property(platform_b, "position", pos_b, move_time)
