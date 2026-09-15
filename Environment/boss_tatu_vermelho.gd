extends CharacterBody2D

## COURAÇA — Boss 1 de ELLI (UNDERSTORY). Implementação da FASE 1 da spec.
##
## Ele é cego e caça por vibração. Todo barulho que o Elli faz NO CHÃO
## sobrescreve `_last_known_x`; a Couraça sempre mira nesse valor, nunca na
## posição real do player. Chão é barulho, parede é silêncio — o jogador tem
## que se expor de propósito (aterrissar) pra criar a janela de dano.
##
## Máquina de estados (fase 1):
##   PATRULHA ──chegou no alvo / silêncio──▶ ESCUTA
##   PATRULHA ──aterrissagem perto──▶ ROLAMENTO
##   ESCUTA   ──qualquer barulho──▶ ROLAMENTO   │  ──silêncio──▶ PATRULHA (vira)
##   ROLAMENTO ──bateu na parede──▶ ATORDOADO   │  ──sem parede──▶ PATRULHA
##   ATORDOADO ──janela acaba──▶ LEVANTAR ──▶ PATRULHA
##   SACUDIDA entra por proximidade (anti-turtle), nunca durante o ATORDOADO.
##
## Ponto fraco: a BARRIGA, exposta só no ATORDOADO e só do lado OPOSTO à parede
## em que ele bateu. Cada acerto encurta a janela restante em `greed_penalty`.
##
## Ainda NÃO implementado (fases 2/3): Escavar, Tremor, troca de fase, carapaça
## de verdade pisável (hoje o corpo tem exceção de colisão com o player).

const TILE := 16.0

enum State { PATROL, LISTEN, WINDUP, CHARGE, IMPACT, STUNNED, RECOVER, SHAKE }

# ---- Ritmo / timings (fase 1) ----
@export var patrol_speed: float = 90.0
@export var roll_speed: float = 380.0
@export var listen_time: float = 0.8
## Enrolar (0,2) + Tensão (0,3). É o tell do rolamento.
@export var windup_time: float = 0.5
@export var impact_time: float = 0.15
@export var stun_time: float = 2.5
@export var recover_time: float = 0.4
@export var shake_windup_time: float = 0.4
## Pausa mínima entre o fim de uma habilidade e o começo da próxima.
@export var ability_gap: float = 1.2
## Silêncio (s) que manda a Couraça pra Escuta.
@export var listen_after_silence: float = 3.0
## Silêncio (s) a partir do qual ela entra em patrulha cega (não para mais).
@export var blind_after_silence: float = 6.0

# ---- Vibração ----
## Alcance (tiles) do barulho de corrida contínua no chão.
@export var run_hear_tiles: float = 12.0
## Alcance (tiles) do barulho de pulo a partir do chão.
@export var jump_hear_tiles: float = 10.0
## Queda (tiles) que conta como aterrissagem pesada ("sala inteira").
@export var hard_fall_tiles: float = 3.0

# ---- Dano ----
@export var roll_damage: int = 1
@export var roll_knockback: Vector2 = Vector2(260, -140)
@export var max_hits_per_phase: int = 3
## Quanto cada acerto na barriga encurta o atordoamento restante.
@export var greed_penalty: float = 0.3

# ---- Espinho ----
@export var spike_scene: PackedScene = preload("res://Environment/EspinhoTatu.tscn")
@export var spike_scale: float = 2.0
## Distância percorrida na patrulha entre um espinho e o próximo.
@export var spike_every_px: float = 60.0
## Não solta espinho se já houver um a menos de tanto (evita empilhar).
@export var spike_min_gap_px: float = 32.0
## Frames do espinho: broto inofensivo → ativo → murchando.
@export var spike_sprout_time: float = 0.3
@export var spike_active_time: float = 8.0
@export var spike_wither_time: float = 0.5
## Teto de espinhos vivos; passou disso, o mais antigo murcha.
@export var spike_cap: int = 24

# ---- Tremor de tela ----
@export var shake_strength: float = 10.0
@export var shake_duration: float = 0.35
@export var shake_margin: float = 96.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var killzone: Area2D = $Killzone
@onready var head: Area2D = $Head

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var state: int = State.PATROL
var _t: float = 0.0                  # cronômetro do estado atual
var _since_ability: float = 0.0      # tempo desde o fim da última habilidade
var _stun_left: float = 0.0

var _last_known_x: float = 0.0
var _silence: float = 0.0
var _facing: int = 1                 # 1 = direita, -1 = esquerda
var _roll_dir: int = 1
var _belly_side: int = 1             # lado exposto no atordoamento
var _rolls_in_a_row: int = 0

