extends CharacterBody2D
## Bloco (LADOxLADO bloquinhos de 16px) que fica flutuando parado e despenca
## reto quando alguém chama derrubar() -- normalmente um GatilhoQueda
## posicionado em outro lugar, ou o próprio player pisando em cima (ver
## `cai_ao_pisar`). Enquanto não cai ele é sólido e imóvel (dá pra ficar em cima).

const TILE := 16.0       ## tamanho de cada bloquinho (px)
const GRAVIDADE := 900.0
const VEL_MAX := 1500.0

## Bloquinhos por linha/coluna. 1 = um bloco unico (16x16), 2 = 2x2 (32x32), etc.
@export_range(1, 4) var lado: int = 2

## Textura 16x16 de cada bloquinho. Deixe vazio pra usar assets/blocos4.png.
@export var textura: Texture2D

## Se ligado, o bloco cai sozinho assim que o player pisa em cima dele --
## alem de continuar podendo ser chamado por fora via derrubar() (GatilhoQueda).
@export var cai_ao_pisar: bool = false
## Se ligado, o bloco cai sozinho quando o player passa por baixo dele (sem
## precisar tocar no bloco) -- pra ele desabar em cima de quem passa embaixo.
@export var cai_ao_passar_embaixo: bool = false
## Pisca (some/aparece) antes de cair, alem da tremidinha, pra avisar o player.
@export var pisca_antes_de_cair: bool = false
## Ao pousar, quebra em particulas e some, em vez de ficar solido parado pra sempre.
@export var quebra_ao_pousar: bool = false
## Volta à posição inicial após cair, aguardando o personagem sair do espaço.
@export var reaparece: bool = true
@export_range(0.5, 15.0, 0.1) var tempo_reaparecer: float = 3.0

var _origem: Transform2D
var _layer_original: int
var _mask_original: int
var _preparando := false
var _retornando := false
var _espera := 0.0
var _tempo_caindo := 0.0

## Brilho normal dos blocos (ignora o escurecimento do CanvasModulate), sem
## vazar pra fora do bloco -- mesmo material usado na camada Blocos da tilemap.
static var _material_brilho: CanvasItemMaterial

var _visual: Node2D
var _caindo := false
var _parado := false

func _ready() -> void:
	_origem = transform
	_layer_original = collision_layer
	_mask_original = collision_mask
	if textura == null:
		textura = load("res://assets/blocos4.png")
	if _material_brilho == null:
		_material_brilho = CanvasItemMaterial.new()
		_material_brilho.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_montar_visual()
	_ajustar_colisao()
	if cai_ao_pisar:
		_montar_zona_pisao()
	if cai_ao_passar_embaixo:
		_montar_zona_passagem_embaixo()

## Area2D fina bem no topo do bloco: qualquer coisa do grupo "player" que pisar
## ali dispara a queda (mesma derrubar() que o GatilhoQueda chama por fora).
func _montar_zona_pisao() -> void:
	var zona := Area2D.new()
	zona.collision_layer = 0
	zona.collision_mask = 1
	zona.monitorable = false
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(lado * TILE - 4.0, 6.0)
	forma.shape = retangulo
	forma.position = Vector2(0.0, -(lado * TILE) * 0.5)
	zona.add_child(forma)
	add_child(zona)
	zona.body_entered.connect(_on_zona_pisao_body_entered)

func _on_zona_pisao_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		derrubar()

## Area2D logo abaixo do bloco: qualquer coisa do grupo "player" que passar
## por ali dispara a queda, mesmo sem tocar no bloco -- pra ele desabar em
## cima de quem passa embaixo, em vez de só quando pisam em cima.
func _montar_zona_passagem_embaixo() -> void:
	var zona := Area2D.new()
	zona.collision_layer = 0
	zona.collision_mask = 1
	zona.monitorable = false
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(lado * TILE - 4.0, 60.0)
	forma.shape = retangulo
	forma.position = Vector2(0.0, (lado * TILE) * 0.5 + 30.0)
	zona.add_child(forma)
	add_child(zona)
	zona.body_entered.connect(_on_zona_passagem_embaixo_body_entered)

func _on_zona_passagem_embaixo_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		derrubar()

