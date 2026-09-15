extends TileMapLayer

const PORTAL_SOURCE_ID := 2
const CRUMBLE_SOURCE_ID := 4
const EXPLOSIVE_SOURCE_ID := 0
## Tiles de espinho: pinta na camada Blocos que nem um bloco normal.
## 11 = espinho apontando pra cima, 12 = espinho apontando pra baixo.
const SPIKE_SOURCE_IDS := [11, 12]
const SPIKE_DAMAGE := 2
const SPIKE_DAMAGE_INTERVAL := 0.5
## Pontos amostrados ao redor da origem do inimigo (corpo do tatu: centro ~ (0,5), raio 11).
const ENEMY_SPIKE_CHECKS := [
	Vector2(0, 5),
	Vector2(0, 15),
	Vector2(0, -5),
	Vector2(-9, 5),
	Vector2(9, 5),
]
const TELEPORT_COOLDOWN := 0.5
const CRUMBLE_DELAY := 0.35
const FUSE_DELAY := 0.4
const FEET_OFFSET := 10

const CENTER_Y := 2.0
const HALF_WIDTH := 5.0
const HALF_HEIGHT := 6.0
const TOUCH_MARGIN := 2.0

var _teleport_cooldown: float = 0.0
var _spike_cooldown: float = 0.0
var _crumbling: Dictionary = {}
var _exploding: Dictionary = {}
var _dead_enemies: Dictionary = {}

func _ready() -> void:
	# Blocos quebrados antes do checkpoint atual comecam ja destruidos.
	var scene_path := owner.scene_file_path if owner else ""
	for cell in SaveManager.celulas_quebradas(scene_path):
		set_cell(cell, -1)
		_crumbling[cell] = true
		_exploding[cell] = true

func _physics_process(delta: float) -> void:
	if _teleport_cooldown > 0.0:
		_teleport_cooldown -= delta
	if _spike_cooldown > 0.0:
		_spike_cooldown -= delta

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var local_pos: Vector2 = to_local(player.global_position)

	if _spike_cooldown <= 0.0 and _touching_spike(local_pos) and player.has_method("take_damage"):
		player.take_damage(SPIKE_DAMAGE)
		_spike_cooldown = SPIKE_DAMAGE_INTERVAL

	# take_damage pode ter matado o player e disparado reload da cena; nesse caso
	# este no ja esta saindo da arvore e get_tree() volta null.
	if get_tree() == null:
		return

	_check_enemy_spikes()

	var feet_cell: Vector2i = local_to_map(local_pos + Vector2(0, FEET_OFFSET))
	if _teleport_cooldown <= 0.0 and get_cell_source_id(feet_cell) == PORTAL_SOURCE_ID:
		_teleport(player, feet_cell)

	var touch_offsets := [
		Vector2(0, CENTER_Y + HALF_HEIGHT + TOUCH_MARGIN), # baixo
		Vector2(0, CENTER_Y - HALF_HEIGHT - TOUCH_MARGIN), # cima
		Vector2(-(HALF_WIDTH + TOUCH_MARGIN), CENTER_Y), # esquerda
		Vector2(HALF_WIDTH + TOUCH_MARGIN, CENTER_Y), # direita
	]
	for offset in touch_offsets:
		var cell: Vector2i = local_to_map(local_pos + offset)
		var cell_source_id := get_cell_source_id(cell)
		if cell_source_id == CRUMBLE_SOURCE_ID and not _crumbling.get(cell, false):
			_crumbling[cell] = true
			_start_crumble(cell)
		elif cell_source_id == EXPLOSIVE_SOURCE_ID and not _exploding.get(cell, false):
			_exploding[cell] = true
			_start_explosion(cell, player)

func _teleport(player: Node, current_cell: Vector2i) -> void:
	var destination_cell := _find_other_portal(current_cell)
	if destination_cell == current_cell:
		return
	var top_of_tile: Vector2 = map_to_local(destination_cell) - Vector2(0, 8)
	player.global_position = to_global(top_of_tile) - Vector2(0, FEET_OFFSET)
	_teleport_cooldown = TELEPORT_COOLDOWN

func _find_other_portal(current_cell: Vector2i) -> Vector2i:
	for cell in get_used_cells():
		if cell != current_cell and get_cell_source_id(cell) == PORTAL_SOURCE_ID:
			return cell
	return current_cell

func _touching_spike(local_pos: Vector2) -> bool:
	var checks := [
		Vector2(0, CENTER_Y),
		Vector2(0, CENTER_Y + HALF_HEIGHT),
		Vector2(0, CENTER_Y - HALF_HEIGHT),
		Vector2(-HALF_WIDTH, CENTER_Y),
		Vector2(HALF_WIDTH, CENTER_Y),
	]
	for offset in checks:
		var cell: Vector2i = local_to_map(local_pos + offset)
		if SPIKE_SOURCE_IDS.has(get_cell_source_id(cell)):
			return true
	return false

## Inimigos (tatu etc.) morrem ao encostar num tile de espinho.
func _check_enemy_spikes() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("die"):
			continue
		if _dead_enemies.get(enemy.get_instance_id(), false):
			continue
		var enemy_local: Vector2 = to_local(enemy.global_position)
		for offset in ENEMY_SPIKE_CHECKS:
			var cell: Vector2i = local_to_map(enemy_local + offset)
			if SPIKE_SOURCE_IDS.has(get_cell_source_id(cell)):
				_dead_enemies[enemy.get_instance_id()] = true
				enemy.die()
				break

## Destroi a celula e avisa o SaveManager (pra ela nao voltar depois do checkpoint).
func _quebrar_celula(cell: Vector2i) -> void:
	set_cell(cell, -1)
	SaveManager.registrar_bloco_quebrado(cell)

func _start_crumble(cell: Vector2i) -> void:
	await get_tree().create_timer(CRUMBLE_DELAY).timeout
	if not is_inside_tree():
		return
	_quebrar_celula(cell)

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