var _hits_this_phase: int = 0
var _killzone_hit: bool = false
var _dist_since_spike: float = 0.0
var _close_timer: float = 0.0
var _charge_time: float = 0.0

# rastreio do player pra inferir a vibração
var _p_was_on_floor: bool = true
var _p_apex_y: float = 0.0

var _spikes: Array[Node] = []
var _belly_tw: Tween

static var _death_particle_texture: ImageTexture


func _ready() -> void:
	add_to_group("enemy")
	killzone.body_entered.connect(_on_killzone_body_entered)
	killzone.body_exited.connect(_on_killzone_body_exited)
	head.body_entered.connect(_on_head_body_entered)

	var p := _player()
	if p:
		# O player compartilha o bit "parede"; sem a exceção o move_and_slide da
		# Couraça briga com ele todo frame que se sobrepõem. Pisar em cima é
		# simulado pela área Head.
		add_collision_exception_with(p)
		_last_known_x = p.global_position.x
		_p_apex_y = p.global_position.y
	else:
		_last_known_x = global_position.x

	_facing = -1 if _last_known_x < global_position.x else 1
	_since_ability = ability_gap
	_enter(State.PATROL)


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	_t += delta
	_since_ability += delta
	_silence += delta

	_sense_player()
	_run_state(delta)
	_check_shake_trigger(delta)

	move_and_slide()

	if state == State.CHARGE:
		_charge_time += delta
		_shred_spikes_in_path()
		if is_on_wall():
			_enter(State.IMPACT)
		elif _charge_time > 0.15 and not is_on_floor():
			_abort_charge()        # passou por cima de um buraco
		elif _charge_time > 4.0:
			_abort_charge()        # não achou parede nenhuma
	elif state == State.PATROL and _silence >= blind_after_silence and is_on_wall():
		_facing = -_facing         # patrulha cega: bateu na parede, volta


# ------------------------------------------------------------------ vibração

func _sense_player() -> void:
	var p := _player()
	if p == null:
		return

	var px: float = p.global_position.x
	var py: float = p.global_position.y
	var on_floor: bool = p.is_on_floor()
	var on_shell: bool = _player_on_shell(p)
	var dx: float = absf(px - global_position.x)

	if not on_floor:
		_p_apex_y = minf(_p_apex_y, py)

	# aterrissou no chão → barulho ALTO, sala inteira
	if on_floor and not _p_was_on_floor:
		if not on_shell:
			var drop: float = maxf(py - _p_apex_y, 0.0)
			_hear(px, true)
			if drop >= hard_fall_tiles * TILE:
				_silence = 0.0   # queda longa corta a Escuta na hora
		_p_apex_y = py
	elif on_floor:
		_p_apex_y = py

	# pulo a partir do chão → barulho médio, alcance menor
	if _p_was_on_floor and not on_floor and p.velocity.y < -50.0 and not on_shell:
		if dx <= jump_hear_tiles * TILE:
			_hear(px, false)

	# corrida contínua no chão → barulho médio dentro do alcance
	if on_floor and not on_shell and absf(p.velocity.x) > 20.0:
		if dx <= run_hear_tiles * TILE:
			_hear(px, false)

	_p_was_on_floor = on_floor


## Quem aterrissa em cima da carapaça não faz barulho (a casca absorve).
func _player_on_shell(p: Node2D) -> bool:
	return absf(p.global_position.x - global_position.x) < 44.0 \
		and p.global_position.y < global_position.y - 40.0


func _hear(x: float, high: bool) -> void:
	_last_known_x = x
	_silence = 0.0
	if state == State.LISTEN:
		_start_roll()
	elif state == State.PATROL and high \
			and _since_ability >= ability_gap and _rolls_in_a_row < 3:
		_start_roll()


# ------------------------------------------------------------------ estados

func _run_state(delta: float) -> void:
	match state:
		State.PATROL:
			_state_patrol(delta)

		State.LISTEN:
			velocity.x = 0.0
			_anim("idle")
			if _t >= listen_time:
				# Silêncio: vira pro lado oposto e sai varrendo o chão pra lá.
				_facing = -_facing
				_last_known_x = global_position.x + _facing * 8.0 * TILE
				_enter(State.PATROL)

		State.WINDUP:
			velocity.x = 0.0
			_anim("roll")
			if _t >= windup_time:
				_enter(State.CHARGE)

		State.CHARGE:
			velocity.x = _roll_dir * roll_speed
			_anim("roll")

		State.IMPACT:
			velocity.x = 0.0
			if _t >= impact_time:
				_enter(State.STUNNED)

		State.STUNNED:
			velocity.x = 0.0
			_anim("idle")
			_stun_left -= delta
			if _stun_left <= 0.0:
				_enter(State.RECOVER)

		State.RECOVER:
			velocity.x = 0.0
			_anim("idle")
			if _t >= recover_time:
				_since_ability = 0.0
				_facing = -1 if _last_known_x < global_position.x else 1
				_enter(State.PATROL)

		State.SHAKE:
			velocity.x = 0.0
			_anim("idle")
			if _t >= shake_windup_time:
				_do_shake_spikes()
				_since_ability = 0.0
				_enter(State.PATROL)


