extends AnimatableBody2D
## Esmagador: blocão pendurado que treme, despenca no chão, fica um instante
## parado e sobe devagar de volta -- em loop. Quem estiver embaixo quando ele
## desce morre esmagado; em cima dele dá pra pegar carona (AnimatableBody2D).
## A distância da queda é achada sozinha (raio até o chão) se `distancia_queda`
## for 0.

enum Estado { ESPERA_CIMA, AVISO, CAINDO, NO_CHAO, SUBINDO }

const TILE := 16.0
## Altura desenhada do espinho_baixo.png (igual SPIKE_DOWN_DRAWN_HEIGHT em blocos_layer.gd).
const ESPINHO_ALT := 10.0

## Tamanho em bloquinhos de 16px.
@export_range(1, 8) var largura: int = 3
@export_range(1, 8) var altura: int = 3
## Textura 16x16 de cada bloquinho. Vazio = assets/blocos4.png.
@export var textura: Texture2D

## Px que ele desce. 0 = mede sozinho até o primeiro chão embaixo.
@export var distancia_queda: float = 0.0
## Limite do raio de medição automática (px).
@export var alcance_max: float = 480.0

@export var tempo_espera_cima: float = 1.4
@export var tempo_aviso: float = 0.35
@export var tempo_no_chao: float = 0.6
@export var gravidade_queda: float = 2600.0
@export var vel_max_queda: float = 900.0
@export var vel_subida: float = 60.0
## Atraso antes do 1º ciclo -- pra vários esmagadores lado a lado baterem
## fora de sincronia.
@export var atraso_inicial: float = 0.0
## Força da tremida de câmera no impacto (0 = sem).
@export var tremida: float = 3.0

static var _material_brilho: CanvasItemMaterial

var _estado := Estado.ESPERA_CIMA
var _timer := 0.0
var _vel := 0.0
var _y_cima := 0.0
var _y_chao := 0.0
var _visual: Node2D
var _zona_esmaga: Area2D

func _ready() -> void:
	if textura == null:
		textura = load("res://assets/blocos4.png")
	if _material_brilho == null:
		_material_brilho = CanvasItemMaterial.new()
		_material_brilho.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_montar_visual()
	_ajustar_colisao()
	_montar_zona_esmaga()
	_y_cima = position.y
	_timer = tempo_espera_cima + atraso_inicial
	# Espera um frame de física pra tilemap já ter colisão antes de medir.
	await get_tree().physics_frame
	_y_chao = _y_cima + (distancia_queda if distancia_queda > 0.0 else _medir_queda())

func _meia_altura() -> float:
	return altura * TILE * 0.5

## Desce até o primeiro tile embaixo dele -- bloco OU espinho (espinho não tem
## colisão, então um raio passaria direto) -- olhando todas as colunas que o
## esmagador cobre. Sem tilemap embaixo, cai no raio de física (outros corpos).
## Tudo em coordenada local do esmagador (o mapa pode estar escalado, ex. mapa_09
## com scale 3.65), e o resultado sai na mesma unidade de `position`.
func _medir_queda() -> float:
	var base := Vector2(0, _meia_altura())
	var melhor := alcance_max
	for layer in get_tree().current_scene.find_children("*", "TileMapLayer", true, false):
		var tml := layer as TileMapLayer
		if tml.tile_set == null or tml.tile_set.get_physics_layers_count() == 0:
			continue  # decorativa (cristais etc.)
		melhor = minf(melhor, _queda_ate_tile(tml, base))
	# Para quando a PONTA dos espinhos encosta, não a base do bloco.
	return maxf(minf(melhor, _queda_por_raio(base)) - ESPINHO_ALT, 0.0)

## Converte um ponto local deste nó pra célula da tilemap.
func _celula(tml: TileMapLayer, p: Vector2) -> Vector2i:
	return tml.local_to_map(tml.to_local(to_global(p)))

func _queda_ate_tile(tml: TileMapLayer, base: Vector2) -> float:
	var meia_w := largura * TILE * 0.5 - 1.0
	var c_esq := _celula(tml, base + Vector2(-meia_w, 1.0))
	var c_dir := _celula(tml, base + Vector2(meia_w, 1.0))
	var c_fim := _celula(tml, base + Vector2(0, alcance_max))
	for cy in range(c_esq.y, c_fim.y + 1):
		for cx in range(c_esq.x, c_dir.x + 1):
			var cel := Vector2i(cx, cy)
			if tml.get_cell_source_id(cel) == -1:
				continue
			var meio_tile := tml.map_to_local(cel)
			var tam := Vector2(tml.tile_set.tile_size)
			var topo := to_local(tml.to_global(meio_tile - Vector2(0, tam.y * 0.5))).y
			if topo >= base.y - 0.5:
				return topo - base.y
	return alcance_max

func _queda_por_raio(base: Vector2) -> float:
	var ini := to_global(base)
	var fim := to_global(base + Vector2(0, alcance_max))
	var q := PhysicsRayQueryParameters2D.create(ini, fim, 1 | 2)
	var excluir: Array[RID] = [get_rid()]
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject2D:
			excluir.append(p.get_rid())
	q.exclude = excluir
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return alcance_max
	return to_local(hit.position).y - base.y

