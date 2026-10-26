extends Area2D
## Gatilho solto: posicione onde quiser. Quando o player encosta, manda cada
## bloco de `blocos` (arraste os BlocoQueCai aqui no Inspector) despencar.

## Nós BlocoQueCai que esse gatilho derruba.
@export var blocos: Array[NodePath] = []
## Se true, o gatilho para de valer depois do primeiro toque.
@export var uma_vez_so: bool = true

## Cor base das partículas (segue o tom quente do vagalume).
const COR := Color(0.9, 0.75, 0.25)
## Energia máxima do halo (luz grande e suave) enquanto o gatilho está armado.
@export var energia_halo: float = 1.1
## Energia máxima do núcleo (luz pequena e forte) enquanto o gatilho está armado.
@export var energia_core: float = 2.0
## Amplitude da flutuação em lemniscata, em pixels -- mesmo voo parado do PortalFase.
@export var raio_voo: float = 10.0
## Velocidade angular da flutuação.
@export var velocidade_voo: float = 0.5
## Velocidade do voo até o bloco depois que o player encosta (px/s).
@export var velocidade_voo_bloco: float = 130.0

@onready var _corpo: AnimatedSprite2D = $Corpo
@onready var _halo: PointLight2D = $Halo
@onready var _core: PointLight2D = $Core

var _usado := false
var _t := 0.0
var _origem := Vector2.ZERO
var _offset := Vector2.ZERO
## Fagulhas que sobem devagar do vagalume enquanto o gatilho está armado.
var _brilho: CPUParticles2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_origem = position
	_corpo.play("voar")
	_criar_brilho()

func _criar_brilho() -> void:
	_brilho = CPUParticles2D.new()
	_brilho.amount = 16
	_brilho.lifetime = 1.6
	_brilho.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_brilho.emission_rect_extents = Vector2(7, 7)
	_brilho.direction = Vector2(0, -1)
	_brilho.spread = 20.0
	_brilho.gravity = Vector2.ZERO
	_brilho.initial_velocity_min = 5.0
	_brilho.initial_velocity_max = 13.0
	_brilho.scale_amount_min = 1.0
	_brilho.scale_amount_max = 2.5
	_brilho.color = Color.WHITE
	# Envelope de alpha: nasce transparente, acende e some.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([
		Color(COR.r, COR.g, COR.b, 0.0),
		Color(COR.r, COR.g, COR.b, 0.85),
		Color(COR.r, COR.g, COR.b, 0.0),
	])
	_brilho.color_ramp = grad
	add_child(_brilho)
	_brilho.emitting = true

func _process(delta: float) -> void:
	if _usado:
		return
	_t += delta
	var pulso := 0.5 + sin(_t * 3.0) * 0.35
	_halo.energy = energia_halo * pulso
	_core.energy = energia_core * pulso

	# Flutuação em lemniscata parada, igual o PortalFase -- ainda dentro do
	# alcance do CollisionShape2D, entao continua tocavel o tempo todo.
	var voo := _t * velocidade_voo
	_offset.x = sin(voo) * raio_voo
	_offset.y = sin(voo * 2.0) * raio_voo * 0.5
	position = _origem + _offset
	_corpo.flip_h = cos(voo) < 0.0

func _on_body_entered(body: Node) -> void:
	if _usado or not body.is_in_group("player"):
		return
	# Em vez de "coletar" que nem um vagalume comum, o gatilho voa ate o
	# bloco e so ativa quando chega la.
	_usado = true
	set_deferred("monitoring", false)
	_voar_ate_bloco()

## Volta pra posicao original e reativa o toque (so quando `uma_vez_so` == false).
func _rearmar() -> void:
	var duracao := clampf(global_position.distance_to(_origem) / velocidade_voo_bloco, 0.6, 2.4)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_atualizar_voo.bind(global_position, _origem), 0.0, 1.0, duracao)
	tw.tween_property(_corpo, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func() -> void:
		_brilho.emitting = true
		_offset = Vector2.ZERO
		set_deferred("monitoring", true)
		_usado = false
	)

## Posicao do primeiro bloco valido em `blocos` (destino do voo). Sem bloco
## valido, fica onde esta -- so ativa no lugar, que nem antes.
func _posicao_alvo() -> Vector2:
	for caminho in blocos:
		var bloco := get_node_or_null(caminho)
		if bloco != null:
			return bloco.global_position
	return global_position

func _voar_ate_bloco() -> void:
	var origem := global_position
	var alvo := _posicao_alvo()
	var duracao := clampf(origem.distance_to(alvo) / velocidade_voo_bloco, 0.6, 2.4)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_atualizar_voo.bind(origem, alvo), 0.0, 1.0, duracao)
	tw.tween_callback(_ativar_blocos)

func _atualizar_voo(t: float, origem: Vector2, alvo: Vector2) -> void:
	global_position = origem.lerp(alvo, t)
	_corpo.flip_h = alvo.x < origem.x

## Chamado quando o gatilho chega no bloco: estoura, derruba e apaga
## (ou volta pra posicao original, se `uma_vez_so` == false).
func _ativar_blocos() -> void:
	_estourar()
	for caminho in blocos:
		var bloco := get_node_or_null(caminho)
		if bloco != null and bloco.has_method("derrubar"):
			bloco.derrubar()
	_brilho.emitting = false
	if not uma_vez_so:
		_rearmar()
		return
	var tw := create_tween()
	tw.tween_property(_corpo, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(_halo, "energy", 0.0, 0.25)
	tw.parallel().tween_property(_core, "energy", 0.0, 0.25)

## Puff de partículas no momento em que o gatilho dispara.
func _estourar() -> void:
	var po := CPUParticles2D.new()
	po.one_shot = true
	po.explosiveness = 1.0
	po.amount = 20
	po.lifetime = 0.55
	po.direction = Vector2(0, -1)
	po.spread = 180.0
	po.gravity = Vector2(0, 160)
	po.initial_velocity_min = 40.0
	po.initial_velocity_max = 110.0
	po.scale_amount_min = 1.5
	po.scale_amount_max = 3.0
	po.color = Color(COR.r, COR.g, COR.b, 0.9)
	add_child(po)
	po.emitting = true
	get_tree().create_timer(1.0).timeout.connect(po.queue_free)
