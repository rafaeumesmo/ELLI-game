extends CharacterBody2D

## Emitido no frame em que o player toca o chão vindo do ar. `impact_speed` é a
## velocity.y de ANTES do move_and_slide() (a que já sai do chão fica ~0, por
## isso é capturada antes). Só pra pendurar efeitos (poeira de pouso etc.) --
## não influencia a física.
signal landed(impact_speed: float)

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var wall_slide_speed: float = 50.0
@export var wall_coyote_time: float = 0.15

## -- Dash --
## Velocidade horizontal fixa mantida do início ao fim do dash.
@export var dash_speed: float = 500.0
## Duração do trecho reto do dash. Pra deixar o dash mais longo, aumente este valor.
@export var dash_duration: float = 0.18
## Tempo mínimo entre o fim de um dash e o início do próximo.
@export var dash_cooldown: float = 0.25
## Janela após o fim do dash em que apertar pular ainda conta como dash-jump.
## Pra alargar a janela do dash-jump, aumente este valor.
@export var dash_jump_window: float = 0.15
## Multiplicador sobre a velocidade horizontal preservada num dash-jump.
## Pra fazer o dash-jump ir mais longe sem alterar o dash em si, aumente este valor.
@export var dash_jump_speed_mult: float = 1.0
## Quão rápido a velocidade extra do dash cai até a velocidade normal de corrida (px/s²).
## Um valor menor faz o dash-jump (e o próprio resíduo do dash) ir mais longe.
@export var dash_decay_speed: float = 1000.0
## Buffer de input do pulo: apertar um pouco antes do momento exato ainda conta.
@export var jump_buffer_time: float = 0.1

const BLOCOSS2_SOURCE_ID := 9
@export var max_health: int = 4
@export var bullet_scene: PackedScene = preload("res://Weapons/Bullet.tscn")
@export var fire_cooldown: float = 0.35
@export var shake_strength: float = 8.0
@export var shake_duration: float = 0.3

## Golpe de espada (corpo-a-corpo). Substitui o tiro assim que o player pega a espada.
@export var attack_cooldown: float = 0.4
@export var attack_damage: int = 1
## Alcance do golpe à frente do player e tamanho da zona de acerto (px).
@export var attack_reach: float = 14.0
@export var attack_box: Vector2 = Vector2(34, 28)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var gun_sprite: Sprite2D = $GunSprite
@onready var camera: Camera2D = $Camera2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var last_dir: String = "D"
var last_wall_side: int = 0
var wall_coyote_timer: float = 0.0
var wall_coyote_side: int = 0
var health: int = max_health
var has_gun: bool = false
var tem_espada: bool = false
var fire_timer: float = 0.0
## Enquanto > 0, o input horizontal não controla o player (empurrão de boss etc).
var knockback_timer: float = 0.0
## Enquanto > 0, o corpo mostra a animação de golpe (atk_A / atk_D).
var attack_timer: float = 0.0
## Espelha o `sticking_to_wall` local do _physics_process -- exposto só pra
## outros nós (poeira de parede etc.) lerem o mesmo estado que já escolhe o
## sprite wall_A/wall_D. Não influencia a física.
var is_wall_sliding: bool = false
## Duração da animação de golpe (3 quadros a 14 fps ≈ 0.21s + folga).
const ATTACK_ANIM_TIME := 0.24

## -- Estado do dash --
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
## Direção travada no início do dash (-1 ou 1). Virar no meio não muda nada.
var dash_direction: float = 1.0
## Enquanto > 0, um pulo ainda é tratado como dash-jump (preserva velocity.x).
var dash_grace_timer: float = 0.0
## Um dash por vez no ar; recarrega ao tocar o chão ou agarrar numa parede.
var can_dash_air: bool = true
## O player já desbloqueou o dash? Começa desligado -- alguma fase futura
## chama `desbloquear_dash()` (mesmo esquema da espada, ver `tem_espada`).
var dash_desbloqueado: bool = false
## Guarda um "pular" apertado até ~jump_buffer_time atrás, pro dash-jump não
## exigir timing perfeito.
var jump_buffer_timer: float = 0.0

static var _death_particle_texture: ImageTexture

