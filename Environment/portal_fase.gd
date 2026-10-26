extends Area2D
## Portal de fim de fase, disfarçado de vagalume de luz azul. Basta o player
## encostar: ele murcha suave e troca de cena. A lógica de save é a mesma de
## antes -- só o visual é o mesmo bicho do `Vagalume.tscn` (asas + halo/core),
## mas azul e sempre visível, pra dar pra distinguir dos vagalumes amarelos
## de ambientação/guia.
## Quando o player encosta, o vagalume se assusta e foge voando pra longe
## dele (pra cima e pro lado oposto), apagando no caminho -- só depois a fase
## troca.

@export_file("*.tscn") var next_scene: String = ""
## Cor da luz do portal-vagalume (halo e núcleo).
@export var cor: Color = Color("#3DA9FC")
## Energia base do halo (luz grande e suave). Mais alta que o vagalume comum
## de propósito, mas sem estourar o bloom a ponto de o bicho virar só uma
## bola de luz -- ainda tem que dar pra reconhecer o vagalume dentro dela.
@export var energia_halo: float = 1.5
## Energia base do núcleo (luz pequena e forte).
@export var energia_core: float = 2.6
## Amplitude da flutuação em lemniscata, em pixels.
@export var raio_voo: float = 10.0
## Velocidade angular da flutuação.
@export var velocidade_voo: float = 0.5
## Nasce invisível e sem colisão -- só aparece quando algo (ex.: um
## VagalumeGuia) chamar `revelar()`. Usado quando o portal é o destino final
## de um vagalume-guia, pra dar a impressão de que um virou o outro.
@export var comeca_escondido: bool = false
## Fuga ao ser pego: distância total que ele voa (px) e quanto tempo leva.
@export var distancia_fuga: float = 200.0
@export var duracao_fuga: float = 1.1
## Ângulo da fuga acima da horizontal (graus) -- 90 = reto pra cima.
@export var angulo_fuga: float = 55.0
## Amplitude do zigue-zague durante a fuga.
@export var zigue_fuga: float = 10.0

var _ativando := false
var _t := 0.0
var _origem := Vector2.ZERO
var _offset := Vector2.ZERO
var _energia_mult: float = 1.0

## Halo e um Sprite2D aditivo e unshaded (nao luz), entao brilha em cima de
## qualquer coisa. Converte energia_halo em opacidade do sprite.
const HALO_ALPHA := 0.35
## Mesmo esquema pro Core: brilho branco pequeno e forte em volta do corpo.
const CORE_ALPHA := 0.35

@onready var particulas: CPUParticles2D = $Particulas
@onready var _corpo: AnimatedSprite2D = $Corpo
@onready var _halo: Sprite2D = $Halo
@onready var _core: Sprite2D = $Core

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("portal_fase")
	_origem = position
	_corpo.play("voar")
	_halo.self_modulate = Color(cor.r, cor.g, cor.b, 0.0)
	if comeca_escondido:
		monitoring = false
		_corpo.modulate.a = 0.0
		_energia_mult = 0.0

## true depois que o player encostou (a fuga + troca de cena já começou).
func foi_pego() -> bool:
	return _ativando

func revelar() -> void:
	monitoring = true
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_corpo, "modulate:a", 1.0, 0.5)
	tw.tween_method(func(v: float) -> void: _energia_mult = v, 0.0, 1.0, 0.5)

func _process(delta: float) -> void:
	if _ativando:
		return
	_t += delta
	# Flutuação tipo lemniscata, igual o Vagalume decorativo -- ainda dentro
	# do alcance do CollisionShape2D, então continua tocável o tempo todo.
	var voo := _t * velocidade_voo
	_offset.x = sin(voo) * raio_voo
	_offset.y = sin(voo * 2.0) * raio_voo * 0.5
	position = _origem + _offset
	_corpo.flip_h = cos(voo) < 0.0
	var pulso := 0.85 + 0.15 * sin(_t * 2.0)
	_halo.self_modulate.a = energia_halo * pulso * _energia_mult * HALO_ALPHA
	_core.self_modulate.a = minf(energia_core * pulso * _energia_mult * CORE_ALPHA, 1.0)

func _on_body_entered(body: Node) -> void:
	if _ativando or not body.is_in_group("player"):
		return
	if next_scene == "":
		push_warning("PortalFase: defina 'Next Scene' no Inspector.")
		return
	_ativar()

func _ativar() -> void:
	_ativando = true
	particulas.emitting = true
	# Foge pro lado oposto do player (se ele tá em cima, escolhe pelo flip atual).
	var lado := -1.0 if _corpo.flip_h else 1.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and absf(player.global_position.x - global_position.x) > 1.0:
		lado = signf(global_position.x - player.global_position.x)
	_corpo.flip_h = lado < 0.0
	var ang := deg_to_rad(angulo_fuga)
	var dir := Vector2(cos(ang) * lado, -sin(ang))
	var origem := position
	var alvo := origem + dir * distancia_fuga
	var perpendicular := dir.orthogonal()
	# Susto: um pulinho pra cima e o halo acende, antes de disparar.
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origem + Vector2(0, -6), 0.12)
	tw.parallel().tween_method(func(v: float) -> void: _aplicar_brilho(v), 1.0, 1.6, 0.12)
	var inicio_voo := origem + Vector2(0, -6)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(
		func(t: float) -> void:
			var base := inicio_voo.lerp(alvo, t)
			var onda := sin(t * TAU * 3.0) * zigue_fuga * (1.0 - t)
			position = base + perpendicular * onda
			# Apaga na segunda metade do voo.
			var apagar := clampf((t - 0.5) * 2.0, 0.0, 1.0)
			_corpo.modulate.a = 1.0 - apagar
			_aplicar_brilho(1.6 * (1.0 - apagar)),
		0.0, 1.0, duracao_fuga
	)
	tw.tween_interval(0.1)
	tw.tween_callback(_trocar_cena)

func _aplicar_brilho(mult: float) -> void:
	_halo.self_modulate.a = energia_halo * mult * HALO_ALPHA
	_core.self_modulate.a = minf(energia_core * mult * CORE_ALPHA, 1.0)

func _trocar_cena() -> void:
	# Trocar de fase também commita a espada (senão dá pra perder ela no portal).
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.get("tem_espada"):
		SaveManager.tem_espada = true
	if player != null and player.get("dash_desbloqueado"):
		SaveManager.tem_dash = true
	SaveManager.save_progress(next_scene)
	get_tree().paused = false
	Transicao.ir_para_cena(next_scene)
