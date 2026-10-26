extends Node2D
## RAINHA DAS MEDUSAS -- perseguidora do mapa_10, no espírito do Oshiro do
## Celeste: não precisa (nem dá pra) matar. Ela persegue a Elli pela fase
## atravessando paredes, e a Elli tem que chegar no vagalume-portal do fim
## antes de ser alcançada. Encostar no sino dela ou ser atingida por qualquer
## ataque dela (tentáculo, bola elétrica, mini, mergulho) = morte na hora.
##
## Tudo desenhado em código (_draw no corpo, e um nó filho aditivo `_fx` pros
## raios, bolas elétricas e brilhos).
##
## Começo: coloque o nó onde a perseguição deve começar. Quando a Elli passa
## desse x, a Rainha surge por trás dela (de fora da tela, à esquerda) e vem.
## Renascendo num checkpoint mais à frente, ela surge de novo por trás.
##
## Durante a perseguição, de tempos em tempos (só perto da Elli):
##   TENTÁCULOS  -- linhas fracas de aviso e depois tentáculos elétricos
##                  esticados em várias direções (um mira a Elli). Param na parede.
##   BOLAS       -- acumula luz e dispara um leque de bolas elétricas na
##                  direção da Elli. Estouram na parede.
##   INVOCAR     -- MiniAguaVivas entram pela borda da tela à frente e cruzam
##                  em direção à Elli (dá pra quicar nelas).
##   MERGULHO    -- se posiciona em cima da Elli, treme e despenca até o chão.
##                  Esmaga quem estiver embaixo; depois fica um instante
##                  atordoada no chão -- a brecha pra abrir distância.
## Golpe de espada ou pisão nela: ela recua um pouco (não morre). Pisão
## também quica a Elli. Atordoada no chão ela é um trampolim: encostar joga
## a Elli pra cima dela e pisar só quica, sem matar nem tirar ela do chão.
## Quando a Elli pega o vagalume-portal, a Rainha desiste e some.
##
## Coordenadas: tudo no espaço local do PAI (o mapa), pra funcionar com o
## scale do mapa. Player é convertido com get_parent().to_local().

## Largura e altura do sino (px locais).
@export var largura: float = 72.0
@export var altura_sino: float = 46.0
@export var cor_corpo: Color = Color(1.0, 0.62, 0.9, 0.38)
@export var cor_brilho: Color = Color(1.0, 0.55, 0.88)
@export var cor_eletrica: Color = Color(0.65, 0.88, 1.0)

@export_group("Perseguição")
## Velocidade normal (px locais/s). A Elli correndo faz ~71.
@export var velocidade: float = 55.0
## Velocidade extra quando ela ficou muito pra trás (some aos poucos de
## `distancia_folga` até `distancia_folga` + 200).
@export var velocidade_extra_longe: float = 45.0
@export var distancia_folga: float = 140.0
## De quão longe (atrás da Elli) ela surge ao começar.
@export var distancia_entrada: float = 210.0
## Altura da base do sino em relação à Elli enquanto segue (negativo = base
## abaixo dela, ou seja, o sino vem pra cima dela e engole -- é a pegada).
@export var altura_sobre_player: float = -20.0

@export_group("Ritmo")
## Pausa entre um ataque e outro.
@export var intervalo_ataques: float = 2.6
## Só ataca com a Elli a essa distância ou menos.
@export var alcance_ataques: float = 220.0
@export var mergulho_a_cada: int = 3
@export var tempo_atordoada: float = 1.6
## Atordoada no chão ela fica mole: encostar nela joga a Elli pra cima até
## passar esse tanto (px locais) acima do topo do sino, pra cair pisando.
## O sino é mais alto que o pulo da Elli, então é assim que dá pra subir.
@export var folga_quique_lateral: float = 10.0

@export_group("Tentáculos")
@export var tentaculos: int = 5
@export var alcance_tentaculo: float = 200.0
@export var aviso_tentaculo: float = 0.7

@export_group("Bolas elétricas")
## Quantas bolas por disparo (em leque, a do meio mira a Elli).
@export var bolas: int = 3
## Abertura do leque inteiro, em graus.
@export var leque_bolas: float = 40.0
## Quantos disparos seguidos por ataque.
@export var disparos: int = 2
@export var velocidade_bola: float = 90.0
@export var raio_bola: float = 4.0
## Segundos até a bola apagar sozinha (se não bater em parede antes).
@export var vida_bola: float = 4.0

