extends CharacterBody2D
## NPC caracol: anda de um lado para o outro sobre o chao e se encolhe na concha
## quando o jogador chega perto (ex.: para parar e ler uma dica de gameplay).
## Vira sozinho ao encontrar parede ou beira de plataforma.
## Esta no grupo "enemy" so para os espinhos / lava poderem mata-lo.
##
## Modo TUTOR (preencha `dialogo`): quando o player chega perto pela 1a vez o
## caracol TRAVA o player e puxa uma conversa obrigatoria -- cada fala aparece
## datilografada num texto fixo no topo-centro da tela (estilo Silksong: sem
## caixa, sem retrato, cena escurecida por baixo) e avanca com ESPACO ou E (um
## "▼" pequeno pisca abaixo do texto quando a linha termina). Terminada a
## conversa ele NAO fala mais sozinho: fica so o "▲ E" no mesmo lugar do texto
## e o player reabre a conversa apertando E. (No modo tutor o balao ambiente
## por proximidade -- texto_dica / frases_dica -- fica desligado.)
##
## O texto (`balao`), a seta e o escurecimento de fundo sao os MESMOS nos pra
## todos os modos (dica, tutor, acusacao, bebe, ultimas palavras) -- so o modo
## tutor ativa o escurecimento; os outros modos so usam o texto no topo.

@export var velocidade: float = 16.0
## Limite (px) de quanto ele se afasta do ponto onde nasceu, para cada lado.
@export var alcance_patrulha: float = 40.0
## Se o jogador estiver a esta distancia (px) ou menos, ele se encolhe.
@export var distancia_encolher: float = 26.0
## Depois que o jogador se afasta, ele sai da concha e volta a andar.
@export var voltar_a_andar: bool = true
## Se ligado, ele da meia-volta ao chegar numa beira. Desligue para deixar
## ele andar para dentro de um buraco / lava de proposito.
@export var parar_na_beira: bool = true
## Se ligado, morre quando o player cai/pisa em cima dele (usa o no "ZonaPisao").
@export var morre_pisado: bool = false
## Dica que ja aparece no balao ao iniciar o jogo. Deixe vazio se este caracol
## nao da dica (ex.: o segundo caracol).
@export_multiline var texto_dica: String = "A / D  andar\nESPAÇO  pular"
## Se preenchido, o balao de dica fica CICLANDO por estas frases enquanto o player
## esta perto (cada uma "reaparece" pra dar sensacao de fala), em vez de mostrar
## o `texto_dica` fixo. Ponha o texto_dica como primeira frase se quiser mante-lo.
@export var frases_dica: Array[String] = []
## Segundos que cada frase de `frases_dica` fica na tela antes de trocar.
@export var intervalo_dica: float = 2.5
## Distancia (px) do jogador que dispara o balao: no caracol de dica ele SOME
## quando o player chega a essa distancia; no de acusacao ele APARECE.
## IGNORADO se o no "AreaInteracao" existir na cena — ai o gatilho e a sobreposicao
## fisica dessa Area2D, que voce redimensiona arrastando o CircleShape2D no editor.
@export var distancia_dica: float = 80.0
## Altura (px, espaco do mundo) acima do caracol onde a bolha/prompt flutuam.
@export var altura_balao: float = 26.0
## Brilho no escuro, mesmo esquema do ELLI (player.gd::brilho_no_escuro): ignora
## o escurecimento do CanvasModulate sem vazar pra fora do sprite.
@export var brilho_no_escuro: bool = true

