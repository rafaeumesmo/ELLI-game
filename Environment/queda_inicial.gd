extends Node2D
## Cena de abertura, antes do tutorial: Elísio tenta pegar o vagalume, erra
## e cai em um poço de água. O mergulho levanta respingos e ondas antes
## de escurecer; o tutorial começa com ele deitado no chão.
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
@onready var _halo: Sprite2D = $Vagalume/Halo
@onready var _core: Sprite2D = $Vagalume/Core
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
var _po_borda: CPUParticles2D
var _soltou_po := false
var _mergulhou := false

func _ready() -> void:
	_pular.modulate.a = 0.0
	_brilho_alpha = _brilho.modulate.a
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim.play("queda")
	_anim.seek(0.0, true)
	_criar_poeira()
	_snap()

func _process(delta: float) -> void:
	if _acabou:
		return
	_t += delta
	_anim.advance(delta)
	_snap()
	# Um pouco de terra se solta no último impulso, marcando a borda do abismo.
	if not _soltou_po and _t >= 2.22:
		_soltou_po = true
		_po_borda.emitting = true
	# Breve tremor ao perder o apoio; depois a câmera acompanha a queda.
	var susto := clampf(1.0 - (_t - 3.5) / 0.35, 0.0, 1.0) if _t >= 3.5 else 0.0
	_camera.offset = Vector2(roundf(sin(_t * 65.0) * susto), 0.0)
	if not _mergulhou and _elisio.position.y >= $AguaPoco.position.y:
		_mergulhou = true
		$AguaPoco.mergulhar(_elisio.position.x)
	if _mergulhou:
		var impacto := 1.0 - smoothstep(6.35, 6.7, _t)
		_camera.offset.y = roundf(sin(_t * 55.0) * impacto * 2.0)
		_elisio.modulate.a = 1.0 - smoothstep(6.35, 7.0, _t)

	# Vagalume: sobe/desce 1px e a luz pulsa devagar.
	_corpo_vagalume.position.y = roundf(sin(_t * 5.0))
	var pulso := sin(_t * pulso_velocidade) * pulso_amplitude
	_halo.self_modulate.a = clampf(energia_halo * (1.0 + pulso) * 0.35, 0.0, 1.0)
	_core.self_modulate.a = clampf(energia_core * (1.0 + pulso * 0.6) * 0.4, 0.0, 1.0)
	_brilho.modulate.a = _brilho_alpha * (1.0 + pulso)
	# O cenário também mergulha na escuridão, incluindo o fundo ilustrado.
	var escuridao := smoothstep(4.15, 8.5, _t)
	$FundoDaFase.modulate = Color.WHITE.lerp(Color(0.16, 0.21, 0.3), escuridao)

	_atualizar_pular(delta)

func _criar_poeira() -> void:
	_po_borda = CPUParticles2D.new()
	_po_borda.emitting = false
	_po_borda.one_shot = true
	_po_borda.explosiveness = 1.0
	_po_borda.amount = 12
	_po_borda.lifetime = 1.4
	_po_borda.position = Vector2(-3, -1)
	_po_borda.direction = Vector2(1, -0.5)
	_po_borda.spread = 40.0
	_po_borda.initial_velocity_min = 8.0
	_po_borda.initial_velocity_max = 22.0
	_po_borda.gravity = Vector2(0, 65)
	_po_borda.color = Color(0.45, 0.43, 0.53, 0.8)
	add_child(_po_borda)

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
	var progresso := clampf(_segurando / maxf(tempo_pular, 0.1), 0.0, 1.0)
	_pular.modulate.a = 0.9 if _segurando > 0.0 else smoothstep(0.8, 1.8, _t) * 0.55
	_pular_barra.scale.x = progresso
	if progresso >= 1.0:
		_terminar()

## Chamado pela track de método no fim da animação (ou ao pular).
func _terminar() -> void:
	if _acabou:
		return
	_acabou = true
	Transicao.ir_para_cena(proxima_cena)
