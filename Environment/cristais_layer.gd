extends TileMapLayer
## Camada de cristais decorativos. Pinte os cristais na paleta que nem os blocos --
## cada tile do atlas (0..8) é um cristal diferente do `pedras-cristal.png`.
##
## Cada célula pintada ganha automaticamente uma PointLight2D (brilho aditivo) pra
## ajudar a iluminar o mapa. NÃO tem colisão -- ponha o `z_index` desta camada
## acima do player (ex.: 5) pra o personagem passar por trás dos cristais.

## Cor do brilho de todos os cristais desta camada.
@export var cor: Color = Color(0.55, 0.85, 1.0)
## Intensidade de cada luz.
@export_range(0.0, 4.0, 0.05) var energia: float = 0.8
## Tamanho do halo (texture_scale da PointLight2D).
@export_range(0.1, 3.0, 0.05) var raio: float = 0.65
## As luzes "respiram" de leve (cristal cintilando).
@export var cintila: bool = true

const _LUZ_TEX := preload("res://Environment/luz_radial.tres")

var _luzes: Array[PointLight2D] = []
var _t := 0.0

func _ready() -> void:
	# A arte do cristal não recebe luz (senão a própria luz lava o pixel art).
	light_mask = 0
	for cell in get_used_cells():
		var luz := PointLight2D.new()
		luz.texture = _LUZ_TEX
		luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		luz.color = cor
		luz.energy = energia
		luz.texture_scale = raio
		luz.blend_mode = Light2D.BLEND_MODE_ADD
		luz.position = map_to_local(cell)
		add_child(luz)
		_luzes.append(luz)
	set_process(cintila and not _luzes.is_empty())

func _process(delta: float) -> void:
	_t += delta
	var e := energia * (0.86 + 0.14 * sin(_t * 2.3))
	for luz in _luzes:
		luz.energy = e