@export_group("Invocar")
@export var mini_scene: PackedScene = preload("res://Environment/MiniAguaViva.tscn")
@export var minis: int = 3
## Velocidade das minis atravessando (px locais/s).
@export var velocidade_minis: float = 60.0

@export_group("Mergulho")
@export var velocidade_mergulho: float = 420.0
## Velocidade (globais) que joga o player pra cima ao pisar nela.
@export var quique: float = 480.0
@export var quique_segurando_pulo: float = 600.0

enum E { DORMENTE, ENTRADA, PERSEGUIR, TENTACULOS, BOLAS, INVOCAR, MIRAR, TREMER, MERGULHAR, ATORDOADA, SUBIR, RECUAR, PARTIR }

const PES_PLAYER := 8.0
const MEIA_LARGURA_PLAYER := 5.0
const N_FIOS := 10
const N_BRACOS := 4

var _e: int = E.DORMENTE
var _tempo: float = 0.0
var _t: float = 0.0
var _ataque_anterior: int = -1
var _ataques_sem_mergulho: int = 0
var _prox_ataque: float = 0.0
var _contracao: float = 0.0
var _carga: float = 0.0
var _iframes: float = 0.0
var _cd_ferir: float = 0.0
var _cd_lancar: float = 0.0
var _vel := Vector2.ZERO
var _chao_y: float = 0.0
var _mira_x: float = 0.0
var _disparos_restantes: int = 0
var _minis_restantes: int = 0
var _prox_mini: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tw_escala: Tween
var _fases_fios := PackedFloat32Array()

## Tentáculos elétricos: {dir: Vector2, max: float, len: float}
var _raios: Array[Dictionary] = []
## Bolas elétricas, no espaço do mapa: {p: Vector2, v: Vector2, vida: float}
var _bolas: Array[Dictionary] = []
var _minis: Array = []

var _fx: Node2D
var _halo: Sprite2D
var _nucleo: Node2D

## Alvo da espada: o golpe do player procura nós do grupo "enemy" e testa
## uma caixinha em volta da posição deles. Esse nó fica sempre no ponto do
## sino mais perto do player, então dá pra acertar o sino em qualquer lugar.
class Nucleo extends Node2D:
	var rainha: Node
	func take_damage(amount: int) -> bool:
		return rainha.take_damage(amount)

func _ready() -> void:
	_rng.seed = hash(str(get_instance_id()) + str(Time.get_ticks_usec()))
	for i in N_FIOS + N_BRACOS:
		_fases_fios.append(_rng.randf_range(0.0, TAU))

	_halo = Sprite2D.new()
	_halo.texture = preload("res://Environment/luz_vagalume.tres")
	_halo.material = _material_aditivo()
	_halo.show_behind_parent = true
	_halo.position = Vector2(0, -altura_sino * 0.45)
	_halo.self_modulate = Color(cor_brilho, 0.12)
	_halo.scale = Vector2.ONE * 0.75
	add_child(_halo)

	_fx = Node2D.new()
	_fx.material = _material_aditivo()
	_fx.z_index = 2
	_fx.draw.connect(_desenhar_fx)
	add_child(_fx)

	_nucleo = Nucleo.new()
	_nucleo.rainha = self
	add_child(_nucleo)

	# Escondida até a perseguição começar.
	visible = false

func _material_aditivo() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return mat

# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	_t += delta
	_tempo += delta
	_iframes = maxf(_iframes - delta, 0.0)
	_cd_ferir = maxf(_cd_ferir - delta, 0.0)
	_cd_lancar = maxf(_cd_lancar - delta, 0.0)
	_contracao = move_toward(_contracao, 0.0, delta * 1.8)

	if _e != E.DORMENTE and _e != E.PARTIR and _portal_pego():
		_partir()

	match _e:
		E.DORMENTE: _st_dormente()
		E.ENTRADA: _st_entrada(delta)
		E.PERSEGUIR: _st_perseguir(delta)
		E.TENTACULOS: _st_tentaculos(delta)
		E.BOLAS: _st_bolas(delta)
		E.INVOCAR: _st_invocar(delta)
		E.MIRAR: _st_mirar(delta)
		E.TREMER: _st_tremer()
		E.MERGULHAR: _st_mergulhar(delta)
		E.ATORDOADA: _st_atordoada()
		E.SUBIR: _st_subir(delta)
		E.RECUAR: _st_recuar(delta)
		E.PARTIR: pass

	_atualizar_bolas(delta)
	if _e != E.DORMENTE and _e != E.PARTIR:
		_checar_player()
	_atualizar_nucleo()

	var brilho: float = 0.12 + 0.1 * _contracao + 0.25 * _carga + 0.03 * sin(_t * 2.0)
	if _e == E.ATORDOADA:
		brilho *= 0.5
	_halo.self_modulate.a = brilho
	queue_redraw()
	_fx.queue_redraw()

