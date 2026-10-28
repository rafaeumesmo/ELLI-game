extends Node2D
## Água-viva voadora: inimigo sutil que flutua no ar. Pulsa o sino (contrai e
## dá um impulso pra cima, depois afunda devagar), balança os tentáculos e
## brilha com um halo aditivo suave. Quando o player chega perto ela deriva
## lentamente na direção dele, sem nunca se afastar demais de onde foi posta.
## Cair por cima do sino quica a Elli como um trampolim (sem dano; segurando
## pulo quica mais alto). Encostar por baixo/lado mata na hora. Um golpe de
## espada estoura ela num punhado de faíscas que sobem.
##
## Tudo é desenhado em código (_draw) -- não precisa de sprite. Ajusta
## `cor_corpo`/`cor_brilho` pra variar a espécie.
##
## Uso: arraste `AguaViva.tscn` pro mapa.

## Cor do sino (translúcido).
@export var cor_corpo: Color = Color(1.0, 1.0, 1.0, 0.85)
## Cor do brilho (halo aditivo, borda do sino e pontinhos internos).
@export var cor_brilho: Color = Color(1.0, 0.55, 0.85)
## Largura do sino em pixels.
@export var largura: float = 14.0
## Comprimento dos tentáculos em pixels.
@export var comprimento_tentaculo: float = 14.0
## Segundos entre uma pulsada e outra.
@export var periodo_pulso: float = 1.8
## Impulso pra cima de cada pulsada (px/s).
@export var impulso: float = 26.0
## Até onde ela enxerga o player (px).
@export var raio_percepcao: float = 96.0
## Velocidade máxima da deriva na direção do player (px/s).
@export var velocidade_caca: float = 18.0
## Distância máxima da posição inicial (px). Passou disso, volta.
@export var raio_maximo: float = 110.0
## Velocidade pra cima ao quicar na cabeça dela (px/s).
@export var quique: float = 460.0
## Quique segurando o botão de pulo.
@export var quique_segurando_pulo: float = 580.0
## Folga nas bordas superiores para pousos um pouco de lado (pixels locais).
@export_range(0.0, 8.0, 1.0) var margem_quique_lateral: float = 4.0
@export_range(0.0, 8.0, 1.0) var tolerancia_quique_vertical: float = 5.0
## Quantas vezes dá pra quicar nela antes de estourar. 0 = infinito.
## A MiniAguaViva usa 1: quica uma vez e ela estoura.
@export var quiques_max: int = 0
## Encostar mata na hora. Desligado = tira 1 de vida + empurrão (as minis
## que a RainhaMedusas invoca usam assim, pra luta ter margem).
@export var mata_na_hora: bool = true
## Opacidade máxima do halo aditivo.
@export var intensidade_brilho: float = 0.32

const N_TENTACULOS := 4
const SEGMENTOS := 6
## Metade de baixo da colisão do player (origem do corpo -> pés).
const PES_PLAYER := 8.0
const MEIA_LARGURA_PLAYER := 5.0
const COOLDOWN_DANO := 1.0

## Modo travessia (setado por quem cria, ex. a RainhaMedusas): anda reto
## nessa velocidade (px/s globais), ignora o player e a origem, e some
## sozinha depois de `vida_travessia` segundos.
var travessia := Vector2.ZERO
var vida_travessia: float = 0.0

@onready var _halo: Sprite2D = $Halo
@onready var _hitbox: Area2D = $Hitbox

var _rng := RandomNumberGenerator.new()
var _origem := Vector2.ZERO
var _vel := Vector2.ZERO
var _t: float = 0.0
var _t_pulso: float = 0.0
## 0 = sino relaxado, 1 = contraído (logo após a pulsada).
var _contracao: float = 0.0
var _cooldown: float = 0.0
var _morta: bool = false
var _quiques: int = 0
## Os pés do player estavam acima do sino no último frame em que ele ainda
## NÃO encostava. Caindo rápido ele já entra fundo no sino antes do Area2D
## avisar, então "de onde ele veio" é mais confiável que a posição na hora.
var _player_veio_de_cima: bool = false
## Pés do player (relativo a ela, px locais) no frame anterior. O player se
## move antes dela no frame e o overlap do Area2D chega 1 frame atrasado,
## então a posição "de agora" já pode estar dentro do sino.
var _pes_rel_anterior: float = INF
## Fases individuais dos tentáculos pra não ondularem em uníssono.
var _fases: PackedFloat32Array = PackedFloat32Array()

static var _particula_texture: ImageTexture
static var _material_corpo: CanvasItemMaterial
var _tempo_desenho: float = 0.0

func _process(delta: float) -> void:
	# Só a deformação do desenho roda a 30 Hz; a física continua independente.
	_tempo_desenho += delta
	if _tempo_desenho >= 1.0 / 30.0:
		_tempo_desenho = fmod(_tempo_desenho, 1.0 / 30.0)
		queue_redraw()

