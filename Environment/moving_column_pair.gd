extends Node2D

@export var move_offset: Vector2 = Vector2(96, 0)
@export var move_time: float = 1.5
@export var pause_time: float = 0.3

@onready var column_a: AnimatableBody2D = $ColumnA
@onready var column_b: AnimatableBody2D = $ColumnB

var _base_a: Vector2
var _base_b: Vector2

func _ready() -> void:
	_base_a = column_a.position
	_base_b = column_b.position
	column_a.add_to_group("double_stick_wall")
	column_b.add_to_group("double_stick_wall")
	_start_loop()

func _start_loop() -> void:
	var tween := create_tween().set_loops()
	tween.set_parallel(true)
	tween.tween_property(column_a, "position", _base_a + move_offset, move_time)
	tween.tween_property(column_b, "position", _base_b + move_offset, move_time)
	tween.chain().tween_interval(pause_time)
	tween.set_parallel(true)
	tween.tween_property(column_a, "position", _base_a, move_time)
	tween.tween_property(column_b, "position", _base_b, move_time)
	tween.chain().tween_interval(pause_time)
