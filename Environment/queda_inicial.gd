extends Node2D
## Cena de abertura, antes do tutorial: Elísio tenta pegar o vagalume, erra
## e cai no vazio. A cena escurece com ele ainda caindo (o vagalume fica lá em
## cima, virando um pontinho) e o tutorial começa com ele deitado no chão.
## Sem física nem controle: tudo é a animação "queda" do AnimationPlayer
## (frame do sprite, posições, câmera, cor do fundo, fade). As durações de cada beat são os tempos dos keys dessa animação.
##
## O AnimationPlayer roda em modo manual: este script avança ele e depois
## arredonda as posições, pra nada ficar em meio pixel.
##
## Segurar ui_accept por `tempo_pular` segundos pula a cutscene.

@export_file("*.tscn") var proxima_cena: String = "res://tutorial.tscn"
## Quanto tempo segurando ui_accept pra pular.
@export var tempo_pular: float = 1.0
## Pulso da luz do vagalume (energia base de halo/core e quanto oscila).
@export var energia_halo: float = 1.5
@export var energia_core: float = 2.6
@export var pulso_amplitude: float = 0.25
@export var pulso_velocidade: float = 2.2

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _elisio: Sprite2D = $Elisio
@onready var _vagalume: Node2D = $Vagalume
@onready var _corpo_vagalume: Sprite2D = $Vagalume/Corpo
@onready var _brilho: Sprite2D = $Vagalume/Brilho
@onready var _halo: PointLight2D = $Vagalume/Halo
@onready var _core: PointLight2D = $Vagalume/Core
@onready var _camera: Camera2D = $Camera2D
@onready var _pular: Control = $UI/Pular
@onready var _pular_barra: ColorRect = $UI/Pular/Barra

var _t: float = 0.0
var _segurando: float = 0.0
## Só conta o "segurar pra pular" depois que ui_accept foi solto uma vez --
## senão o Enter que apertou "Novo jogo" no menu já começa pulando.
var _soltou_accept: bool = false
var _acabou: bool = false
var _brilho_alpha: float

func _ready() -> void:
	_pular.modulate.a = 0.0
	_brilho_alpha = _brilho.modulate.a
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim.play("queda")
	_anim.seek(0.0, true)
	_snap()

func _process(delta: float) -> void:
	if _acabou:
		return
	_t += delta
	_anim.advance(delta)
	_snap()

	# Vagalume: sobe/desce 1px e a luz pulsa devagar.
	_corpo_vagalume.position.y = roundf(sin(_t * 5.0))
	var pulso := sin(_t * pulso_velocidade) * pulso_amplitude
	_halo.energy = energia_halo * (1.0 + pulso)
	_core.energy = energia_core * (1.0 + pulso * 0.6)
	_brilho.modulate.a = _brilho_alpha * (1.0 + pulso)

	_atualizar_pular(delta)

func _snap() -> void:
	_elisio.position = _elisio.position.round()
	_vagalume.position = _vagalume.position.round()
	_camera.position = _camera.position.round()

func _atualizar_pular(delta: float) -> void:
	var apertado := Input.is_action_pressed("ui_accept")
	if not apertado:
		_soltou_accept = true
	if apertado and _soltou_accept:
		_segurando += delta
	else:
		_segurando = maxf(_segurando - delta * 3.0, 0.0)
	var progresso := clampf(_segurando / tempo_pular, 0.0, 1.0)
	_pular.modulate.a = 0.35 if _segurando > 0.0 else 0.0
	_pular_barra.scale.x = progresso
	if progresso >= 1.0:
		_terminar()

## Chamado pela track de método no fim da animação (ou ao pular).
func _terminar() -> void:
	if _acabou:
		return
	_acabou = true
	Transicao.ir_para_cena(proxima_cena)