func _ready() -> void:
	add_to_group("enemy")
	_rng.seed = hash(str(get_instance_id()) + str(Time.get_ticks_usec()))
	_origem = global_position
	_t = _rng.randf_range(0.0, TAU)
	_t_pulso = _rng.randf_range(0.0, periodo_pulso)
	for i in N_TENTACULOS:
		_fases.append(_rng.randf_range(0.0, TAU))
	_halo.self_modulate = Color(cor_brilho, intensidade_brilho)
	# Ignora o CanvasModulate escuro do mapa, senão o branco vira cinza.
	if _material_corpo == null:
		_material_corpo = CanvasItemMaterial.new()
		_material_corpo.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _material_corpo

func _physics_process(delta: float) -> void:
	if _morta:
		return
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)

	# Pulsada: contrai o sino e dá um impulso; depois relaxa e afunda.
	_t_pulso += delta
	if _t_pulso >= periodo_pulso:
		_t_pulso -= periodo_pulso
		_contracao = 1.0
		_vel.y -= impulso
	_contracao = move_toward(_contracao, 0.0, delta * 2.2)

	if travessia != Vector2.ZERO:
		_atravessar(delta)
		return

	# Afunda bem devagar entre pulsadas e balança de leve pros lados.
	_vel.y += 14.0 * delta
	var alvo_x: float = sin(_t * 0.7) * 6.0

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var dir := Vector2.ZERO
	if player != null and player.visible:
		var para_player: Vector2 = player.global_position + Vector2(0, -10) - global_position
		if para_player.length() < raio_percepcao \
				and (player.global_position - _origem).length() < raio_maximo + raio_percepcao:
			dir = para_player.normalized()
	var longe: Vector2 = _origem - global_position
	if longe.length() > raio_maximo:
		dir = longe.normalized()
	elif dir == Vector2.ZERO:
		# Sem player por perto: volta devagarinho pro ponto de origem.
		dir = longe / raio_maximo

	_vel.x = lerpf(_vel.x, dir.x * velocidade_caca + alvo_x, delta * 1.2)
	_vel.y += dir.y * velocidade_caca * delta * 1.5
	_vel.y = clampf(_vel.y, -impulso, 20.0)
	global_position += _vel * delta

	# Halo respira junto com a pulsada.
	var brilho: float = intensidade_brilho * (0.75 + 0.45 * _contracao + 0.08 * sin(_t * 3.1))
	_halo.self_modulate.a = brilho
	_halo.scale = Vector2.ONE * (0.32 + 0.05 * _contracao) * largura / 14.0

	_checar_contato()

## Travessia: a origem anda reto e ela ondula em volta dela no ritmo da
## pulsada. No fim da vida apaga e some (sem faíscas -- não foi morta).
func _atravessar(delta: float) -> void:
	_origem += travessia * delta
	var s: float = global_scale.y
	global_position = _origem + Vector2(0, sin(_t * 2.4) * 3.0 * s - _contracao * 2.0 * s)
	_halo.self_modulate.a = intensidade_brilho * (0.75 + 0.45 * _contracao)
	vida_travessia -= delta
	if vida_travessia <= 0.0:
		_morta = true
		remove_from_group("enemy")
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		return
	_checar_contato()

func _checar_contato() -> void:
	_lembrar_altura_player()
	if _cooldown > 0.0:
		return
	# A zona de pouso é mais larga que a hitbox mortal. Resolve o quique
	# antes de consultar os overlaps, inclusive na borda externa do sino.
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null and player.visible and player.is_physics_processing():
		var rel := to_local(player.global_position)
		var pes := rel.y + PES_PLAYER
		var alcance := largura * 0.5 + MEIA_LARGURA_PLAYER + margem_quique_lateral
		if absf(rel.x) <= alcance and pes >= -largura * 0.62 \
				and pes <= tolerancia_quique_vertical and _caiu_por_cima(player):
			_quicar(player)
			return
	for body in _hitbox.get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		if _caiu_por_cima(body):
			_quicar(body)
			return
		if mata_na_hora:
			# Queima mortal: encostar fora do topo do sino mata na hora.
			if body.has_method("die") and body.is_physics_processing():
				body.die()
			return
		if body.has_method("take_damage"):
			body.take_damage(1)
		if body.has_method("apply_knockback"):
			var lado: float = signf(body.global_position.x - global_position.x)
			body.apply_knockback(Vector2((lado if lado != 0.0 else 1.0) * 200.0, -160.0))
		_cooldown = COOLDOWN_DANO
		return

func _lembrar_altura_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	# Os mapas são escalados (Mapa10 tem scale 3.65): medidas locais do
	# desenho/colisão viram globais multiplicando pela escala.
	var s: float = global_scale.y
	var pes_rel: float = (p.global_position.y - global_position.y) / s + PES_PLAYER
	if not _hitbox.overlaps_body(p):
		_player_veio_de_cima = minf(pes_rel, _pes_rel_anterior) <= -largura * 0.25
	_pes_rel_anterior = pes_rel

## Player descendo e que, antes de encostar, estava com os pés acima do sino.
func _caiu_por_cima(body: Node2D) -> bool:
	if not body is CharacterBody2D:
		return false
	if (body as CharacterBody2D).velocity.y < -10.0:
		return false
	var pes := to_local(body.global_position).y + PES_PLAYER
	# Pousos laterais na metade superior também contam. O histórico continua
	# cobrindo quedas rápidas, que podem atravessar o topo entre dois ticks.
	return _player_veio_de_cima or pes <= tolerancia_quique_vertical