func _montar_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	var canto := -(lado * TILE) * 0.5 + TILE * 0.5
	for y in lado:
		for x in lado:
			var s := Sprite2D.new()
			s.texture = textura
			s.material = _material_brilho
			s.position = Vector2(canto + x * TILE, canto + y * TILE)
			_visual.add_child(s)
	var detalhes := Node2D.new()
	detalhes.set_script(preload("res://Environment/detalhes_bloco.gd"))
	detalhes.set("tamanho", Vector2.ONE * lado * TILE)
	detalhes.set("textura", textura)
	detalhes.material = _material_brilho
	_visual.add_child(detalhes)

## Redimensiona a colisao (definida no .tscn pra caber o LADO=2 padrao) pro
## tamanho real deste bloco. Duplica o shape antes de mexer -- senao, como
## instancias da mesma cena compartilham o mesmo SubResource, mudar o tamanho
## aqui mudaria TODAS as instancias de BlocoQueCai.tscn ja espalhadas nos mapas.
func _ajustar_colisao() -> void:
	var col := $CollisionShape2D as CollisionShape2D
	var forma := (col.shape as RectangleShape2D).duplicate() as RectangleShape2D
	forma.size = Vector2(lado * TILE - 2.0, lado * TILE)
	col.shape = forma

func _physics_process(delta: float) -> void:
	if _retornando:
		_espera -= delta
		if _espera <= 0.0:
			_tentar_reaparecer()
		return
	if not _caindo or _parado:
		return
	_tempo_caindo += delta
	# Também recupera blocos que caíram num abismo sem chão.
	if reaparece and _tempo_caindo > 5.0:
		_iniciar_retorno()
		return
	velocity.y = min(velocity.y + GRAVIDADE * delta, VEL_MAX)
	# move_and_slide desliza nas paredes laterais em vez de travar nelas.
	move_and_slide()
	# Só para de verdade quando encosta em algo por baixo.
	if is_on_floor():
		_parado = true
		velocity = Vector2.ZERO
		_poeira()
		if quebra_ao_pousar:
			_quebrar()
		elif reaparece:
			_iniciar_retorno()

## Solta o bloco. Chamado pelo GatilhoQueda, pela ZonaPisao (cai_ao_pisar) ou
## por qualquer outro script.
func derrubar() -> void:
	if _caindo or _preparando or _retornando:
		return
	_preparando = true
	_ativar_espinhos()
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	if pisca_antes_de_cair:
		for i in 4:
			tw.tween_property(self, "modulate:a", 0.25, 0.08)
			tw.tween_property(self, "modulate:a", 1.0, 0.08)
	# Tremidinha antes de cair.
	for i in 3:
		tw.tween_property(_visual, "position:x", 1.5, 0.04)
		tw.tween_property(_visual, "position:x", -1.5, 0.04)
	tw.tween_property(_visual, "position:x", 0.0, 0.04)
	tw.tween_callback(func() -> void:
		_preparando = false
		_caindo = true
	)

## Liga qualquer EspinhoPreso filho (ex.: BlocoFragilComEspinho) que tenha
## `comeca_ativo = false` -- ele só passa a machucar quando o bloco de fato
## começa a cair, não enquanto o player só passa por baixo esperando.
func _ativar_espinhos() -> void:
	for filho in get_children():
		if filho.has_method("ativar"):
			filho.ativar()

## Some pra sempre depois de pousar (em vez de ficar solido parado): tira a
## colisao na hora (senao o player fica em cima de um bloco "fantasma" ate a
## poeira acabar) e espera a poeira acabar antes de sair da arvore de vez.
func _quebrar() -> void:
	if reaparece:
		_iniciar_retorno()
		return
	collision_layer = 0
	collision_mask = 0
	_visual.visible = false
	get_tree().create_timer(0.9).timeout.connect(queue_free)

func _iniciar_retorno() -> void:
	_retornando = true
	_espera = tempo_reaparecer
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hide()
	for filho in get_children():
		if filho.has_method("desativar"):
			filho.desativar()

func _tentar_reaparecer() -> void:
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = $CollisionShape2D.shape
	consulta.transform = get_parent().global_transform * _origem * $CollisionShape2D.transform
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		_espera = 0.1
		return
	transform = _origem
	velocity = Vector2.ZERO
	_visual.position = Vector2.ZERO
	_visual.visible = true
	modulate.a = 1.0
	collision_layer = _layer_original
	collision_mask = _mask_original
	_caindo = false
	_parado = false
	_preparando = false
	_retornando = false
	_tempo_caindo = 0.0
	show()

func _poeira() -> void:
	var po := CPUParticles2D.new()
	po.position = Vector2(0, lado * TILE * 0.5)
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