func _state_patrol(delta: float) -> void:
	_anim("idle")

	if _t > 3.0:
		_rolls_in_a_row = 0

	var blind: bool = _silence >= blind_after_silence
	var to_target: float = _last_known_x - global_position.x

	if not blind and (absf(to_target) <= 4.0 or _silence >= listen_after_silence):
		_enter(State.LISTEN)
		return

	var dir: int = _facing if blind else (-1 if to_target < 0.0 else 1)
	_facing = dir
	velocity.x = dir * patrol_speed

	_dist_since_spike += absf(velocity.x) * delta
	if _dist_since_spike >= spike_every_px:
		_dist_since_spike = 0.0
		_try_drop_spike(global_position.x)


func _start_roll() -> void:
	_killzone_hit = false
	_enter(State.WINDUP)


func _abort_charge() -> void:
	# Sem parede no fim: volta pra patrulha sem abrir janela nenhuma.
	_rolls_in_a_row += 1
	_since_ability = 0.0
	velocity.x = 0.0
	_enter(State.PATROL)


func _enter(s: int) -> void:
	state = s
	_t = 0.0
	match s:
		State.CHARGE:
			_roll_dir = -1 if _last_known_x < global_position.x else 1
			_facing = _roll_dir
			_charge_time = 0.0
			_killzone_hit = false
		State.IMPACT:
			_rolls_in_a_row += 1
			_shake_camera()
		State.STUNNED:
			_belly_side = -_roll_dir       # parede à esquerda → barriga à direita
			_stun_left = stun_time
			_start_belly_pulse()
		State.RECOVER:
			_stop_belly_pulse()


# ------------------------------------------------------------------ dano

## Só a barriga fere, e só do lado oposto à parede. Devolve false quando o golpe
## pegou na carapaça / fora do atordoamento (aí o player vê só a faísca de blindado).
func take_damage(_amount: int) -> bool:
	if state != State.STUNNED:
		return false
	var p := _player()
	if p:
		var side: float = signf(p.global_position.x - global_position.x)
		if side != 0.0 and int(side) != _belly_side:
			return false
	_hits_this_phase += 1
	_stun_left -= greed_penalty            # ganância custa janela
	_play_damage_flash()
	if _hits_this_phase >= max_hits_per_phase:
		# Fase 1 é a única implementada: 3 acertos derrubam.
		die()
	return true


func die() -> void:
	_stop_belly_pulse()
	_clear_spikes()
	_spawn_death_particles()
	queue_free()


func _on_killzone_body_entered(body: Node) -> void:
	if state != State.CHARGE or _killzone_hit:
		return
	if not body.is_in_group("player"):
		return
	# Quem está em cima da carapaça não toma o rolo.
	if body.global_position.y < global_position.y - 40.0:
		return
	_killzone_hit = true
	if body.has_method("take_damage"):
		body.take_damage(roll_damage)
	# Knockback sempre pro lado oposto à parede que ele vai bater (centro da sala).
	var kb := Vector2(-_roll_dir * roll_knockback.x, roll_knockback.y)
	if body.has_method("apply_knockback"):
		body.apply_knockback(kb, 0.2)
	elif body is CharacterBody2D:
		body.velocity = kb


func _on_killzone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_killzone_hit = false


func _on_head_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# Carapaça é dura: não dá nem toma dano, só um quique seco pra não dar pra
	# ficar parado em cima esperando.
	if body is CharacterBody2D and body.velocity.y > 0.0:
		body.velocity.y = -160.0


func _play_damage_flash() -> void:
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(sprite, "modulate", Color(1, 0.25, 0.25), 0.06)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.06)


# ------------------------------------------------------------------ sacudida

func _check_shake_trigger(delta: float) -> void:
	if state != State.PATROL and state != State.LISTEN:
		_close_timer = 0.0
		return
	var p := _player()
	if p and p.is_on_floor() \
			and absf(p.global_position.x - global_position.x) < 2.0 * TILE:
		_close_timer += delta
		if _close_timer >= 1.5 and _since_ability >= ability_gap:
			_close_timer = 0.0
			_enter(State.SHAKE)
	else:
		_close_timer = 0.0


