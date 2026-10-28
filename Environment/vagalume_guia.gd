extends Node2D
## Vagalume-guia: voa na frente do player pelo caminho até o portal de saída
## -- `pontos` é uma sequência de waypoints que segue os corredores do mapa
## (não uma linha reta, pra não atravessar parede). Em cada waypoint (menos
## no último) ele para e espera o player chegar perto antes de continuar pro
## próximo; no último ponto (o portal) ele chega e fica flutuando por perto
## (mesma flutuação em oito do Vagalume comum) em vez de parar parado, com o
## guia completo. Mesmo visual do Vagalume comum (asas batendo + halo/core
## pulsando), mas sempre visível -- sem sumir/reaparecer aleatório.
##
## Uso: arraste `VagalumeGuia.tscn` pro mapa e preenche `pontos` (espaço
## local do nó pai) com os waypoints do trajeto -- a 1ª é onde ele começa
## (perto do player), a última costuma ser o portal, e os do meio marcam as
## curvas dos corredores/chaminés que tem que contornar.

@export var pontos: PackedVector2Array = PackedVector2Array()
@export var velocidade: float = 65.0
## Distância (do player até o vagalume) abaixo da qual ele considera que o
## player "chegou" e pode seguir pro próximo ponto.
@export var raio_espera: float = 200.0
## Pausa depois que o player chega, antes de sair voando de novo -- só pra
## não parecer que ele sai no exato instante em que o player encosta.
@export var pausa_antes_de_seguir: float = 0.4
@export var amplitude_zigue: float = 6.0
## Raio da flutuação em oito que ele faz parado no ponto final (o portal).
@export var raio_flutuacao: float = 14.0
## Velocidade angular dessa flutuação final.
@export var velocidade_flutuacao: float = 0.7
@export var energia_halo: float = 1.1
@export var energia_core: float = 2.4
@export var cor_luz: Color = Color("#FFD023"):
	set(v):
		cor_luz = v
		_aplicar_cor()
## Nó do PortalFase que este vagalume vira ao chegar no ponto final -- em vez
## de ficar flutuando do lado, ele some enquanto o portal (escondido até essa
## hora) aparece no mesmo lugar. Deixa vazio pra manter o comportamento antigo
## (fica flutuando por perto pra sempre).
@export var portal_alvo: NodePath = NodePath("")
@export var duracao_transformacao: float = 0.6

@onready var _corpo: AnimatedSprite2D = $Corpo
const HALO_ALPHA := 0.35
const CORE_ALPHA := 0.4

@onready var _halo: Sprite2D = $Halo
@onready var _core: Sprite2D = $Core

var _fase_pulso: float = 0.0
var _flutuando := false
var _origem_flutuacao := Vector2.ZERO
var _tempo_flutuacao: float = 0.0
var _transformando := false

func _ready() -> void:
	_corpo.play("voar")
	_aplicar_cor()
	modulate.a = 1.0
	if pontos.size() >= 1:
		position = pontos[0]
	if pontos.size() >= 2:
		_guiar()

func _aplicar_cor() -> void:
	if _halo == null:
		return
	# Sprites aditivos e unshaded: a luz aparece mesmo sobre fundo escuro.
	_halo.self_modulate = Color(cor_luz.r, cor_luz.g, cor_luz.b, _halo.self_modulate.a)
	var cor_core := cor_luz.lightened(0.35)
	_core.self_modulate = Color(cor_core.r, cor_core.g, cor_core.b, _core.self_modulate.a)
	_corpo.modulate = Color(cor_luz.r * 1.3, cor_luz.g * 1.3, cor_luz.b * 1.3, 1.0)

func _process(delta: float) -> void:
	if _transformando:
		return
	_fase_pulso += delta * 2.0
	var pulso: float = 0.85 + 0.15 * sin(_fase_pulso)
	_halo.self_modulate.a = minf(energia_halo * pulso * HALO_ALPHA, 1.0)
	_core.self_modulate.a = minf(energia_core * pulso * CORE_ALPHA, 1.0)

	if _flutuando:
		_tempo_flutuacao += delta * velocidade_flutuacao
		var t: float = _tempo_flutuacao
		var offset := Vector2(sin(t) * raio_flutuacao, sin(t * 2.0) * raio_flutuacao * 0.5)
		position = _origem_flutuacao + offset

func _guiar() -> void:
	for i in range(1, pontos.size()):
		await _voar_ate(pontos[i])
		# Player morreu e a cena recarregou enquanto a gente esperava: este
		# vagalume já saiu da árvore (get_tree() == null), só para.
		if not is_inside_tree():
			return
		if i < pontos.size() - 1:
			await _esperar_jogador()
			if not is_inside_tree():
				return
			await get_tree().create_timer(pausa_antes_de_seguir).timeout
			if not is_inside_tree():
				return
	if not portal_alvo.is_empty():
		var portal := get_node_or_null(portal_alvo)
		if portal != null:
			await _transformar_em_portal(portal)
			return
	_origem_flutuacao = position
	_flutuando = true

func _transformar_em_portal(portal: Node) -> void:
	_transformando = true
	if portal.has_method("revelar"):
		portal.revelar()
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_corpo, "modulate:a", 0.0, duracao_transformacao)
	tw.tween_property(_halo, "self_modulate:a", 0.0, duracao_transformacao)
	tw.tween_property(_core, "self_modulate:a", 0.0, duracao_transformacao)
	await tw.finished
	queue_free()

func _esperar_jogador() -> void:
	while is_inside_tree():
		var jogador := get_tree().get_first_node_in_group("player") as Node2D
		if jogador == null or not is_instance_valid(jogador):
			return
		if global_position.distance_to(jogador.global_position) <= raio_espera:
			return
		await get_tree().process_frame

func _voar_ate(alvo: Vector2) -> void:
	var origem := position
	var distancia := origem.distance_to(alvo)
	var duracao: float = max(distancia / velocidade, 0.1)
	var perpendicular := (alvo - origem).orthogonal().normalized()
	_corpo.flip_h = alvo.x < origem.x
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(t: float) -> void:
			var base := origem.lerp(alvo, t)
			var onda: float = sin(t * TAU * 2.0) * amplitude_zigue * t * (1.0 - t) * 4.0
			position = base + perpendicular * onda,
		0.0, 1.0, duracao
	)
	await tw.finished
