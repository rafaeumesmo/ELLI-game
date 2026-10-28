extends Node2D
## Goteira decorativa em pixels: nasce no teto e respinga na primeira rocha abaixo.

@export_range(8.0, 1024.0) var altura: float = 160.0
@export_range(0.2, 8.0) var intervalo: float = 1.8
@export var fase: float = 0.0

const GRAVIDADE := 240.0
const VELOCIDADE_INICIAL := 12.0
const TEMPO_RESPINGO := 0.25
const COR_AGUA := Color(0.49, 0.68, 0.67, 0.65)
const COR_REFLEXO := Color(0.72, 0.83, 0.77, 0.8)

var _tempo: float = 0.0
var _tempo_queda: float = 0.0
var _periodo: float = 0.0

func _ready() -> void:
	_tempo_queda = (sqrt(VELOCIDADE_INICIAL * VELOCIDADE_INICIAL + 2.0 * GRAVIDADE * altura) - VELOCIDADE_INICIAL) / GRAVIDADE
	_periodo = _tempo_queda + TEMPO_RESPINGO + intervalo
	_tempo = fposmod(fase, _periodo)
	queue_redraw()

func _process(delta: float) -> void:
	_tempo = fposmod(_tempo + delta, _periodo)
	queue_redraw()

func _draw() -> void:
	var limites := Rect2(-8.0, -4.0, 16.0, altura + 8.0)
	if not get_viewport_rect().intersects(get_global_transform_with_canvas() * limites):
		return
	# Uma pequena gota se forma no teto antes de se soltar.
	if _tempo >= _tempo_queda + TEMPO_RESPINGO:
		var crescimento := (_tempo - _tempo_queda - TEMPO_RESPINGO) / intervalo
		draw_rect(Rect2(-1, 0, 2, 1 + floorf(crescimento * 2.0)), COR_AGUA)
	elif _tempo < _tempo_queda:
		var y := floorf(VELOCIDADE_INICIAL * _tempo + 0.5 * GRAVIDADE * _tempo * _tempo)
		draw_rect(Rect2(0, maxf(0.0, y - 3.0), 1, minf(3.0, y + 1.0)), COR_AGUA)
		draw_rect(Rect2(0, y, 1, 1), COR_REFLEXO)
	else:
		var t := (_tempo - _tempo_queda) / TEMPO_RESPINGO
		var distancia := floorf(1.0 + t * 6.0)
		var y := altura - 1.0 - floorf(sin(t * PI) * 4.0)
		var cor := Color(COR_REFLEXO, (1.0 - t) * COR_REFLEXO.a)
		draw_rect(Rect2(-distancia, y, 1, 1), cor)
		draw_rect(Rect2(distancia, y, 1, 1), cor)
		draw_rect(Rect2(-distancia, altura - 1.0, distancia * 2.0 + 1.0, 1), Color(COR_AGUA, (1.0 - t) * 0.25))