func _do_shake_spikes() -> void:
	for off in [-2.0 * TILE, 0.0, 2.0 * TILE]:
		_spawn_spike(global_position.x + off)


# ------------------------------------------------------------------ espinho

func _try_drop_spike(x: float) -> void:
	var p := _player()
	if p and p.is_on_floor() and absf(x - p.global_position.x) < TILE * 0.5:
		return                              # nunca no tile onde o Elli pisa
	for s in _spikes:
		if is_instance_valid(s) and absf(s.global_position.x - x) < spike_min_gap_px:
			return                          # já tem um espinho perto
	_spawn_spike(x)


func _spawn_spike(x: float) -> void:
	var scene := get_tree().current_scene
	if spike_scene == null or scene == null:
		return

	var spike := spike_scene.instantiate()
	scene.add_child(spike)
	spike.global_position = Vector2(x, global_position.y + 6.0)
	if spike is Node2D:
		spike.scale = Vector2(spike_scale, spike_scale)

	var base_y: float = spike.position.y
	spike.position.y = base_y + 6.0 * spike_scale   # broto: enterrado, translúcido
	spike.modulate = Color(1, 1, 1, 0.4)
	if spike is Area2D:
		spike.monitoring = false

	_spikes.append(spike)
	get_tree().create_timer(spike_sprout_time).timeout.connect(
		_activate_spike.bind(spike, base_y))
	get_tree().create_timer(spike_sprout_time + spike_active_time).timeout.connect(
		_wither_spike.bind(spike))

	while _spikes.size() > spike_cap:
		var oldest: Node = _spikes.pop_front()
		if is_instance_valid(oldest):
			_wither_spike(oldest)


func _activate_spike(spike: Node, base_y: float) -> void:
	if not is_instance_valid(spike) or spike.has_meta("withering"):
		return
	if spike is Area2D:
		spike.set_deferred("monitoring", true)
	var tw := spike.create_tween()
	tw.tween_property(spike, "modulate", Color.WHITE, 0.1)
	tw.parallel().tween_property(spike, "position:y", base_y, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _wither_spike(spike: Node) -> void:
	if not is_instance_valid(spike) or spike.has_meta("withering"):
		return
	spike.set_meta("withering", true)
	_spikes.erase(spike)
	if spike is Area2D:
		spike.set_deferred("monitoring", false)
	var tw := spike.create_tween()
	tw.tween_property(spike, "modulate:a", 0.0, spike_wither_time)
	tw.tween_callback(spike.queue_free)


func _shred_spikes_in_path() -> void:
	for s in _spikes.duplicate():
		if is_instance_valid(s) \
				and absf(s.global_position.x - global_position.x) < 44.0:
			_spikes.erase(s)
			s.queue_free()


func _clear_spikes() -> void:
	for s in _spikes:
		if is_instance_valid(s):
			s.queue_free()
	_spikes.clear()


# ------------------------------------------------------------------ apresentação

func _anim(kind: String) -> void:
	if sprite.sprite_frames == null:
		return
	var want: String = kind + ("_D" if _facing > 0 else "_A")
	if sprite.sprite_frames.has_animation(want) \
			and (sprite.animation != want or not sprite.is_playing()):
		sprite.play(want)


func _start_belly_pulse() -> void:
	_stop_belly_pulse()
	sprite.scale = Vector2(0.9, 1.0)            # "bola aberta": mais baixa
	_belly_tw = create_tween().set_loops()
	_belly_tw.tween_property(sprite, "modulate", Color(1.5, 1.15, 0.5), 0.18)
	_belly_tw.tween_property(sprite, "modulate", Color.WHITE, 0.18)


func _stop_belly_pulse() -> void:
	if _belly_tw and _belly_tw.is_valid():
		_belly_tw.kill()
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE


func _shake_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not _visible_on_camera(cam):
		return
	var steps := 6
	var tween := create_tween()
	for i in steps:
		var off := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		tween.tween_property(cam, "offset", off, shake_duration / steps)
	tween.tween_property(cam, "offset", Vector2.ZERO, shake_duration / steps)


func _visible_on_camera(cam: Camera2D) -> bool:
	var view_size := get_viewport_rect().size / cam.zoom
	var view_rect := Rect2(cam.get_screen_center_position() - view_size * 0.5, view_size)
	return view_rect.grow(shake_margin).has_point(global_position)


func _spawn_death_particles() -> void:
	if _death_particle_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		_death_particle_texture = ImageTexture.create_from_image(image)

	var particles := CPUParticles2D.new()
	particles.texture = _death_particle_texture
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.9, 0.2, 0.2)

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = true

	var timer := get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(particles.queue_free)
