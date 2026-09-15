extends Node2D
## Vagalume decorativo: bate as asas, flutua num vaivém orgânico tipo
## lemniscata ao redor do ponto onde foi colocado, com luz quente pulsando
## (Halo suave e grande + Core pequeno e forte) e some/reaparece de vez em
## quando. Sem colisão -- é só ambientação e iluminação de cena escura.
##
## Uso: arraste `Vagalume.tscn` pro mapa. Ajusta `raio_voo`/`velocidade` pro
## jeito que ele voa e `cor_luz`/`energia_halo`/`energia_core` pro brilho.

## Amplitude da flutuação em lemniscata, em pixels (espaço local do nó).
@export var raio_voo: float = 24.0
## Velocidade angular da flutuação -- maior valor, voo mais agitado.
@export var velocidade: float = 0.6
## Energia base do halo (luz grande e suave).
@export var energia_halo: float = 0.9
## Energia base do núcleo (luz pequena e forte, tipo brasa).
@export var energia_core: float = 2.0
## Cor do halo. O núcleo fica sempre num branco-quente fixo.
@export var cor_luz: Color = Color("#FFD98A"):
	set(v):
		cor_luz = v
		if _halo != null:
			_halo.color = cor_luz
## Quanto tempo (min/max, em segundos) ele fica visível antes de sumir.
@export var tempo_visivel_min: float = 3.0
@export var tempo_visivel_max: float = 6.0
## Quanto tempo (min/max, em segundos) ele fica sumido antes de reaparecer.
@export var tempo_sumido_min: float = 0.8
@export var tempo_sumido_max: float = 2.2

@onready var _corpo: AnimatedSprite2D = $Corpo
@onready var _halo: PointLight2D = $Halo
@onready var _core: PointLight2D = $Core

## RNG próprio por instância -- usar o global randomize() em cada _ready()
## faria vagalumes que nascem no mesmo frame sincronizarem a fase.
var _rng := RandomNumberGenerator.new()
var _origem := Vector2.ZERO
var _fase_voo: float = 0.0
var _fase_pulso: float = 0.0
var _freq_pulso: float = 1.0
var _tempo_voo: float = 0.0
var _tempo_pulso: float = 0.0
var _visivel: bool = false
var _offset := Vector2.ZERO

func _ready() -> void:
	_rng.seed = hash(str(get_instance_id()) + str(Time.get_ticks_usec()))
	_origem = position
	_fase_voo = _rng.randf_range(0.0, TAU)
	_fase_pulso = _rng.randf_range(0.0, TAU)
	_freq_pulso = _rng.randf_range(1.6, 2.4)
	_corpo.play("voar")
	_halo.color = cor_luz
	modulate.a = 0.0
	_halo.energy = 0.0
	_core.energy = 0.0
	_ciclo_de_vida()

func _process(delta: float) -> void:
	# flutuação tipo lemniscata (curva em oito) ao redor da posição inicial
	_tempo_voo += delta * velocidade
	var t: float = _tempo_voo + _fase_voo
	_offset.x = sin(t) * raio_voo
	_offset.y = sin(t * 2.0) * raio_voo * 0.5
	position = _origem + _offset

	if _visivel:
		# pulsação de energia com frequência diferente da flutuação, pra não
		# sincronizar os dois movimentos
		_tempo_pulso += delta * _freq_pulso
		var pulso: float = 0.875 + 0.125 * sin(_tempo_pulso + _fase_pulso)
		_halo.energy = energia_halo * pulso
		_core.energy = energia_core * pulso

func _ciclo_de_vida() -> void:
	while is_inside_tree():
		await _aparecer()
		await get_tree().create_timer(_rng.randf_range(tempo_visivel_min, tempo_visivel_max)).timeout
		await _sumir()
		await get_tree().create_timer(_rng.randf_range(tempo_sumido_min, tempo_sumido_max)).timeout

func _aparecer() -> void:
	_visivel = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.9)
	await tw.finished

func _sumir() -> void:
	_visivel = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	tw.parallel().tween_property(_halo, "energy", 0.0, 1.2)
	tw.parallel().tween_property(_core, "energy", 0.0, 1.2)
	await tw.finished
