extends TileMapLayer

const CRUMBLE_SOURCE_ID := 4
const CRUMBLE_SOURCE_IDS := [CRUMBLE_SOURCE_ID]
const EXPLOSIVE_SOURCE_ID := 0
## Tile "blocos3" (blocos3.png): parede solida normal. Quebra em qualquer
## toque do player, independente da forca/velocidade -- checado no loop de
## touch_offsets abaixo que nem CRUMBLE/EXPLOSIVE. O dash tem um caminho
## extra (ver player.gd::_quebrar_blocos3_no_caminho / quebrar_blocos3_no_caminho
## abaixo) que quebra a fileira toda ANTES do move_and_slide, pra ele nunca
## chegar a colidir de verdade com a parede (nao precisa "grudar" nela).
const DASH_BREAK_SOURCE_ID := 2
## Tiles de espinho: pinta na camada Blocos que nem um bloco normal.
## 11 = espinho apontando pra cima, 12 = espinho apontando pra baixo.
const SPIKE_SOURCE_IDS := [11, 12]
## Os desenhos dos espinhos so ocupam parte do tile: o pra cima (espinho.png)
## as linhas de baixo, o pra baixo (espinho_baixo.png) as de cima. O resto do
## tile e vazio e nao deve machucar.
const SPIKE_UP_SOURCE_ID := 11
const SPIKE_DOWN_SOURCE_ID := 12
## HITBOX DOS ESPINHOS DA TILEMAP (vale pra todos os mapas; tile = 16x16 px).
## Altura que machuca, contada a partir da base do espinho (0 = nao machuca, 16 = tile todo).
const SPIKE_UP_DRAWN_HEIGHT := 10.0
const SPIKE_DOWN_DRAWN_HEIGHT := 10.0
## Largura que machuca, centralizada no tile (16 = tile todo).
const SPIKE_WIDTH := 16.0
const SPIKE_DAMAGE_INTERVAL := 0.5
## Pontos amostrados ao redor da origem do inimigo (corpo do tatu: centro ~ (0,5), raio 11).
const ENEMY_SPIKE_CHECKS := [
	Vector2(0, 5),
	Vector2(0, 15),
	Vector2(0, -5),
	Vector2(-9, 5),
	Vector2(9, 5),
]
const FUSE_DELAY := 0.4

## Bloco fisico que substitui a celula "blocos5" ao ser tocada -- mesmo
## pisca+cai+quebra do BlocoFragil (ver bloco_que_cai.gd), so que disparado
## por encostar no tile em vez de uma instancia fixa no mapa.
const CRUMBLE_QUEDA_SCENE := preload("res://Environment/BlocoQueCai.tscn")
const CRUMBLE_TEXTURA := preload("res://assets/blocos5.png")

const CENTER_Y := 2.0
const HALF_WIDTH := 5.0
const HALF_HEIGHT := 6.0
const TOUCH_MARGIN := 2.0
const TOUCH_OFFSETS := [
	Vector2(0, CENTER_Y + HALF_HEIGHT + TOUCH_MARGIN),
	Vector2(0, CENTER_Y - HALF_HEIGHT - TOUCH_MARGIN),
	Vector2(-(HALF_WIDTH + TOUCH_MARGIN), CENTER_Y),
	Vector2(HALF_WIDTH + TOUCH_MARGIN, CENTER_Y),
]
const SPIKE_CHECKS := [
	Vector2(0, CENTER_Y),
	Vector2(0, CENTER_Y + HALF_HEIGHT),
	Vector2(0, CENTER_Y - HALF_HEIGHT),
	Vector2(-HALF_WIDTH, CENTER_Y),
	Vector2(HALF_WIDTH, CENTER_Y),
]

@export var shake_strength: float = 6.0
@export var shake_duration: float = 0.2
## Bordas de pedra e musgo estáticos; pode desligar no Inspector.
@export var acabamento_rochas: bool = true

var _spike_cooldown: float = 0.0
var _crumbling: Dictionary = {}
var _exploding: Dictionary = {}
var _dead_enemies: Dictionary = {}
var _tem_espinhos: bool = false