## --- Modo tutor -------------------------------------------------------------
## Falas da conversa OBRIGATORIA. Se vazio, o caracol nao e um tutor e mantem o
## comportamento antigo (balao por proximidade).
@export var dialogo: Array[String] = []
## A conversa comeca sozinha quando o player entra no alcance pela 1a vez.
## Desligue para so abrir quando ele apertar E.
@export var dialogo_auto_perto: bool = true
## Velocidade da datilografia em caracteres por segundo (vale pro dialogo e
## tambem pros baloes ambiente).
@export var velocidade_typewriter: float = 34.0
## Alpha do escurecimento da cena atras do texto, so durante o dialogo obrigatorio (0 a 1).
@export_range(0.0, 1.0, 0.01) var escurecimento_alpha: float = 0.35
## Duracao (s) do fade do texto e do escurecimento ao abrir/fechar o dialogo obrigatorio.
@export var duracao_fade: float = 0.25
## Ao terminar a conversa obrigatoria, libera o dash do player (ve
## `player.desbloquear_dash()`). Usado pela caracol-mae que ensina o dash.
@export var ativa_dash: bool = false

## Marca o caracol tutorial. Ao morrer, avisa os outros caracois (flag estatica).
@export var eh_tutorial: bool = false
## Marca o caracol bebe. Se ele morrer E o player tambem morrer na fase depois
## disso, ele vira um vagalume pequeno flutuando onde estava em vez de
## renascer -- mesmo depois de um checkpoint. So volta ao normal com "Novo
## Jogo" (ver SaveManager.bebe_morto / bebe_lapide).
@export var eh_bebe: bool = false
## Se preenchido, ao morrer o caracol solta uma destas frases (sorteada) no
## balao antes de sumir. Usado no caracol tutorial.
@export var frases_morte: Array[String] = []
## Quanto tempo (s) a frase de morte fica na tela.
@export var tempo_frase_morte: float = 3.5
## Se preenchido, este caracol so fala (ao chegar perto) SE o caracol tutorial
## ja tiver sido morto. Fala uma destas frases (sorteada). Usado no 2o caracol.
@export var frases_acusacao: Array[String] = []
## Caracol bebe. Se qualquer uma destas listas tiver frases, ele NAO precisa do player
## por perto: fica trocando de frase em loop, pra sempre. Qual lista ele usa depende do
## caracol tutorial (o "pai") estar vivo ou morto nesta run (`tutorial_morto`).
## Pai vivo: o bebe se gaba do pai (fila `frases_pai_vivo`, a cada `intervalo_pai_vivo` s).
@export var frases_pai_vivo: Array[String] = []
@export var intervalo_pai_vivo: float = 3.0
## Pai morto: o bebe procura o pai, aflito (`frases_pai_morto`, a cada `intervalo_pai_morto` s).
@export var frases_pai_morto: Array[String] = []
@export var intervalo_pai_morto: float = 2.0

## Compartilhada por todos os caracois: o caracol tutorial foi morto nesta run?
static var tutorial_morto: bool = false
## O player ja passou pela conversa obrigatoria do caracol tutor nesta run?
static var tutorial_dialogo_feito: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detector_chao: RayCast2D = $DetectorChao
## Balao: CanvasLayer com o texto flutuando em cima do caracol -- fica sempre
## no mesmo tamanho na tela (nao escala com o zoom da camera nem com a escala
## do proprio caracol, ja que CanvasLayer e' desenhado em espaco de tela), mas
## a posicao e' recalculada todo frame a partir da posicao dele no mundo.
@onready var balao: RichTextLabel = $Balao/Bolha/Texto
@onready var _bolha: Control = $Balao/Bolha
@onready var _seta: Label = $Balao/Bolha/Seta
@onready var _prompt: Label = $Balao/Prompt
@onready var _escurecer: ColorRect = $Balao/Escurecer
## Area2D opcional "AreaInteracao": se existir, o gatilho do balao ("player perto")
## passa a ser a sobreposicao fisica dela em vez do numero `distancia_dica`.
## Redimensione o CircleShape2D no editor para ajustar o alcance visualmente.
@onready var _area_interacao: Area2D = get_node_or_null("AreaInteracao")
## Area2D "ZonaPisao" no topo do corpo: se `morre_pisado`, o player caindo aqui o mata.
@onready var _zona_pisao: Area2D = get_node_or_null("ZonaPisao")

