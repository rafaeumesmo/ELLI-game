@tool
extends Node2D
## Pedra de cristal decorativa: brilha e joga uma luz suave pra ajudar a iluminar
## o mapa. NÃO tem colisão -- o player passa por trás dela.
##
## Uso: arraste `PedraCristal.tscn` pro mapa, escolha o cristal em `pedra` (0..8) e
## ajuste `cor` / `energia` / `raio` da luz no Inspector. Com `pedra = -1` cada
## instância sorteia um cristal ao rodar o jogo.

const TOTAL_PEDRAS := 9

## Qual cristal do spritesheet (0..8). -1 = sorteia um quando o jogo roda.
@export_range(-1, 8) var pedra: int = -1:
	set(v):
		pedra = v
		_aplicar()
## Cor do brilho (a luz e um leve tint no próprio cristal).
@export var cor: Color = Color(0.55, 0.85, 1.0):
	set(v):
		cor = v
		_aplicar()
## Intensidade da luz.
@export_range(0.0, 4.0, 0.05) var energia: float = 0.8:
	set(v):
		energia = v
		_aplicar()
## Tamanho do halo de luz.
@export_range(0.1, 3.0, 0.05) var raio: float = 0.65:
	set(v):
		raio = v
		_aplicar()
## A luz "respira" de leve (cristal cintilando). Desligue pra luz fixa.
@export var cintila: bool = true
## Renderiza na frente do player (o personagem passa por trás). Desligue pra usar
## como cenário de fundo (atrás de tudo).
@export var na_frente: bool = true:
	set(v):
		na_frente = v
		_aplicar()

@onready var _spr: Sprite2D = $Cristal
@onready var _luz: PointLight2D = $Luz

var _t := 0.0
var _energia_base := 0.8

func _ready() -> void:
	if pedra < 0 and not Engine.is_editor_hint():
		pedra = randi() % TOTAL_PEDRAS
	_aplicar()

func _aplicar() -> void:
	var spr: Sprite2D = _spr if _spr != null else get_node_or_null("Cristal")
	var luz: PointLight2D = _luz if _luz != null else get_node_or_null("Luz")
	if spr == null or luz == null:
		return
	spr.hframes = TOTAL_PEDRAS
	spr.frame = clampi(pedra, 0, TOTAL_PEDRAS - 1)
	spr.modulate = Color.WHITE.lerp(cor, 0.22)
	luz.color = cor
	luz.energy = energia
	luz.texture_scale = raio
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	_energia_base = energia
	z_index = 5 if na_frente else -10

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not cintila or _luz == null:
		return
	_t += delta
	_luz.energy = _energia_base * (0.86 + 0.14 * sin(_t * 2.3))