func _montar_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	var x0 := -largura * TILE * 0.5 + TILE * 0.5
	var y0 := -_meia_altura() + TILE * 0.5
	for y in altura:
		for x in largura:
			var s := Sprite2D.new()
			s.texture = textura
			s.material = _material_brilho
			s.position = Vector2(x0 + x * TILE, y0 + y * TILE)
			_visual.add_child(s)
	# Fileira de espinhos pra baixo na base -- mesmo tile do tileset (source 12,
	# espinho_baixo.png: desenho nas ESPINHO_ALT linhas de cima do tile).
	var tex_espinho: Texture2D = load("res://assets/espinho_baixo.png")
	for x in largura:
		var e := Sprite2D.new()
		e.texture = tex_espinho
		e.material = _material_brilho
		e.position = Vector2(x0 + x * TILE, _meia_altura() + TILE * 0.5)
		_visual.add_child(e)

## Duplica o shape antes de mexer, senão todas as instâncias compartilham ele.
func _ajustar_colisao() -> void:
	var col := $CollisionShape2D as CollisionShape2D
	var forma := (col.shape as RectangleShape2D).duplicate() as RectangleShape2D
	forma.size = Vector2(largura * TILE, altura * TILE)
	col.shape = forma

## Área dos espinhos embaixo da base: encostou = morre, igual espinho da tilemap
## (parado, descendo ou subindo -- e descendo é o esmagamento).
func _montar_zona_esmaga() -> void:
	_zona_esmaga = Area2D.new()
	_zona_esmaga.collision_layer = 0
	_zona_esmaga.collision_mask = 1 | 4
	_zona_esmaga.monitorable = false
	var forma := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(largura * TILE - 2.0, ESPINHO_ALT)
	forma.shape = r
	forma.position = Vector2(0, _meia_altura() + ESPINHO_ALT * 0.5)
	_zona_esmaga.add_child(forma)
	add_child(_zona_esmaga)

func _physics_process(delta: float) -> void:
	_esmagar()
	match _estado:
		Estado.ESPERA_CIMA:
			_timer -= delta
			if _timer <= 0.0:
				_entrar_aviso()
		Estado.AVISO:
			_timer -= delta
			if _timer <= 0.0:
				_visual.position.x = 0.0
				_vel = 0.0
				_estado = Estado.CAINDO
		Estado.CAINDO:
			_vel = minf(_vel + gravidade_queda * delta, vel_max_queda)
			var alvo := position.y + _vel * delta
			if alvo >= _y_chao:
				# Compara antes de gravar: position é float32 e _y_chao float64,
				# então "position.y >= _y_chao" podia nunca dar true e travar.
				position.y = _y_chao
				_impacto()
			else:
				position.y = alvo
		Estado.NO_CHAO:
			_timer -= delta
			if _timer <= 0.0:
				_estado = Estado.SUBINDO
		Estado.SUBINDO:
			var alvo_sub := position.y - vel_subida * delta
			if alvo_sub <= _y_cima:
				position.y = _y_cima
				_estado = Estado.ESPERA_CIMA
				_timer = tempo_espera_cima
			else:
				position.y = alvo_sub

func _entrar_aviso() -> void:
	_estado = Estado.AVISO
	_timer = tempo_aviso
	var tw := create_tween()
	var passos := int(tempo_aviso / 0.05)
	for i in passos:
		tw.tween_property(_visual, "position:x", 1.5 if i % 2 == 0 else -1.5, 0.05)
	tw.tween_property(_visual, "position:x", 0.0, 0.02)

func _esmagar() -> void:
	for body in _zona_esmaga.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(body.max_health)
		elif body.is_in_group("enemy") and body.has_method("die"):
			body.die()

func _impacto() -> void:
	_esmagar()
	_estado = Estado.NO_CHAO
	_timer = tempo_no_chao
	_poeira()
	_tremer_camera()

func _tremer_camera() -> void:
	if tremida <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	# Só treme se o esmagador estiver perto da tela.
	var tela := get_viewport_rect().size / cam.zoom
	if absf(global_position.x - cam.get_screen_center_position().x) > tela.x * 0.75:
		return
	var tw := create_tween()
	for i in 5:
		tw.tween_property(cam, "offset", Vector2(randf_range(-tremida, tremida), randf_range(-tremida, tremida)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)

func _poeira() -> void:
	for lado in [-1.0, 1.0]:
		var po := CPUParticles2D.new()
		po.position = Vector2(lado * largura * TILE * 0.5, _meia_altura())
		po.one_shot = true
		po.explosiveness = 0.95
		po.amount = 10
		po.lifetime = 0.45
		po.direction = Vector2(lado, -0.4)
		po.spread = 30.0
		po.gravity = Vector2(0, 150)
		po.initial_velocity_min = 40.0
		po.initial_velocity_max = 90.0
		po.scale_amount_min = 1.5
		po.scale_amount_max = 3.0
		po.color = Color(0.6, 0.55, 0.5, 0.8)
		add_child(po)
		po.emitting = true
		get_tree().create_timer(0.8).timeout.connect(po.queue_free)