static var _death_particle_texture: ImageTexture
const VAGALUME_MEMORIAL_SCENE := preload("res://Environment/Vagalume.tscn")
## Escala do vagalume-memorial em relacao ao Vagalume.tscn normal (pequeno).
const VAGALUME_MEMORIAL_ESCALA := 0.5
## Flutua bem rente a onde o bebe morreu -- valores pequenos de proposito
## porque o mapa em si roda numa escala grande (~3.65x), entao qualquer coisa
## aqui ja aparece bem ampliada na tela.
const VAGALUME_MEMORIAL_OFFSET_Y := -4.0
const VAGALUME_MEMORIAL_RAIO_VOO := 3.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _origem_x: float
var _direcao: float = -1.0
var _encolhido: bool = false
var _morto: bool = false
var _acusou: bool = false
## Caracol bebe: indice da proxima fala e timer ate a proxima troca.
var _proxima_fala_bebe: int = 0
var _timer_grito: float = 0.0
## Dica ciclando (frases_dica): indice da proxima frase e timer ate trocar.
var _proxima_dica: int = 0
var _timer_dica: float = 0.0
## Ultima leitura de `tutorial_morto` vista pelo bebe; ao mudar, ele reinicia a fila.
var _bebe_pai_morto: bool = false
## Caminho deste caracol dentro da cena — id estavel entre recarregamentos.
var _meu_caminho: String = ""
## Datilografia da linha atual do balao (Tween animando visible_ratio).
var _tw_typewriter: Tween
var _linha_completa: bool = false
var _tempo_ui: float = 0.0
## Conversa obrigatoria (modo tutor).
var _dialogo_ativo: bool = false
var _dialogo_idx: int = 0
var _dialogo_feito: bool = false
## Pequena folga antes de a conversa poder comecar sozinha (a cena assenta).
var _graca: float = 0.45
## Player congelado enquanto a conversa rola (destravado ao terminar / sair de cena).
var _player_travado: Node = null

func _ready() -> void:
	# Bebe morto + player ja morreu depois disso: vira vagalume de vez, ignorando
	# checkpoint -- nunca mais volta a ser o caracol normal.
	if eh_bebe and SaveManager.bebe_lapide:
		_virar_vagalume()
		return

	var scene_path := owner.scene_file_path if owner else ""
	_meu_caminho = str(owner.get_path_to(self)) if owner else str(name)

	if SaveManager.caracol_esta_morto(scene_path, _meu_caminho):
		# Morreu antes do checkpoint atual: nao renasce.
		if eh_tutorial:
			tutorial_morto = true
		hide()
		set_physics_process(false)
		set_process(false)
		queue_free()
		return

	if brilho_no_escuro:
		var material_brilho := CanvasItemMaterial.new()
		material_brilho.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sprite.material = material_brilho

	add_to_group("enemy")
	_origem_x = global_position.x
	if eh_tutorial:
		# Este caracol esta vivo agora, entao a "memoria dos caracois" volta ao normal.
		tutorial_morto = false
	_dialogo_feito = tutorial_dialogo_feito
	_mostrar_linha(frases_dica[0] if not frases_dica.is_empty() else texto_dica)
	# Todos os modos ligam/desligam o balao pela proximidade; comeca escondido e
	# aparece quando o player chega perto.
	_bolha.modulate.a = 0.0
	# Forca de escurecimento vem do export; o fade em si e feito por modulate:a.
	_escurecer.color.a = escurecimento_alpha
	_escurecer.modulate.a = 0.0
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject2D:
		# Divide o bit "player" so para os espinhos/lava enxergarem o caracol;
		# sem esta excecao o jogador esbarraria fisicamente nele.
		add_collision_exception_with(player)

	if _zona_pisao != null:
		if morre_pisado:
			_zona_pisao.body_entered.connect(_on_zona_pisao_body_entered)
		else:
			_zona_pisao.monitoring = false