func _entrar(estado: int) -> void:
	_e = estado
	_tempo = 0.0

# ---------------------------------------------------------------- estados

func _st_dormente() -> void:
	var p := _player()
	if p == null or _pos_player(p).x < position.x:
		return
	# Surge por trás da Elli, de fora da tela.
	position = _pos_player(p) + Vector2(-distancia_entrada, -altura_sobre_player - 30.0)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
	_contracao = 1.0
	_entrar(E.ENTRADA)

func _st_entrada(delta: float) -> void:
	_seguir(delta, 1.0)
	if fmod(_tempo, 0.5) < delta:
		_contracao = 1.0
	if _tempo >= 1.2:
		_prox_ataque = intervalo_ataques
		_entrar(E.PERSEGUIR)

func _st_perseguir(delta: float) -> void:
	_seguir(delta, 1.0)
	if fmod(_t, 1.2) < delta:
		_contracao = 1.0
	_prox_ataque -= delta
	var p := _player()
	if _prox_ataque <= 0.0 and p != null and position.distance_to(_pos_player(p)) <= alcance_ataques:
		_escolher_ataque()

## Vai na direção de um ponto um pouco acima da Elli. `mult` desacelera
## durante os ataques. Atravessa paredes de propósito.
func _seguir(delta: float, mult: float) -> void:
	var p := _player()
	if p == null:
		return
	var alvo := _pos_player(p) + Vector2(0, -altura_sobre_player)
	var falta := alvo - position
	var dist := falta.length()
	var v: float = velocidade + velocidade_extra_longe * clampf((dist - distancia_folga) / 200.0, 0.0, 1.0)
	var desejada := falta.normalized() * v * mult if dist > 1.0 else Vector2.ZERO
	# Desliza com inércia, como quem nada no ar.
	_vel = _vel.lerp(desejada, clampf(delta * 2.5, 0.0, 1.0))
	position += _vel * delta

func _escolher_ataque() -> void:
	var opcoes := [E.TENTACULOS, E.BOLAS, E.INVOCAR, E.MIRAR]
	var escolhido: int
	if _ataques_sem_mergulho >= mergulho_a_cada - 1:
		escolhido = E.MIRAR
	else:
		opcoes.erase(_ataque_anterior)
		escolhido = opcoes[_rng.randi() % opcoes.size()]
	_ataque_anterior = escolhido
	_ataques_sem_mergulho = 0 if escolhido == E.MIRAR else _ataques_sem_mergulho + 1
	match escolhido:
		E.TENTACULOS: _iniciar_tentaculos()
		E.BOLAS:
			_disparos_restantes = disparos
			_entrar(E.BOLAS)
		E.INVOCAR:
			_minis_restantes = minis
			_prox_mini = 0.4
			_minis = _minis.filter(func(m): return is_instance_valid(m))
			_entrar(E.INVOCAR)
		E.MIRAR: _entrar(E.MIRAR)

func _voltar_a_perseguir() -> void:
	_carga = 0.0
	_prox_ataque = intervalo_ataques
	_entrar(E.PERSEGUIR)

# -- tentáculos elétricos

func _iniciar_tentaculos() -> void:
	_raios.clear()
	var origem := _origem_raios()
	var p := _player()
	var ang_base: float = PI * 0.5
	if p != null:
		ang_base = (_pos_player(p) - origem).angle()
	for i in tentaculos:
		var ang: float = ang_base + TAU * float(i) / tentaculos
		var dir := Vector2.from_angle(ang)
		_raios.append({dir = dir, max = _alcance_ate_parede(origem, dir), len = 0.0})
	_entrar(E.TENTACULOS)

func _st_tentaculos(delta: float) -> void:
	# aviso -> estica (0.15s) -> segura (0.5s) -> recolhe (0.3s). Fica parada
	# pra os raios não mudarem de lugar depois do aviso.
	_vel = _vel.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	position += _vel * delta
	if _tempo < aviso_tentaculo:
		_carga = _tempo / aviso_tentaculo
	for r in _raios:
		if _tempo < aviso_tentaculo:
			r.len = 0.0
		elif _tempo < aviso_tentaculo + 0.15:
			r.len = r.max * (_tempo - aviso_tentaculo) / 0.15
		elif _tempo < aviso_tentaculo + 0.65:
			r.len = r.max
		else:
			r.len = move_toward(r.len, 0.0, r.max / 0.3 * delta)
	if _tempo >= aviso_tentaculo + 0.15 and _tempo < aviso_tentaculo + 0.2:
		_contracao = 1.0
	if _tempo >= aviso_tentaculo + 0.65:
		_carga = move_toward(_carga, 0.0, delta * 3.0)
	if _tempo >= aviso_tentaculo + 0.95:
		_raios.clear()
		_voltar_a_perseguir()

