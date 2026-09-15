extends Area2D

## Serra fixa: gira sem parar, mas nunca sai do lugar. Mata a qualquer contato,
## igual ao MovingSaw e ao RotatingSawTrap -- so que essa fica parada, servindo
## de obstaculo puro num canto, parede ou vao.

## Velocidade de rotacao da lamina (radianos por segundo), sempre girando.
@export var spin_speed: float = 10.0

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	visual.rotation += spin_speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(body.max_health)
	elif body.is_in_group("enemy") and body.has_method("die"):
		body.die()