## Substitui este caracol (o bebe) por um vagalume pequeno flutuando na mesma
## posicao, em vez do comportamento normal. Ver eh_bebe / SaveManager.bebe_lapide.
func _virar_vagalume() -> void:
	var vagalume := VAGALUME_MEMORIAL_SCENE.instantiate()
	var pos := global_position + Vector2(0, VAGALUME_MEMORIAL_OFFSET_Y)
	var pai := get_parent()
	# Adiado: isto roda dentro de _ready(), enquanto a arvore da cena ainda
	# esta sendo montada -- add_child direto aqui e' rejeitado pelo Godot
	# ("Parent node is busy setting up children").
	(func() -> void:
		vagalume.scale = Vector2.ONE * VAGALUME_MEMORIAL_ESCALA
		vagalume.raio_voo = VAGALUME_MEMORIAL_RAIO_VOO
		# A posicao TEM que ser setada antes do add_child: o vagalume.gd le a
		# propria posicao dentro do seu _ready() (`_origem = position`) pra
		# saber ao redor de onde flutuar, e o _ready roda na hora do
		# add_child -- setar depois so faz ele "pular" de volta pra origem
		# do mapa no proximo frame (foi o bug do vagalume nascendo la em cima).
		vagalume.position = pai.to_local(pos)
		pai.add_child(vagalume)
	).call_deferred()
	queue_free()

func _exit_tree() -> void:
	# Rede de seguranca: nunca deixa o player congelado se o caracol sumir no meio da conversa.
	if _player_travado != null and is_instance_valid(_player_travado):
		_player_travado.set_physics_process(true)
	_player_travado = null

func die() -> void:
	if _morto:
		return
	_morto = true
	if eh_tutorial:
		tutorial_morto = true
	if eh_bebe:
		SaveManager.registrar_bebe_morto()
	SaveManager.registrar_caracol_morto(_meu_caminho)
	set_physics_process(false)
	velocity = Vector2.ZERO
	if _dialogo_ativo:
		_encerrar_dialogo()
	_soltar_particulas()
	if frases_morte.is_empty():
		queue_free()
		return
	_ultimas_palavras()

## Player caiu/pisou em cima: so mata se ele vier de cima e descendo (nao ao esbarrar de lado).
func _on_zona_pisao_body_entered(body: Node) -> void:
	if _morto or not body.is_in_group("player") or not body is CharacterBody2D:
		return
	var jogador := body as CharacterBody2D
	if jogador.global_position.y <= global_position.y and jogador.velocity.y > 20.0:
		die()