func _ready() -> void:
	add_to_group("player")
	# Espada já commitada num checkpoint (ou fase anterior): começa com ela, sem o pop.
	if SaveManager.tem_espada:
		equip_gun(false)
	if SaveManager.tem_dash:
		dash_desbloqueado = true
	# Cenas ainda no esquema antigo (troca de cena): current_scene É a fase,
	# então o checkpoint dela já pode ser aplicado aqui. Sob o Mundo
	# (mundo.gd), quem chama ao_entrar_na_tela() é o próprio Mundo -- ver
	# comentário lá; current_scene seria o Mundo, não a tela.
	if get_tree().get_first_node_in_group("gerenciador") != null:
		return
	var scene_path := get_tree().current_scene.scene_file_path
	if SaveManager.has_checkpoint(scene_path):
		global_position = SaveManager.checkpoint_position
		_apply_checkpoint_camera(get_tree().current_scene)

## Chamado sempre que o Elísio "entra" numa tela: pela primeira vez (Mundo
## carregando a tela_inicial), ao subir de tela (subir_tela) ou ao recarregar
## depois de morrer (recarregar_tela). Extraído do antigo _ready() -- que só
## rodava uma vez, quando cada fase era sua própria cena com o player dentro.
func ao_entrar_na_tela(tela: Node2D) -> void:
	if SaveManager.has_checkpoint(tela.scene_file_path):
		global_position = SaveManager.checkpoint_position
		_apply_checkpoint_camera(tela)

func _apply_checkpoint_camera(tela: Node) -> void:
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	if mundo != null:
		# Sob o Mundo, checkpoint_camera_path aponta pra um Marker2D (âncora)
		# dentro da tela, não pra uma Camera2D irmã.
		if SaveManager.checkpoint_camera_path != "":
			var ancora := tela.get_node_or_null(SaveManager.checkpoint_camera_path) as Marker2D
			if ancora:
				var zoom: Vector2 = tela.zoom_camera if "zoom_camera" in tela else Vector2(0.9, 0.9)
				mundo.ancorada(ancora, zoom, true)
				return
		mundo.seguir_jogador(true)
		return
	# Esquema antigo: liga a Camera2D certa dentro da própria cena da fase.
	var fixed_camera: Camera2D = null
	if SaveManager.checkpoint_camera_path != "":
		fixed_camera = tela.get_node_or_null(SaveManager.checkpoint_camera_path) as Camera2D
	for node in tela.find_children("*", "Camera2D", true, false):
		(node as Camera2D).enabled = false
	if fixed_camera:
		fixed_camera.enabled = true
	else:
		camera.enabled = true

func equip_gun(com_efeito: bool = true) -> void:
	has_gun = true
	_equipar_espada(com_efeito)

## Libera o dash pro player. Chamado por um pickup/gatilho de fase (ainda não
## existe nenhum -- é só a permissão; a fase que desbloqueia decide o efeito).
func desbloquear_dash() -> void:
	dash_desbloqueado = true

## Marca o player como armado. Fora do golpe o corpo NÃO muda de sprite — a espada
## só aparece na animação de ataque (atk_A / atk_D). Com `com_efeito` faz um "pop"
## de transição (pickup); sem, é a restauração silenciosa do save.
func _equipar_espada(com_efeito: bool = true) -> void:
	if tem_espada:
		return
	tem_espada = true
	if is_instance_valid(gun_sprite):
		gun_sprite.queue_free()
	if not com_efeito:
		return

	sprite.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.35, 1.35), 0.1)
	tw.parallel().tween_property(sprite, "modulate", Color(4, 4, 4), 0.1)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.3)

## Joga o player numa direção e suspende o controle horizontal por `duration`.
func apply_knockback(vel: Vector2, duration: float = 0.18) -> void:
	velocity = vel
	knockback_timer = maxf(knockback_timer, duration)

func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	_play_damage_flash()
	_shake_camera()
	if health <= 0:
		die()

