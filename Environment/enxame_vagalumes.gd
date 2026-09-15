extends Node2D
## Espalha `quantidade` vagalumes dentro de um retângulo, com posições
## sorteadas de forma determinística -- a mesma `seed_enxame` gera sempre o
## mesmo enxame, então dá pra ajustar sem susto de "recompor" o mapa.
##
## Uso: arraste `EnxameVagalumes.tscn` pro mapa e ajusta `area` (espaço
## local do nó) e `quantidade`/`seed_enxame` no Inspector.

@export var quantidade: int = 6
@export var area: Rect2 = Rect2(-40.0, -30.0, 80.0, 60.0)
@export var seed_enxame: int = 0

const VAGALUME_CENA: PackedScene = preload("res://Environment/Vagalume.tscn")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_enxame
	for i in quantidade:
		var vagalume: Node2D = VAGALUME_CENA.instantiate()
		vagalume.position = Vector2(
			rng.randf_range(area.position.x, area.position.x + area.size.x),
			rng.randf_range(area.position.y, area.position.y + area.size.y)
		)
		add_child(vagalume)