## Some com o corpo mas mantem o no vivo so para o balao cuspir uma ultima frase.
func _ultimas_palavras() -> void:
	sprite.visible = false
	collision_layer = 0
	($CollisionShape2D as CollisionShape2D).set_deferred("disabled", true)

	_seta.visible = false
	_prompt.visible = false
	_mostrar_linha(frases_morte.pick_random())

	var tw := create_tween()
	tw.tween_property(_bolha, "modulate:a", 1.0, 0.15)
	tw.tween_interval(tempo_frase_morte)
	tw.tween_property(_bolha, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	_tempo_ui += delta
	_atualizar_seta()
	_atualizar_posicao_balao()
	if not dialogo.is_empty() and not _morto:
		_logica_dialogo(delta)

## So pisca quando a linha atual terminou de datilografar e o balao esta visivel
## -- e o unico sinal de "da pra avancar" agora que nao tem mais texto na seta.
func _atualizar_seta() -> void:
	var mostrar := _dialogo_ativo and _linha_completa and _bolha.modulate.a > 0.05
	_seta.visible = mostrar
	if mostrar:
		_seta.modulate.a = 0.35 + 0.65 * absf(sin(_tempo_ui * 6.0))

## Converte a posicao do caracol no mundo pra espaco de tela (via o transform
## da camera atual) e poe a bolha e o prompt centralizados ali em cima, com um
## pouco de folga (`altura_balao`). Roda todo frame porque o caracol anda e a
## camera pode se mover.
##
## Trava dentro da tela: em mapas com camera seguindo o player (nao uma camera
## fixa de tela unica), o caracol pode estar numa plataforma mais alta que o
## player e ficar perto ou fora da borda de cima -- sem isso a bolha calcularia
## uma posicao fora da area visivel e o jogador nunca veria o texto aparecer.
func _atualizar_posicao_balao() -> void:
	if _bolha.modulate.a <= 0.0 and not _prompt.visible:
		return
	var alvo := global_position + Vector2(0, -altura_balao)
	var tela := get_viewport().get_canvas_transform() * alvo
	var tela_tam := get_viewport().get_visible_rect().size
	_prompt.size = _prompt.get_minimum_size()
	# Ancora pelo canto de baixo-centro de cada caixa, pra elas crescerem pra
	# cima a partir do mesmo ponto acima do caracol (em vez de crescer pros
	# dois lados a partir do centro, o que empurraria o topo mais alto ainda).
	_bolha.position = _travar_na_tela(Vector2(tela.x - _bolha.size.x * 0.5, tela.y - _bolha.size.y), _bolha.size, tela_tam)
	_prompt.position = _travar_na_tela(Vector2(tela.x - _prompt.size.x * 0.5, tela.y - _prompt.size.y), _prompt.size, tela_tam)

## Garante que a caixa (bolha ou prompt) fique inteira dentro da tela, com uma
## pequena margem, mesmo quando o ponto-alvo em cima do caracol calcularia uma
## posicao fora da area visivel.
func _travar_na_tela(pos: Vector2, tamanho: Vector2, tela_tam: Vector2) -> Vector2:
	const MARGEM := 8.0
	pos.x = clampf(pos.x, MARGEM, maxf(MARGEM, tela_tam.x - tamanho.x - MARGEM))
	pos.y = clampf(pos.y, MARGEM, maxf(MARGEM, tela_tam.y - tamanho.y - MARGEM))
	return pos

## Redimensiona a caixa de texto pro tamanho do conteudo atual (o RichTextLabel
## com fit_content ja calcula sua propria altura minima) e centraliza -- so
## roda quando a linha muda, nao every frame.
func _ajustar_layout_texto() -> void:
	_bolha.size = _bolha.get_combined_minimum_size()

## Mostra a linha e datilografa via Tween em `visible_ratio` (RichTextLabel).
func _mostrar_linha(txt: String) -> void:
	balao.text = "[center]%s[/center]" % txt
	balao.visible_ratio = 0.0
	_linha_completa = false
	_ajustar_layout_texto()

	if _tw_typewriter != null and _tw_typewriter.is_valid():
		_tw_typewriter.kill()
	var duracao := txt.length() / maxf(velocidade_typewriter, 1.0)
	_tw_typewriter = create_tween()
	_tw_typewriter.tween_property(balao, "visible_ratio", 1.0, duracao)
	_tw_typewriter.tween_callback(func() -> void: _linha_completa = true)

## Volta a esconder os caracteres pra a linha ser re-datilografada da proxima
## vez que a bolha aparecer (texto_dica fixo, ao o player voltar).
func _reiniciar_linha() -> void:
	if _tw_typewriter != null and _tw_typewriter.is_valid():
		_tw_typewriter.kill()
	balao.visible_ratio = 0.0
	_linha_completa = false

func _completar_linha() -> void:
	if _tw_typewriter != null and _tw_typewriter.is_valid():
		_tw_typewriter.kill()
	balao.visible_ratio = 1.0
	_linha_completa = true

# --- Conversa obrigatoria (modo tutor) --------------------------------------

func _logica_dialogo(delta: float) -> void:
	if _dialogo_ativo:
		_prompt.visible = false
		if Input.is_action_just_pressed("interagir") or Input.is_action_just_pressed("jump"):
			_avancar_dialogo()
		return

	if _graca > 0.0:
		_graca -= delta

	var perto := _player_perto(_dist_ao_player())
	var quer_abrir := Input.is_action_just_pressed("interagir")
	if perto and _graca <= 0.0 and ((dialogo_auto_perto and not _dialogo_feito) or quer_abrir):
		_iniciar_dialogo()
		return

	# Mostra o "E" sempre que perto e a conversa nao vai abrir sozinha -- ou
	# porque ja abriu uma vez (_dialogo_feito), ou porque este caracol nunca
	# abre sozinho (dialogo_auto_perto = false) e o E e' a unica forma de comecar.
	_prompt.visible = perto and (_dialogo_feito or not dialogo_auto_perto) and _bolha.modulate.a < 0.5
	if _prompt.visible:
		_prompt.modulate.a = 0.45 + 0.4 * absf(sin(_tempo_ui * 3.0))

func _iniciar_dialogo() -> void:
	if _dialogo_ativo or dialogo.is_empty():
		return
	_dialogo_ativo = true
	_dialogo_idx = 0
	_encolhido = true
	velocity = Vector2.ZERO
	sprite.play("concha_D" if _direcao > 0.0 else "concha_A")

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_player_travado = player
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		player.set_physics_process(false)

	_abrir_caixa_texto()
	_mostrar_linha(dialogo[0])

func _avancar_dialogo() -> void:
	if not _linha_completa:
		_completar_linha()
		return
	_dialogo_idx += 1
	if _dialogo_idx >= dialogo.size():
		_encerrar_dialogo()
		return
	_mostrar_linha(dialogo[_dialogo_idx])

func _encerrar_dialogo() -> void:
	_dialogo_ativo = false
	_dialogo_feito = true
	tutorial_dialogo_feito = true
	_seta.visible = false
	if ativa_dash and _player_travado != null and is_instance_valid(_player_travado) and _player_travado.has_method("desbloquear_dash"):
		_player_travado.desbloquear_dash()
	if _player_travado != null and is_instance_valid(_player_travado):
		_player_travado.set_physics_process(true)
	_player_travado = null
	_fechar_caixa_texto()

## Fade-in do texto + escurecimento sutil da cena, so no dialogo obrigatorio.
func _abrir_caixa_texto() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bolha, "modulate:a", 1.0, duracao_fade)
	tw.tween_property(_escurecer, "modulate:a", 1.0, duracao_fade)