func _ready() -> void:
	add_to_group("blocos_layer")
	if acabamento_rochas:
		var acabamento := Node2D.new()
		acabamento.name = "AcabamentoRochas"
		acabamento.use_parent_material = true
		acabamento.set_script(preload("res://Environment/acabamento_blocos.gd"))
		add_child(acabamento)
	# Blocos quebrados antes do checkpoint atual comecam ja destruidos.
	var scene_path := owner.scene_file_path if owner else ""
	for cell in SaveManager.celulas_quebradas(scene_path):
		# Blocos que caem são temporários, inclusive em saves anteriores.
		if get_cell_source_id(cell) in CRUMBLE_SOURCE_IDS:
			continue
		set_cell(cell, -1)
		_crumbling[cell] = true
		_exploding[cell] = true
	# O jogo só remove tiles durante a fase. Sem espinhos, não precisa
	# percorrer todos os inimigos e amostrar seus cinco pontos a cada tick.
	for source_id in SPIKE_SOURCE_IDS:
		if not get_used_cells_by_id(source_id).is_empty():
			_tem_espinhos = true
			break

func _physics_process(delta: float) -> void:
	if _spike_cooldown > 0.0:
		_spike_cooldown -= delta

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var local_pos: Vector2 = to_local(player.global_position)

	if _tem_espinhos and _spike_cooldown <= 0.0 and _touching_spike(local_pos) and player.has_method("take_damage"):
		player.take_damage(player.max_health)
		_spike_cooldown = SPIKE_DAMAGE_INTERVAL

	# take_damage pode ter matado o player e disparado reload da cena; nesse caso
	# este no ja esta saindo da arvore e get_tree() volta null.
	if get_tree() == null:
		return

	if _tem_espinhos:
		_check_enemy_spikes()

	for offset in TOUCH_OFFSETS:
		var cell: Vector2i = local_to_map(local_pos + offset)
		var cell_source_id := get_cell_source_id(cell)
		if cell_source_id in CRUMBLE_SOURCE_IDS and not _crumbling.get(cell, false):
			_crumbling[cell] = true
			_start_crumble(cell)
		elif cell_source_id == EXPLOSIVE_SOURCE_ID and not _exploding.get(cell, false):
			_exploding[cell] = true
			_start_explosion(cell, player)
		elif cell_source_id == DASH_BREAK_SOURCE_ID:
			_quebrar_bloco_dash(cell)
			_shake_camera()

func _touching_spike(local_pos: Vector2) -> bool:
	for offset in SPIKE_CHECKS:
		if _is_spike_at(local_pos + offset):
			return true
	return false

## Se o ponto (local) cai na parte desenhada de um tile de espinho.
func _is_spike_at(point: Vector2) -> bool:
	var cell: Vector2i = local_to_map(point)
	var source_id := get_cell_source_id(cell)
	if not SPIKE_SOURCE_IDS.has(source_id):
		return false
	var half_tile: float = tile_set.tile_size.y / 2.0
	# Ponto relativo ao centro do tile, desfazendo o giro/espelho que o editor
	# aplicou na celula (Z/X/ctrl no editor de tilemap) -- assim a hitbox gira
	# junto com o desenho. A Godot desenha: transpose, depois flip_h, depois flip_v;
	# aqui desfaz na ordem contraria.
	var rel: Vector2 = point - map_to_local(cell)
	var alt := get_cell_alternative_tile(cell)
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_V:
		rel.y = -rel.y
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_H:
		rel.x = -rel.x
	if alt & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
		rel = Vector2(rel.y, rel.x)
	if absf(rel.x) > SPIKE_WIDTH / 2.0:
		return false
	if source_id == SPIKE_UP_SOURCE_ID:
		return half_tile - rel.y < SPIKE_UP_DRAWN_HEIGHT
	if source_id == SPIKE_DOWN_SOURCE_ID:
		return rel.y + half_tile < SPIKE_DOWN_DRAWN_HEIGHT
	return true

## Inimigos (tatu etc.) morrem ao encostar num tile de espinho.
func _check_enemy_spikes() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("die"):
			continue
		if _dead_enemies.get(enemy.get_instance_id(), false):
			continue
		var enemy_local: Vector2 = to_local(enemy.global_position)
		for offset in ENEMY_SPIKE_CHECKS:
			if _is_spike_at(enemy_local + offset):
				_dead_enemies[enemy.get_instance_id()] = true
				enemy.die()
				break