func _play_damage_flash() -> void:
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(sprite, "modulate", Color(1, 0.25, 0.25), 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

## Recupera vida (padrao: cura total). Chamado ao ativar um checkpoint novo.
func heal(amount: int = max_health) -> void:
	if health >= max_health:
		return
	health = min(health + amount, max_health)
	_play_heal_flash()

func _play_heal_flash() -> void:
	var tween := create_tween()
	for i in range(2):
		tween.tween_property(sprite, "modulate", Color(0.4, 1.4, 0.55), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

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

func die() -> void:
	# Se o caracol bebe ja tinha morrido, essa morte trava a lapide dele de vez.
	if SaveManager.bebe_morto:
		SaveManager.marcar_lapide_bebe()
	_spawn_death_particles()
	visible = false
	set_physics_process(false)
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	var scene_path: String = get_tree().current_scene.scene_file_path
	if mundo != null:
		scene_path = mundo.tela_atual_scene_path()
	if SaveManager.has_checkpoint(scene_path):
		# Caracois / blocos que morreram DEPOIS do checkpoint voltam ao renascer.
		SaveManager.descartar_pendentes()
		if mundo != null:
			mundo.recarregar_tela()
		else:
			get_tree().reload_current_scene()
		return
	var death_menu := get_tree().get_first_node_in_group("death_menu")
	if death_menu:
		death_menu.show_death()

func _spawn_death_particles() -> void:
	if _death_particle_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		_death_particle_texture = ImageTexture.create_from_image(image)

	var particles := CPUParticles2D.new()
	# Parented to the tree root (not current_scene) and always-processing so
	# the burst survives both the instant checkpoint reload and the pause
	# triggered by the death menu.
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.texture = _death_particle_texture
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.7
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = Color(1, 0.3, 0.3)

	get_tree().root.add_child(particles)
	particles.global_position = global_position
	particles.z_index = 100
	particles.emitting = true

	var timer := get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(particles.queue_free)

func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()  # pra detectar pouso (transição ar -> chão)
	var direction: float = Input.get_axis("move_left", "move_right")

	if is_on_floor():
		last_wall_side = 0
		wall_coyote_timer = 0.0
		can_dash_air = true  # recarrega o dash aéreo ao tocar o chão

	var wall_side: int = sign(get_wall_normal().x) if is_on_wall() else 0
	var wall_double_stick: bool = is_on_wall() and _wall_allows_double_stick()

	if is_on_wall() and not is_on_floor():
		wall_coyote_timer = wall_coyote_time
		wall_coyote_side = wall_side
	elif wall_coyote_timer > 0.0:
		wall_coyote_timer -= delta

	var sticking_to_wall: bool = (
		is_on_wall()
		and not is_on_floor()
		and _is_pressing_into_wall(direction)
		and (wall_side != last_wall_side or wall_double_stick)
	)
	is_wall_sliding = sticking_to_wall  # exposto pra poeira de parede
	if sticking_to_wall:
		can_dash_air = true  # recarrega o dash aéreo ao agarrar numa parede

	# -- Timers do dash e do buffer de pulo (correm sempre, dash ativo ou não) --
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if dash_grace_timer > 0.0:
		dash_grace_timer -= delta
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	# -- Início do dash --
	if (
		dash_desbloqueado
		and Input.is_action_just_pressed("dash")
		and not is_dashing
		and dash_cooldown_timer <= 0.0
		and (is_on_floor() or can_dash_air)
	):
		_start_dash(direction)

	if is_dashing:
		# Reto, direção travada, sem gravidade -- ver bloco de gravidade abaixo.
		velocity.x = dash_direction * dash_speed
		dash_timer -= delta
		if dash_timer <= 0.0:
			_end_dash()

	if is_dashing:
		velocity.y = 0.0
	elif sticking_to_wall:
		velocity.y = min(velocity.y + gravity * delta, wall_slide_speed)
	elif not is_on_floor():
		velocity.y += gravity * delta

	if is_dashing:
		pass  # velocity.x já foi travado acima
	elif knockback_timer > 0.0:
		knockback_timer -= delta
	elif absf(velocity.x) > speed:
		# Resíduo do dash (ou de um dash-jump) decaindo até a corrida normal.
		velocity.x = move_toward(velocity.x, direction * speed, dash_decay_speed * delta)
	else:
		velocity.x = direction * speed

	if jump_buffer_timer > 0.0 and (is_dashing or dash_grace_timer > 0.0):
		# Dash-jump: cancela o dash e pula preservando a velocidade horizontal.
		var preserved_vx: float = velocity.x
		_end_dash()
		velocity.y = jump_velocity
		velocity.x = preserved_vx * dash_jump_speed_mult
		jump_buffer_timer = 0.0
		dash_grace_timer = 0.0
	elif Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
		elif wall_coyote_timer > 0.0 and wall_coyote_side != last_wall_side:
			velocity.y = jump_velocity
			last_wall_side = wall_coyote_side
			wall_coyote_timer = 0.0

	var pre_slide_vy := velocity.y  # impacto do pouso é medido ANTES do slide
	move_and_slide()
	if not was_on_floor and is_on_floor():
		landed.emit(pre_slide_vy)

	# Dash não atravessa parede: se colidiu batendo no dash, encerra aqui
	# (checado só DEPOIS do move_and_slide, senão pegaria o "grudado" de
	# antes de sair de uma parede que o player estava agarrando).
	if is_dashing and is_on_wall():
		_end_dash()

	_update_animation(direction, sticking_to_wall)
	_update_weapon(delta)

## Começa o dash: trava a direção (a do input, ou a última encarada se nenhuma
## tecla estiver pressionada) e consome a carga aérea se estiver no ar.
func _start_dash(input_direction: float) -> void:
	var dir := input_direction
	if dir == 0.0:
		dir = -1.0 if last_dir == "A" else 1.0
	dash_direction = sign(dir)
	is_dashing = true
	dash_timer = dash_duration
	if not is_on_floor():
		can_dash_air = false

## Encerra o dash (fim natural, colisão com parede, ou cancelado por um
## dash-jump) e liga o cooldown + a janela de graça do dash-jump.
func _end_dash() -> void:
	if not is_dashing:
		return
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = dash_cooldown
	dash_grace_timer = dash_jump_window

func _update_weapon(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
	if attack_timer > 0.0:
		attack_timer -= delta

	# Com a espada equipada, "shoot" (K / clique) vira golpe corpo-a-corpo.
	if tem_espada:
		if fire_timer <= 0.0 and Input.is_action_just_pressed("shoot"):
			_swing()
		return

	if not has_gun:
		return

	var to_mouse: Vector2 = get_global_mouse_position() - gun_sprite.global_position
	var angle: float = to_mouse.angle()
	if abs(angle) > PI / 2.0:
		gun_sprite.rotation = angle + PI
		gun_sprite.flip_v = true
	else:
		gun_sprite.rotation = angle
		gun_sprite.flip_v = false

	if fire_timer <= 0.0 and Input.is_action_just_pressed("shoot"):
		_shoot(to_mouse.normalized())

## Golpe de espada: zona de acerto retangular à frente do player, ativa por 1 frame.
## Bate em quem está no grupo "enemy" (take_damage se tiver, senão die()).
func _swing() -> void:
	fire_timer = attack_cooldown
	var dir: float = -1.0 if last_dir == "A" else 1.0
	var center: Vector2 = global_position + Vector2(dir * attack_reach, -2.0)
	var hitbox := Rect2(center - attack_box * 0.5, attack_box)

	_play_attack(dir)

	var acertou := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var p: Vector2 = (enemy as Node2D).global_position
		# Trata o inimigo como uma caixa em volta da origem (origem costuma ficar
		# nos pés, então a caixa puxa pra cima). Bem mais tolerante que testar 1 ponto.
		var alvo := Rect2(p - Vector2(16, 22), Vector2(32, 32))
		if not hitbox.intersects(alvo):
			continue
		var corpo: Vector2 = p + Vector2(0, -8)
		if enemy.has_method("take_damage"):
			# take_damage pode devolver false = golpe não contou (blindado, i-frame…).
			if enemy.take_damage(attack_damage) == false:
				_spawn_hit_spark(corpo)
				continue
		elif enemy.has_method("die"):
			enemy.die()
		acertou = true
		_spawn_hit_slash(corpo, dir)

	if acertou:
		_shake_camera()
		# Flash branco de impacto.
		sprite.modulate = Color(3, 3, 3)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.18)

## Animação de golpe do corpo (atk_A / atk_D — corpo + espada + risco já no sprite).
## Fica no ar sem `flip_h` porque o desenho já está na orientação certa (123 = D,
## 456 = A). `_update_animation` deixa ela rodar enquanto `attack_timer > 0`.
func _play_attack(dir: float) -> void:
	last_dir = "A" if dir < 0.0 else "D"
	attack_timer = ATTACK_ANIM_TIME
	sprite.flip_h = false
	sprite.play("atk_" + last_dir)

## Marca de corte no inimigo acertado: um risco diagonal branco que dá um pop e
## some rápido, em cima do corpo dele. Parenteado à cena (não ao inimigo) pra
## sobreviver se ele morrer no golpe.
func _spawn_hit_slash(at: Vector2, dir: float) -> void:
	var marca := Node2D.new()
	marca.z_index = 30
	marca.rotation = -0.5 * dir + randf_range(-0.3, 0.3)
	get_tree().current_scene.add_child(marca)
	marca.global_position = at

	var comprimento := 11.0
	for camada in 2:
		var risco := Line2D.new()
		risco.begin_cap_mode = Line2D.LINE_CAP_ROUND
		risco.end_cap_mode = Line2D.LINE_CAP_ROUND
		risco.add_point(Vector2(-comprimento, 0))
		risco.add_point(Vector2(comprimento, 0))
		if camada == 0:
			risco.width = 7.0
			risco.default_color = Color(1.0, 0.6, 0.7, 0.5)
		else:
			risco.width = 2.5
			risco.default_color = Color(1, 1, 1, 1)
		marca.add_child(risco)

	marca.scale = Vector2(0.4, 0.8)
	var tw := create_tween()
	tw.tween_property(marca, "scale", Vector2(1.3, 1.0), 0.16) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(marca, "modulate:a", 0.0, 0.16)
	tw.tween_callback(marca.queue_free)

## Faísca de "blindado": o golpe pegou mas não contou. Estrelinha branca curta.
func _spawn_hit_spark(at: Vector2) -> void:
	var faisca := Node2D.new()
	faisca.z_index = 30
	faisca.rotation = randf_range(0.0, PI)
	get_tree().current_scene.add_child(faisca)
	faisca.global_position = at

	for i in 4:
		var risco := Line2D.new()
		risco.begin_cap_mode = Line2D.LINE_CAP_ROUND
		risco.end_cap_mode = Line2D.LINE_CAP_ROUND
		risco.width = 2.0
		risco.default_color = Color(1, 1, 1, 0.9)
		var ang := i * PI / 2.0
		var v := Vector2(cos(ang), sin(ang))
		risco.add_point(v * 2.0)
		risco.add_point(v * 7.0)
		faisca.add_child(risco)

	faisca.scale = Vector2.ONE * 0.5
	var tw := create_tween()
	tw.tween_property(faisca, "scale", Vector2.ONE * 1.4, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(faisca, "modulate:a", 0.0, 0.12)
	tw.tween_callback(faisca.queue_free)

func _shoot(aim_dir: Vector2) -> void:
	fire_timer = fire_cooldown
	var bullet := bullet_scene.instantiate()
	bullet.direction = aim_dir
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = gun_sprite.global_position + aim_dir * 8.0

func _wall_allows_double_stick() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var normal: Vector2 = collision.get_normal()
		if absf(normal.x) <= 0.5:
			continue
		var collider: Object = collision.get_collider()
		if collider is Node and collider.is_in_group("double_stick_wall"):
			return true
		if collider is TileMapLayer:
			var local_pos: Vector2 = collider.to_local(collision.get_position() - normal * 4.0)
			var cell: Vector2i = collider.local_to_map(local_pos)
			if collider.get_cell_source_id(cell) == BLOCOSS2_SOURCE_ID:
				return true
	return false

func _is_pressing_into_wall(direction: float) -> bool:
	return direction != 0 and sign(direction) == -sign(get_wall_normal().x)

## Frame em que a corrida "congela" enquanto o player está no ar (pulo/queda).
const AIR_FREEZE_FRAME := 1

func _update_animation(direction: float, wall_sliding: bool) -> void:
	# Golpe em andamento: deixa a animação de ataque terminar sem interrupção.
	if attack_timer > 0.0:
		return

	if direction < 0:
		last_dir = "A"
	elif direction > 0:
		last_dir = "D"

	# Grudado na parede: sprite dedicado (wall_A / wall_D), 1 quadro só. O desenho
	# já está na orientação certa (esquerda encara a esquerda), então sem flip.
	if wall_sliding:
		sprite.flip_h = false
		sprite.play("wall_" + last_dir)
		return

	sprite.flip_h = true

	# No ar sem parede: não temos sprite de pulo, então a corrida congela num
	# quadro só em vez de ficar mexendo as perninhas.
	if not is_on_floor():
		var anim := "run_" + last_dir
		if sprite.animation != anim:
			sprite.animation = anim
		sprite.frame = AIR_FREEZE_FRAME
		sprite.pause()
		return

	if direction != 0:
		sprite.play("run_" + last_dir)
	else:
		sprite.play("idle_" + last_dir)