func _fechar_caixa_texto() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bolha, "modulate:a", 0.0, duracao_fade)
	tw.tween_property(_escurecer, "modulate:a", 0.0, duracao_fade)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if _dialogo_ativo:
		velocity.x = 0.0
		move_and_slide()
		return

	var dist_player := _dist_ao_player()
	_atualizar_balao(dist_player, delta)

	if distancia_encolher > 0.0 and dist_player <= distancia_encolher:
		if not _encolhido:
			_encolhido = true
			sprite.play("concha_D" if _direcao > 0.0 else "concha_A")
		velocity.x = 0.0
		move_and_slide()
		return

	if _encolhido:
		if not voltar_a_andar:
			velocity.x = 0.0
			move_and_slide()
			return
		_encolhido = false

	detector_chao.position.x = absf(detector_chao.position.x) * _direcao
	detector_chao.force_raycast_update()

	# Vira ao passar do alcance, ao bater numa parede ou ao chegar numa beira.
	if global_position.x - _origem_x >= alcance_patrulha:
		_direcao = -1.0
	elif global_position.x - _origem_x <= -alcance_patrulha:
		_direcao = 1.0
	elif is_on_floor() and (is_on_wall() or (parar_na_beira and not detector_chao.is_colliding())):
		_direcao = -_direcao

	velocity.x = _direcao * velocidade
	sprite.play("andar_D" if _direcao > 0.0 else "andar_A")
	move_and_slide()

func _dist_ao_player() -> float:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)