## Destroi a celula e avisa o SaveManager (pra ela nao voltar depois do checkpoint).
func _quebrar_celula(cell: Vector2i) -> void:
	set_cell(cell, -1)
	SaveManager.registrar_bloco_quebrado(cell)

## Troca a celula "blocos5" por um BlocoQueCai de verdade na mesma posicao,
## ja com pisca_antes_de_cair + quebra_ao_pousar ligados: pisca, cai reto e
## quebra ao pousar no chao -- igual ao BlocoFragil, so que nascendo de um tile.
func _start_crumble(cell: Vector2i) -> void:
	var pos := map_to_local(cell)
	var atlas := tile_set.get_source(get_cell_source_id(cell)) as TileSetAtlasSource
	var textura_queda: Texture2D = atlas.texture if atlas != null else CRUMBLE_TEXTURA
	# O corpo permanece responsável por cair e reaparecer; não salva destruição.
	set_cell(cell, -1)
	var bloco := CRUMBLE_QUEDA_SCENE.instantiate()
	bloco.lado = 1
	bloco.textura = textura_queda
	bloco.pisca_antes_de_cair = true
	bloco.quebra_ao_pousar = true
	bloco.cai_ao_pisar = true
	bloco.position = pos
	add_child(bloco)
	bloco.derrubar()

## Chamado pelo player (ver player.gd::_quebrar_blocos3_no_caminho) a cada
## frame do dash, ANTES do move_and_slide. Olha "alcance" px na frente da
## borda do player, na direcao do dash; se cair num blocos3, quebra ele e
## encadeia na mesma direcao enquanto houver mais empilhados, pro dash
## atravessar a fileira toda de uma vez em vez de trombar no primeiro bloco.
## Devolve true se quebrou algo.
func quebrar_blocos3_no_caminho(player_global_pos: Vector2, direcao_x: int, alcance: float) -> bool:
	var borda := player_global_pos + Vector2((HALF_WIDTH + alcance) * direcao_x, CENTER_Y)
	var cell: Vector2i = local_to_map(to_local(borda))
	if get_cell_source_id(cell) != DASH_BREAK_SOURCE_ID:
		return false
	var passo := Vector2i(direcao_x, 0)
	var atual := cell
	while get_cell_source_id(atual) == DASH_BREAK_SOURCE_ID:
		_quebrar_bloco_dash(atual)
		atual += passo
	return true

func _shake_camera() -> void:
	var active_camera: Camera2D = get_viewport().get_camera_2d()
	if active_camera == null:
		return
	var steps := 6
	var tween := create_tween()
	for i in range(steps):
		var offset := Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		tween.tween_property(active_camera, "offset", offset, shake_duration / steps)
	tween.tween_property(active_camera, "offset", Vector2.ZERO, shake_duration / steps)

## Quebra na hora, sem cair nem explodir -- so poeira, pro dash sentir "impacto".
func _quebrar_bloco_dash(cell: Vector2i) -> void:
	_quebrar_celula(cell)
	_spawn_dash_break_particles(cell)

func _spawn_dash_break_particles(cell: Vector2i) -> void:
	var particles := CPUParticles2D.new()
	particles.position = map_to_local(cell)
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 14
	particles.lifetime = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 100.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 110.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(0.6, 0.55, 0.5, 0.8)
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)

func _start_explosion(cell: Vector2i, player: Node) -> void:
	await get_tree().create_timer(FUSE_DELAY).timeout
	if not is_inside_tree():
		return
	_spawn_explosion_particles(cell)
	var neighbors := [
		cell,
		cell + Vector2i(0, -1),
		cell + Vector2i(0, 1),
		cell + Vector2i(-1, 0),
		cell + Vector2i(1, 0),
	]
	for neighbor in neighbors:
		_quebrar_celula(neighbor)
	# Dano por ultimo: se matar o player, die() ja limpou os pendentes acima e o
	# codigo aqui acabou (nada re-registra a quebra depois do descarte).
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(player.max_health / 2)

func _spawn_explosion_particles(cell: Vector2i) -> void:
	var particles := CPUParticles2D.new()
	particles.position = map_to_local(cell)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 0.5, 0.1)
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)
