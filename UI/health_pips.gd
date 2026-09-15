extends Control

var health: int = 4
var max_health: int = 4

const PIP_RADIUS := 8.0
const PIP_SPACING := 24.0
const COLOR_FULL := Color(0.223, 0.687, 0.228, 1.0)
const COLOR_EMPTY := Color(0.3, 0.3, 0.3, 0.6)

func _draw() -> void:
	for i in range(max_health):
		var center := Vector2(PIP_RADIUS + i * PIP_SPACING, PIP_RADIUS)
		var color := COLOR_FULL if i < health else COLOR_EMPTY
		draw_circle(center, PIP_RADIUS, color)