## O player esta dentro do raio de interacao? Usa a AreaInteracao (redimensionavel
## no editor) se ela existir; senao cai no numero `distancia_dica`.
func _player_perto(dist_player: float) -> bool:
	if _area_interacao != null:
		for corpo in _area_interacao.get_overlapping_bodies():
			if corpo.is_in_group("player"):
				return true
		return false
	return dist_player <= distancia_dica

## Tres modos (fora o tutor, que roda em `_logica_dialogo`):
## - dica (texto_dica preenchido): balao fica na tela enquanto o player esta perto e
##   some quando ele se afasta.
## - acusacao (frases_acusacao preenchido + caracol tutorial morto): aparece quando o
##   player chega perto, some quando ele se afasta.
## - bebe (frases_pai_vivo/frases_pai_morto preenchido): fala em loop sem se importar
##   com a distancia (ver _atualizar_balao_bebe).
func _atualizar_balao(dist_player: float, delta: float) -> void:
	if _morto or _dialogo_ativo:
		return
	# Caracol tutor (dialogo preenchido): NAO tem balao ambiente por proximidade.
	# Ele so fala na conversa obrigatoria inicial e quando o player reabre com E
	# (o "▲ E" aparece via _logica_dialogo). Assim ele nao fica "tagarelando" sozinho.
	if not dialogo.is_empty():
		_bolha.modulate.a = move_toward(_bolha.modulate.a, 0.0, delta * 3.0)
		return
	var alvo := 0.0
	if not texto_dica.is_empty() or not frases_dica.is_empty():
		if _player_perto(dist_player):
			alvo = 1.0
			if not frases_dica.is_empty():
				_ciclar_dica(delta)
		else:
			# Longe: reinicia o ciclo pra recomecar da 1a frase na proxima vez.
			_proxima_dica = 0
			_timer_dica = 0.0
			if _bolha.modulate.a < 0.05:
				_reiniciar_linha()
	elif not frases_acusacao.is_empty() and tutorial_morto:
		if _player_perto(dist_player):
			if not _acusou:
				_acusou = true
				_mostrar_linha(frases_acusacao.pick_random())
			alvo = 1.0
	elif not frases_pai_vivo.is_empty() or not frases_pai_morto.is_empty():
		alvo = _atualizar_balao_bebe(delta)
	_bolha.modulate.a = move_toward(_bolha.modulate.a, alvo, delta * 3.0)

## Dica ciclando: troca a frase do balao a cada `intervalo_dica` s e re-datilografa
## ela (sensacao de fala). Roda so enquanto o player esta perto.
func _ciclar_dica(delta: float) -> void:
	_timer_dica -= delta
	if _timer_dica <= 0.0:
		_timer_dica = intervalo_dica
		_mostrar_linha(frases_dica[_proxima_dica % frases_dica.size()])
		_proxima_dica += 1

## Caracol bebe: nao liga pra distancia do player. Fica trocando de frase em loop e faz
## o balao re-datilografar pra dar a sensacao de fala. Balao sempre visivel.
## Pai vivo -> se gaba do pai; pai morto -> procura o pai, aflito. Ao trocar de estado
## reinicia a fila do comeco.
func _atualizar_balao_bebe(delta: float) -> float:
	if tutorial_morto != _bebe_pai_morto:
		_bebe_pai_morto = tutorial_morto
		_proxima_fala_bebe = 0
		_timer_grito = 0.0

	var falas := frases_pai_morto if tutorial_morto else frases_pai_vivo
	var intervalo := intervalo_pai_morto if tutorial_morto else intervalo_pai_vivo
	if falas.is_empty():
		return 0.0

	_timer_grito -= delta
	if _timer_grito <= 0.0:
		_timer_grito = intervalo
		_mostrar_linha(falas[_proxima_fala_bebe % falas.size()])
		_proxima_fala_bebe += 1

	return 1.0

## Mesma explosao de particulas da morte do jogador (player.gd::_spawn_death_particles).
func _soltar_particulas() -> void:
	if _death_particle_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		_death_particle_texture = ImageTexture.create_from_image(image)

	var particles := CPUParticles2D.new()
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