# -- bolas elétricas

func _st_bolas(delta: float) -> void:
	_seguir(delta, 0.3)
	_carga = minf(_carga + delta / 0.7, 1.0)
	if _tempo >= 0.7:
		_contracao = 1.0
		_disparar_bolas()
		_disparos_restantes -= 1
		if _disparos_restantes > 0:
			_tempo = 0.25  # o disparo seguinte carrega mais rápido
			_carga = 0.4
		else:
			_voltar_a_perseguir()

func _disparar_bolas() -> void:
	var origem := position + Vector2(0, -altura_sino * 0.4)
	var p := _player()
	var ang_base: float = PI * 0.5
	if p != null:
		ang_base = (_pos_player(p) - origem).angle()
	for i in bolas:
		var k: float = 0.0 if bolas <= 1 else float(i) / (bolas - 1) - 0.5
		var dir := Vector2.from_angle(ang_base + deg_to_rad(leque_bolas) * k)
		_bolas.append({p = origem + dir * 8.0, v = dir * velocidade_bola, vida = vida_bola})

func _atualizar_bolas(delta: float) -> void:
	for i in range(_bolas.size() - 1, -1, -1):
		var b: Dictionary = _bolas[i]
		b.p += b.v * delta
		b.vida -= delta
		if b.vida <= 0.0:
			_bolas.remove_at(i)
		elif _bate_parede(b.p):
			_faisca(b.p)
			_bolas.remove_at(i)

# -- invocar medusas pequenas

func _st_invocar(delta: float) -> void:
	_seguir(delta, 0.6)
	_carga = minf(_tempo / 0.4, 1.0)
	if _tempo < 0.4:
		return
	if _minis_restantes <= 0:
		_voltar_a_perseguir()
		return
	if _tempo >= _prox_mini:
		_prox_mini = _tempo + 0.35
		_contracao = 1.0
		_soltar_mini()
		_minis_restantes -= 1

## Mini entra pela borda da tela do lado pra onde a Elli está indo (à frente
## dela) e cruza na direção dela.
func _soltar_mini() -> void:
	var p := _player()
	if mini_scene == null or p == null:
		return
	var tela := _tela_local()
	var pp := _pos_player(p)
	var lado: float = 1.0 if pp.x >= position.x else -1.0
	var mini = mini_scene.instantiate()
	var y: float = clampf(pp.y - 10.0 + _rng.randf_range(-35.0, 25.0), tela.position.y + 10.0, tela.end.y - 10.0)
	var x: float = tela.end.x + 8.0 if lado > 0.0 else tela.position.x - 8.0
	mini.position = Vector2(x, y)
	var escala: float = (get_parent() as Node2D).global_scale.x
	mini.travessia = Vector2(-lado * velocidade_minis * escala, 0)
	mini.vida_travessia = tela.size.x / velocidade_minis + 0.5
	get_parent().add_child(mini)
	_minis.append(mini)

# -- mergulho

func _st_mirar(delta: float) -> void:
	# Vai pra cima da Elli.
	var p := _player()
	if p != null:
		_mira_x = _pos_player(p).x
		var alvo := Vector2(_mira_x, _pos_player(p).y - 70.0)
		position = position.lerp(alvo, clampf(delta * 4.0, 0.0, 1.0))
	if _tempo >= 0.7:
		_entrar(E.TREMER)

func _st_tremer() -> void:
	_carga = minf(_tempo / 0.45, 1.0)
	position.x = _mira_x + _rng.randf_range(-1.5, 1.5)
	if _tempo >= 0.45:
		_chao_y = _achar_chao()
		_vel = Vector2.ZERO
		_carga = 0.0
		_contracao = 1.0
		_entrar(E.MERGULHAR)

func _st_mergulhar(delta: float) -> void:
	_vel.y = move_toward(_vel.y, velocidade_mergulho, velocidade_mergulho * 4.0 * delta)
	position.y += _vel.y * delta
	if position.y >= _chao_y:
		position.y = _chao_y
		_vel = Vector2.ZERO
		_tremer_camera(8.0, 0.3)
		_esmagar()
		_entrar(E.ATORDOADA)

