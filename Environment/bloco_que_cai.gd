extends CharacterBody2D
## Bloco 2x2 (32x32) que fica flutuando parado e despenca reto quando alguém
## chama derrubar() -- normalmente um GatilhoQueda posicionado em outro lugar.
## Enquanto não cai ele é sólido e imóvel (dá pra ficar em cima).

const LADO := 2          ## bloquinhos por linha/coluna
const TILE := 16.0       ## tamanho de cada bloquinho (px)
const GRAVIDADE := 900.0
const VEL_MAX := 1500.0

## Textura 16x16 de cada bloquinho. Deixe vazio pra usar assets/blocos4.png.
@export var textura: Texture2D

var _visual: Node2D
var _caindo := false
var _parado := false

func _ready() -> void:
	if textura == null:
		textura = load("res://assets/blocos4.png")
	_montar_visual()

func _montar_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	var canto := -(LADO * TILE) * 0.5 + TILE * 0.5
	for y in LADO:
		for x in LADO:
			var s := Sprite2D.new()
			s.texture = textura
			s.position = Vector2(canto + x * TILE, canto + y * TILE)
			_visual.add_child(s)

func _physics_process(delta: float) -> void:
	if not _caindo or _parado:
		return
	velocity.y = min(velocity.y + GRAVIDADE * delta, VEL_MAX)
	# move_and_slide desliza nas paredes laterais em vez de travar nelas.
	move_and_slide()
	# Só para de verdade quando encosta em algo por baixo.
	if is_on_floor():
		_parado = true
		velocity = Vector2.ZERO
		_poeira()

## Solta o bloco. Chamado pelo GatilhoQueda (ou por qualquer outro script).
func derrubar() -> void:
	if _caindo:
		return
	# Tremidinha antes de cair.
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	for i in 3:
		tw.tween_property(_visual, "position:x", 1.5, 0.04)
		tw.tween_property(_visual, "position:x", -1.5, 0.04)
	tw.tween_property(_visual, "position:x", 0.0, 0.04)
	tw.tween_callback(func() -> void: _caindo = true)

func _poeira() -> void:
	var po := CPUParticles2D.new()
	po.position = Vector2(0, LADO * TILE * 0.5)
	po.one_shot = true
	po.explosiveness = 0.9
	po.amount = 14
	po.lifetime = 0.5
	po.direction = Vector2(0, -1)
	po.spread = 70.0
	po.gravity = Vector2(0, 120)
	po.initial_velocity_min = 20.0
	po.initial_velocity_max = 50.0
	po.scale_amount_min = 1.5
	po.scale_amount_max = 3.0
	po.color = Color(0.6, 0.55, 0.5, 0.8)
	add_child(po)
	po.emitting = true
	get_tree().create_timer(0.9).timeout.connect(po.queue_free)