## Trampolim: joga o player pra cima, libera outro pulo, recarrega o dash aéreo e o sino
## afunda e se espreme, voltando com uma mola.
func _quicar(body: CharacterBody2D) -> void:
	var forca: float = quique_segurando_pulo if Input.is_action_pressed("jump") else quique
	body.velocity.y = -forca
	if body.has_method("recarregar_pulo_agua_viva"):
		body.recarregar_pulo_agua_viva()
	if "can_dash_air" in body:
		body.can_dash_air = true
	_quiques += 1
	if quiques_max > 0 and _quiques >= quiques_max:
		die()
		return
	# Não queima com os tentáculos logo depois do quique.
	_cooldown = 0.3
	_contracao = 1.0
	_vel.y = 45.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.35, 0.65), 0.07).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# O CanvasItem não conhece os limites do desenho procedural. Evita
	# reconstruir polígonos e tentáculos das medusas fora da câmera.
	# Mantém movimento e colisão ativos, inclusive durante a travessia.
	var margem := (largura + comprimento_tentaculo) * get_global_transform_with_canvas().get_scale().abs().length()
	if not get_viewport_rect().grow(margem).has_point(get_global_transform_with_canvas().origin):
		return
	var c: float = _contracao
	var w: float = largura * (1.0 - 0.22 * c)
	var h: float = largura * 0.62 * (1.0 + 0.25 * c)

	# Tentáculos: saem da borda do sino e ondulam, arrastando atrás do movimento.
	for i in N_TENTACULOS:
		var x0: float = lerpf(-w * 0.38, w * 0.38, float(i) / (N_TENTACULOS - 1))
		var pts := PackedVector2Array()
		var comp: float = comprimento_tentaculo * (1.0 + 0.15 * c) * (0.85 + 0.15 * float(i % 2))
		for s in SEGMENTOS + 1:
			var k: float = float(s) / SEGMENTOS
			var onda: float = sin(_t * 3.0 - k * 4.0 + _fases[i]) * 2.2 * k
			var arrasto: float = -_vel.x * 0.08 * k * k
			pts.append(Vector2(x0 * (1.0 - 0.3 * k) + onda + arrasto, k * comp))
		var cor_t := Color(cor_corpo, 0.45)
		draw_polyline(pts, cor_t, 1.0)

	# Sino: meia elipse com franja ondulada embaixo.
	var sino := PackedVector2Array()
	var passos := 14
	for s in passos + 1:
		var a: float = PI + PI * float(s) / passos
		sino.append(Vector2(cos(a) * w * 0.5, sin(a) * h))
	for s in range(passos, -1, -1):
		var x: float = lerpf(-w * 0.5, w * 0.5, float(s) / passos)
		sino.append(Vector2(x, 1.2 + sin(x * 1.3 + _t * 4.0) * 0.8))
	draw_colored_polygon(sino, cor_corpo)

	# Miolo mais claro e borda brilhante.
	var miolo := PackedVector2Array()
	for s in passos + 1:
		var a: float = PI + PI * float(s) / passos
		miolo.append(Vector2(cos(a) * w * 0.28, sin(a) * h * 0.6 - 0.5))
	draw_colored_polygon(miolo, Color(1, 1, 1, 0.22))
	var borda := PackedVector2Array()
	for s in passos + 1:
		var a: float = PI + PI * float(s) / passos
		borda.append(Vector2(cos(a) * w * 0.5, sin(a) * h))
	draw_polyline(borda, Color(1, 1, 1, 0.95), 1.0)

	# Pontinhos de luz dentro do sino.
	var p: float = 0.6 + 0.4 * sin(_t * 2.3)
	draw_rect(Rect2(Vector2(-2, -h * 0.55), Vector2(1, 1)), Color(1, 1, 1, 0.7 * p))
	draw_rect(Rect2(Vector2(1, -h * 0.4), Vector2(1, 1)), Color(1, 1, 1, 0.5 * (1.4 - p)))

func take_damage(_amount: int) -> bool:
	if _morta:
		return false
	die()
	return true

func die() -> void:
	if _morta:
		return
	_morta = true
	remove_from_group("enemy")
	_hitbox.set_deferred("monitoring", false)
	_spawn_particulas()
	# Some num suspiro: incha, perde a cor e o halo apaga.
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(1.4, 0.7), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_property(_halo, "self_modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)

func _spawn_particulas() -> void:
	if _particula_texture == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_particula_texture = ImageTexture.create_from_image(image)
	var particles := CPUParticles2D.new()
	particles.texture = _particula_texture
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 1.1
	particles.explosiveness = 0.9
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, -25)
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 45.0
	particles.damping_min = 20.0
	particles.damping_max = 40.0
	var fade := Gradient.new()
	fade.set_color(0, Color(cor_brilho, 1.0))
	fade.set_color(1, Color(cor_brilho, 0.0))
	particles.color_ramp = fade
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = mat
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector2(0, -4)
	particles.z_index = 10
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)