func _esmagar() -> void:
	_tween_escala()
	_tw_escala.tween_property(self, "scale", Vector2(1.25, 0.72), 0.08)
	_tw_escala.tween_property(self, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _tween_escala() -> void:
	if _tw_escala != null and _tw_escala.is_valid():
		_tw_escala.kill()
	_tw_escala = create_tween()

func _st_atordoada() -> void:
	if _tempo >= tempo_atordoada:
		_entrar(E.SUBIR)

func _st_subir(delta: float) -> void:
	# Volta a nadar atrás da Elli, devagar no começo.
	_seguir(delta, clampf(_tempo / 0.8, 0.2, 1.0))
	if fmod(_tempo, 0.45) < delta:
		_contracao = 1.0
	if _tempo >= 0.8:
		_voltar_a_perseguir()

# -- recuo (levou golpe)

func _st_recuar(delta: float) -> void:
	_vel = _vel.lerp(Vector2.ZERO, clampf(delta * 3.0, 0.0, 1.0))
	position += _vel * delta
	if _tempo >= 0.7:
		_voltar_a_perseguir()

# -- fim: a Elli pegou o vagalume

func _portal_pego() -> bool:
	for portal in get_tree().get_nodes_in_group("portal_fase"):
		if portal.has_method("foi_pego") and portal.foi_pego():
			return true
	return false

func _partir() -> void:
	_entrar(E.PARTIR)
	_raios.clear()
	for b in _bolas:
		_faisca(b.p)
	_bolas.clear()
	_carga = 0.0
	_contracao = 1.0
	if _nucleo.is_in_group("enemy"):
		_nucleo.remove_from_group("enemy")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 60.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", 0.0, 1.4)

# ---------------------------------------------------------------- player

func _player() -> CharacterBody2D:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if p == null or not p.visible or not p.is_physics_processing():
		return null
	return p

func _pos_player(p: Node2D) -> Vector2:
	return get_parent().to_local(p.global_position)

## Superfície de cima do sino (y local do pai) na coluna x, ou INF fora dele.
func _topo_sino(x: float) -> float:
	var u: float = (x - position.x) / (largura * 0.5 * scale.x)
	if absf(u) > 1.0:
		return INF
	return position.y - altura_sino * scale.y * sqrt(1.0 - u * u)

## Ponto dentro da cúpula do sino (larga embaixo, redonda em cima), com folga.
func _dentro_sino(ponto: Vector2, folga: float) -> bool:
	var meia: float = largura * 0.5 * scale.x
	var dx: float = ponto.x - position.x
	if absf(dx) > meia + folga:
		return false
	var u: float = clampf(dx / meia, -1.0, 1.0)
	var topo: float = position.y - altura_sino * scale.y * sqrt(1.0 - u * u)
	return ponto.y >= topo - folga and ponto.y <= position.y + folga + 2.0

func _checar_player() -> void:
	var p := _player()
	if p == null:
		return
	var pp := _pos_player(p)
	var pes: float = pp.y + PES_PLAYER
	var escala: float = (get_parent() as Node2D).global_scale.y
	var pes_antes: float = pes - p.velocity.y * get_physics_process_delta_time() / escala
	var topo: float = _topo_sino(pp.x)

	# Pisão: no ar, caindo, e os pés cruzaram a superfície de cima do sino.
	# (No chão não conta -- senão o sino deslizando por baixo dos pés de
	# quem tá parado viraria "pisão".)
	if topo != INF and p.velocity.y > 0.0 and not p.is_on_floor() \
			and pes >= topo - 3.0 and pes_antes <= topo + 4.0:
		var forca: float = quique_segurando_pulo if Input.is_action_pressed("jump") else quique
		p.velocity.y = -forca
		if "can_dash_air" in p:
			p.can_dash_air = true
		_cd_ferir = maxf(_cd_ferir, 0.3)
		if _e == E.ATORDOADA:
			# No chão ela é só um trampolim: continua atordoada.
			_contracao = 1.0
		else:
			take_damage(1)
		return

	var centro_p := pp + Vector2(0, 2)
	if _e == E.ATORDOADA:
		_quique_lateral(p, pp, pes, escala, centro_p)
		return
	var inofensiva: bool = _e == E.ATORDOADA or _e == E.SUBIR or _e == E.RECUAR or _e == E.ENTRADA
	# Pega: encostar no sino é o fim da linha.
	if not inofensiva and _dentro_sino(centro_p, MEIA_LARGURA_PLAYER):
		p.die()
		return
	# Despencando: a boca do sino e os tentáculos logo abaixo esmagam.
	if _e == E.MERGULHAR and absf(pp.x - position.x) < largura * 0.45 \
			and pp.y > position.y - altura_sino and pp.y < position.y + 14.0:
		p.die()
		return
	if _cd_ferir > 0.0:
		return
	var origem := _origem_raios()
	for r in _raios:
		if r.len <= 0.0:
			continue
		if _dist_segmento(centro_p, origem, origem + r.dir * r.len) < 4.0 + MEIA_LARGURA_PLAYER:
			_ferir(p, pp)
			return
	for b in _bolas:
		if centro_p.distance_to(b.p) < raio_bola + MEIA_LARGURA_PLAYER:
			_ferir(p, pp)
			return

## Atordoada: encostou no sino (sem ser por cima) -> ela devolve um quique
## que leva a Elli até um pouco acima do topo e cai pisando. Voo inteiro sem
## controle (knockback) pra garantir que caia em cima.
func _quique_lateral(p: CharacterBody2D, pp: Vector2, pes: float, escala: float, centro_p: Vector2) -> void:
	if _cd_lancar > 0.0 or p.velocity.y < -50.0 or not _dentro_sino(centro_p, MEIA_LARGURA_PLAYER):
		return
	var topo: float = position.y - altura_sino * scale.y
	var subir: float = (pes - topo + folga_quique_lateral) * escala
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var v: float = sqrt(2.0 * g * maxf(subir, 1.0))
	# Mira a aterrissagem a meio caminho entre o centro e a borda do sino,
	# do lado onde ela já está.
	var lado: float = signf(pp.x - position.x)
	if lado == 0.0:
		lado = 1.0
	var alvo_x: float = position.x + lado * largura * 0.5 * scale.x * 0.45
	var tempo_voo: float = 2.0 * v / g
	var vx: float = (alvo_x - pp.x) * escala / tempo_voo
	if p.has_method("apply_knockback"):
		p.apply_knockback(Vector2(vx, -v), tempo_voo)
	else:
		p.velocity = Vector2(vx, -v)
	if "can_dash_air" in p:
		p.can_dash_air = true
	_cd_lancar = 0.6
	_contracao = 1.0

func _ferir(p: CharacterBody2D, _pp: Vector2) -> void:
	_cd_ferir = 1.0
	p.die()

func _atualizar_nucleo() -> void:
	var p := _player()
	if p == null or _e == E.PARTIR or _e == E.DORMENTE:
		if _nucleo.is_in_group("enemy"):
			_nucleo.remove_from_group("enemy")
		return
	if not _nucleo.is_in_group("enemy"):
		_nucleo.add_to_group("enemy")
	# Ponto do sino mais perto do player (clamp na elipse).
	var c := Vector2(0, -altura_sino * 0.5)
	var rel: Vector2 = (_pos_player(p) + Vector2(0, -2) - position) / scale - c
	var raio := Vector2(largura * 0.5, altura_sino * 0.5)
	var d := rel / raio
	if d.length() > 1.0:
		rel = d.normalized() * raio
	# A espada testa uma caixa (em px globais) centrada 6px acima da origem
	# do alvo -- compensa pra caixa cair em cima do ponto do sino.
	_nucleo.position = c + rel + Vector2(0, 6.0 / maxf(global_scale.y, 0.01))

# ---------------------------------------------------------------- golpe

## Não tem vida: golpe/pisão só faz ela recuar um pouco, sem atacar.
func take_damage(_amount: int) -> bool:
	if _iframes > 0.0 or _e == E.PARTIR or _e == E.DORMENTE:
		return false
	_iframes = 1.2
	modulate = Color(2.2, 2.0, 2.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)
	_contracao = 1.0
	_raios.clear()
	var p := _player()
	if p != null:
		_vel = (position - _pos_player(p)).normalized() * 90.0
	_entrar(E.RECUAR)
	return true

# ---------------------------------------------------------------- utilidades

func _origem_raios() -> Vector2:
	return position + Vector2(0, -altura_sino * 0.15)

## Retângulo da tela atual em coordenadas locais do mapa.
func _tela_local() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var pai := get_parent() as Node2D
	var tamanho := get_viewport_rect().size
	if cam == null:
		return Rect2(position - tamanho * 0.5 / pai.global_scale, tamanho / pai.global_scale)
	tamanho = tamanho / cam.zoom / pai.global_scale
	var centro := pai.to_local(cam.get_screen_center_position())
	return Rect2(centro - tamanho * 0.5, tamanho)

func _espaco_raycast(de: Vector2, ate: Vector2) -> Dictionary:
	var pai := get_parent() as Node2D
	var q := PhysicsRayQueryParameters2D.create(pai.to_global(de), pai.to_global(ate), 2)
	var p := get_tree().get_first_node_in_group("player") as CollisionObject2D
	if p != null:
		q.exclude = [p.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q)

func _bate_parede(ponto: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = (get_parent() as Node2D).to_global(ponto)
	q.collision_mask = 2
	var p := get_tree().get_first_node_in_group("player") as CollisionObject2D
	if p != null:
		q.exclude = [p.get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()

## Estalinho de faíscas azuis quando uma bola estoura.
func _faisca(ponto: Vector2) -> void:
	var particles := CPUParticles2D.new()
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(img)
	particles.material = _material_aditivo()
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = cor_eletrica
	get_parent().add_child(particles)
	particles.position = ponto
	particles.z_index = 10
	particles.emitting = true
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

func _alcance_ate_parede(origem: Vector2, dir: Vector2) -> float:
	var hit := _espaco_raycast(origem, origem + dir * alcance_tentaculo)
	if hit.is_empty():
		return alcance_tentaculo
	return origem.distance_to(get_parent().to_local(hit.position))

func _achar_chao() -> float:
	var hit := _espaco_raycast(position, position + Vector2(0, 260.0))
	if hit.is_empty():
		return position.y + 120.0
	return get_parent().to_local(hit.position).y - 3.0

func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

func _tremer_camera(forca: float, duracao: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := create_tween()
	for i in 6:
		tw.tween_property(cam, "offset", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), duracao / 6.0)
	tw.tween_property(cam, "offset", Vector2.ZERO, duracao / 6.0)

# ---------------------------------------------------------------- desenho

func _draw() -> void:
	var c: float = _contracao
	var w: float = largura * (1.0 - 0.12 * c)
	var h: float = altura_sino * (1.0 + 0.1 * c)
	var cor_fio := Color(cor_brilho, 0.3)
	var arrasto: float = 0.0
	if _e == E.MERGULHAR:
		arrasto = -1.0  # tentáculos voam pra cima durante a queda

	# Fios longos (atrás do sino).
	for i in N_FIOS:
		var x0: float = lerpf(-w * 0.44, w * 0.44, float(i) / (N_FIOS - 1))
		var comp: float = 48.0 + 14.0 * sin(_fases_fios[i] * 3.0)
		var pts := PackedVector2Array()
		for s in 9:
			var k: float = s / 8.0
			var onda: float = sin(_t * 1.8 - k * 4.0 + _fases_fios[i]) * 4.0 * k
			var y: float = k * comp * (1.0 + 0.6 * arrasto)
			pts.append(Vector2(x0 * (1.0 + 0.2 * k) + onda, y))
		draw_polyline(pts, cor_fio, 1.0)

	# Braços orais: fitas largas e onduladas no meio.
	for i in N_BRACOS:
		var x0: float = lerpf(-w * 0.16, w * 0.16, float(i) / (N_BRACOS - 1))
		var fase: float = _fases_fios[N_FIOS + i]
		var pts := PackedVector2Array()
		for s in 9:
			var k: float = s / 8.0
			var onda: float = sin(_t * 1.3 - k * 3.0 + fase) * 6.0 * k
			pts.append(Vector2(x0 + onda, k * 34.0 * (1.0 + 0.5 * arrasto)))
		draw_polyline(pts, Color(cor_brilho, 0.18), 4.0)
		draw_polyline(pts, Color(1, 0.9, 1, 0.25), 1.0)

	# Sino.
	var passos := 24
	var sino := PackedVector2Array()
	for s in passos + 1:
		var a: float = PI + PI * s / passos
		sino.append(Vector2(cos(a) * w * 0.5, sin(a) * h))
	for s in range(passos, -1, -1):
		var x: float = lerpf(-w * 0.5, w * 0.5, float(s) / passos)
		sino.append(Vector2(x, 2.0 + sin(x * 0.45 + _t * 3.0) * 1.5))
	var cor_sino := cor_corpo
	if _e == E.ATORDOADA:
		cor_sino = Color(cor_corpo.r * 0.75, cor_corpo.g * 0.75, cor_corpo.b * 0.9, cor_corpo.a)
	draw_colored_polygon(sino, cor_sino)

	# Domo interno mais claro.
	var domo := PackedVector2Array()
	for s in passos + 1:
		var a: float = PI + PI * s / passos
		domo.append(Vector2(cos(a) * w * 0.34, sin(a) * h * 0.72 - 2.0))
	draw_colored_polygon(domo, Color(1, 1, 1, 0.1))

	# Trevo de gônadas (as 4 "pétalas" da água-viva-da-lua).
	var cg := Vector2(0, -h * 0.4)
	for i in 4:
		var a: float = TAU * i / 4.0 + PI * 0.25 + sin(_t * 0.5) * 0.1
		draw_circle(cg + Vector2.from_angle(a) * 6.0, 4.2, Color(1.0, 0.5, 0.82, 0.35))
	draw_circle(cg, 3.0, Color(1, 0.85, 0.95, 0.4 + 0.4 * _carga))

	# Contorno brilhante + pontinhos de luz na borda.
	var borda := PackedVector2Array()
	for s in passos + 1:
		var a: float = PI + PI * s / passos
		borda.append(Vector2(cos(a) * w * 0.5, sin(a) * h))
	draw_polyline(borda, Color(cor_brilho, 0.85), 1.5)
	for i in 11:
		var a: float = PI + PI * (i + 0.5) / 11.0
		var pisca: float = 0.5 + 0.5 * sin(_t * 2.5 + i * 0.9)
		draw_rect(Rect2(Vector2(cos(a) * w * 0.47, sin(a) * h * 0.94) - Vector2.ONE * 0.5, Vector2.ONE * 1.5),
				Color(1, 0.95, 1, 0.3 + 0.5 * pisca))

func _desenhar_fx() -> void:
	# Coração aceso enquanto carrega um ataque.
	if _carga > 0.0:
		var cg := Vector2(0, -altura_sino * 0.4)
		_fx.draw_circle(cg, 6.0 + 10.0 * _carga, Color(cor_brilho, 0.12 * _carga))
		_fx.draw_circle(cg, 3.0 + 4.0 * _carga, Color(1, 0.9, 1, 0.35 * _carga))

	# Tentáculos elétricos: linha de aviso fraca, depois o raio em zigue-zague.
	var origem: Vector2 = _origem_raios() - position
	for r in _raios:
		var dir: Vector2 = r.dir
		if r.len <= 0.0:
			var piscar: float = 0.5 + 0.5 * sin(_t * 18.0)
			_fx.draw_line(origem, origem + dir * r.max, Color(cor_eletrica, 0.08 + 0.1 * piscar * _carga), 1.0)
			continue
		var fim: Vector2 = origem + dir * r.len
		var normal := dir.orthogonal()
		var pts := PackedVector2Array()
		var n: int = maxi(int(r.len / 7.0), 2)
		for s in n + 1:
			var k: float = float(s) / n
			var desvio: float = 0.0 if s == 0 or s == n else _rng.randf_range(-2.5, 2.5)
			pts.append(origem.lerp(fim, k) + normal * desvio)
		_fx.draw_polyline(pts, Color(cor_eletrica, 0.25), 5.0)
		_fx.draw_polyline(pts, Color(cor_eletrica, 0.7), 2.0)
		_fx.draw_polyline(pts, Color(1, 1, 1, 0.9), 1.0)
		_fx.draw_circle(fim, 2.5, Color(1, 1, 1, 0.6))

	# Bolas elétricas: miolo branco, halo azul e faísquinhas em volta. Elas
	# vivem no espaço do mapa, então desenha desfazendo o transform da Rainha
	# (senão o achatamento do impacto entortaria as bolas longe dela).
	_fx.draw_set_transform_matrix(transform.affine_inverse())
	for b in _bolas:
		var c: Vector2 = b.p
		var pisca: float = 0.75 + 0.25 * sin(_t * 30.0 + c.x)
		_fx.draw_circle(c, raio_bola * 2.6, Color(cor_eletrica, 0.12 * pisca))
		_fx.draw_circle(c, raio_bola * 1.5, Color(cor_eletrica, 0.35 * pisca))
		_fx.draw_circle(c, raio_bola * 0.8, Color(1, 1, 1, 0.9))
		for k in 3:
			var a: float = _rng.randf_range(0.0, TAU)
			var meio := c + Vector2.from_angle(a + 0.4) * raio_bola * 1.3
			var ponta := c + Vector2.from_angle(a) * raio_bola * _rng.randf_range(1.8, 2.6)
			_fx.draw_polyline(PackedVector2Array([c, meio, ponta]), Color(1, 1, 1, 0.7), 1.0)
	_fx.draw_set_transform_matrix(Transform2D.IDENTITY)
