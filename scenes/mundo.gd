extends Node2D
## Cena principal do Mundo: mantém o Elísio e a câmera persistentes acima
## das telas, que entram e saem como filhas de `Telas` em vez de trocar de
## cena. Ver auditoria anterior para o porquê (change_scene_to_file
## destrói a árvore inteira, inclusive o player).
##
## No máximo duas telas vivas ao mesmo tempo: a atual e, durante
## subir_tela(), a próxima -- a antiga é liberada assim que o tween termina.

## Duração do slide de câmera/Elísio ao subir de tela.
const DURACAO := 0.45
## Duração das trocas de modo de câmera "avulsas" (zonas de câmera fixa
## dentro de uma tela, tipo a TowerCameraZone do mapa_01).
const DURACAO_ANCORA := 0.5
const ZOOM_PADRAO := Vector2(1, 1)

## Tela carregada quando o Mundo entra na árvore pela primeira vez.
@export var tela_inicial: PackedScene

@onready var telas: Node2D = $Telas
@onready var elisio: Node2D = $Elisio
@onready var elisio_corpo: CharacterBody2D = $Elisio/CharacterBody2D
@onready var camera: Camera2D = $Camera

var _tela_atual: Node2D = null
var _tela_atual_packed: PackedScene = null
var _em_transicao: bool = false
var _seguindo: bool = true

func _ready() -> void:
	add_to_group("gerenciador")
	camera.position_smoothing_enabled = false
	camera.make_current()
	if tela_inicial or SaveManager.checkpoint_scene != "":
		_carregar_tela_inicial()

func _process(_delta: float) -> void:
	if _seguindo and not _em_transicao:
		camera.global_position = elisio_corpo.global_position

func em_transicao() -> bool:
	return _em_transicao

func tela_atual_scene_path() -> String:
	return _tela_atual.scene_file_path if _tela_atual else ""

# --- Câmera -------------------------------------------------------------

## Câmera acompanha o Elísio direto (mundo aberto). `instantaneo` pula o tween
## (usado ao carregar uma tela; subir_tela já tem seu próprio tween).
func seguir_jogador(instantaneo: bool = false) -> void:
	if instantaneo or _em_transicao:
		_seguindo = true
		camera.global_position = elisio_corpo.global_position
		camera.zoom = ZOOM_PADRAO
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_position", elisio_corpo.global_position, DURACAO_ANCORA)
	tw.tween_property(camera, "zoom", ZOOM_PADRAO, DURACAO_ANCORA)
	await tw.finished
	_seguindo = true

## Câmera fixa num Marker2D (tela de câmera fixa, ou zona de câmera fixa
## dentro de uma tela de mundo aberto). `instantaneo` pula o tween.
func ancorada(ancora: Marker2D, zoom: Vector2 = ZOOM_PADRAO, instantaneo: bool = false) -> void:
	_seguindo = false
	if instantaneo or _em_transicao:
		camera.global_position = ancora.global_position
		camera.zoom = zoom
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_position", ancora.global_position, DURACAO_ANCORA)
	tw.tween_property(camera, "zoom", zoom, DURACAO_ANCORA)

# --- Carregamento de telas -----------------------------------------------

func _carregar_tela_inicial() -> void:
	# "Continue" chega aqui com SaveManager.checkpoint_scene já populado (por
	# load_progress(), chamado pelo MainMenu antes de trocar de cena) -- carrega
	# a tela salva em vez da tela_inicial fixa. "New Game" limpa o save antes,
	# então checkpoint_scene fica vazio e cai no caminho normal.
	var pacote := tela_inicial
	if SaveManager.checkpoint_scene != "":
		var carregado: Resource = load(SaveManager.checkpoint_scene)
		if carregado is PackedScene:
			pacote = carregado
	var nova: Node2D = pacote.instantiate()
	nova.position = Vector2.ZERO
	telas.add_child(nova)
	_tela_atual = nova
	_tela_atual_packed = pacote
	# Posiciona ANTES de aplicar a câmera: em modo "seguir" ela usa a posição
	# atual do Elísio na hora -- aplicar antes deixaria a câmera 1 frame
	# atrás, apontando pra posição antiga.
	_posicionar_no_respawn_ou_checkpoint(nova)
	_aplicar_camera_da_tela(nova, true)
	if elisio_corpo.has_method("ao_entrar_na_tela"):
		elisio_corpo.ao_entrar_na_tela(nova)

func _posicionar_no_respawn_ou_checkpoint(tela: Node2D) -> void:
	if SaveManager.has_checkpoint(tela.scene_file_path):
		return # ao_entrar_na_tela cuida disso
	var respawn := tela.get_node_or_null("Respawn") as Marker2D
	if respawn:
		elisio_corpo.global_position = respawn.global_position

func _aplicar_camera_da_tela(tela: Node2D, instantaneo: bool) -> void:
	var modo: String = tela.modo_camera if "modo_camera" in tela else "seguir"
	if modo == "ancorada":
		var ancora := tela.get_node_or_null("AncoraCamera") as Marker2D
		if ancora:
			var zoom: Vector2 = tela.zoom_camera if "zoom_camera" in tela else ZOOM_PADRAO
			ancorada(ancora, zoom, instantaneo)
			return
	seguir_jogador(instantaneo)

## Sobe da tela atual pra `proxima`: instancia e alinha pela âncora
## (AncoraInferior da nova encosta na AncoraSuperior da atual), desliza a
## câmera e o Elísio, e só então libera a tela antiga.
func subir_tela(proxima: PackedScene) -> void:
	if _em_transicao or proxima == null or _tela_atual == null:
		return
	_em_transicao = true

	var tela_velha := _tela_atual
	var ancora_saida := tela_velha.get_node_or_null("AncoraSuperior") as Marker2D

	var nova: Node2D = proxima.instantiate()
	nova.position = Vector2.ZERO
	telas.add_child(nova)

	var ancora_entrada := nova.get_node_or_null("AncoraInferior") as Marker2D
	if ancora_saida and ancora_entrada:
		var diff: Vector2 = ancora_saida.global_position - ancora_entrada.global_position
		nova.global_position += diff
	else:
		push_warning("subir_tela: faltam AncoraSuperior/AncoraInferior -- telas não alinhadas.")

	elisio_corpo.set_physics_process(false)
	elisio_corpo.velocity = Vector2.ZERO

	var modo: String = nova.modo_camera if "modo_camera" in nova else "seguir"
	var zoom_destino: Vector2 = ZOOM_PADRAO
	var pos_destino: Vector2 = elisio_corpo.global_position
	if modo == "ancorada":
		var ancora_camera := nova.get_node_or_null("AncoraCamera") as Marker2D
		if ancora_camera:
			pos_destino = ancora_camera.global_position
			zoom_destino = nova.zoom_camera if "zoom_camera" in nova else ZOOM_PADRAO

	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_position", pos_destino, DURACAO)
	tw.tween_property(camera, "zoom", zoom_destino, DURACAO)
	tw.tween_property(elisio_corpo, "global_position:y", elisio_corpo.global_position.y - 20.0, DURACAO) \
		.set_ease(Tween.EASE_OUT)
	await tw.finished

	tela_velha.queue_free()
	_tela_atual = nova
	_tela_atual_packed = proxima
	_seguindo = (modo != "ancorada")

	elisio_corpo.set_physics_process(true)
	if elisio_corpo.has_method("ao_entrar_na_tela"):
		elisio_corpo.ao_entrar_na_tela(nova)
	_em_transicao = false

## Recarrega a tela atual do zero (morte sem checkpoint mais recente que
## esta entrada, ou botão "Retry" do DeathMenu) mantendo o Elísio vivo --
## reposiciona no checkpoint ou, na falta dele, no Marker2D "Respawn".
func recarregar_tela() -> void:
	if _tela_atual == null or _tela_atual_packed == null:
		return
	var posicao_da_tela: Vector2 = _tela_atual.position
	var pacote := _tela_atual_packed
	_tela_atual.queue_free()

	var nova: Node2D = pacote.instantiate()
	nova.position = posicao_da_tela
	telas.add_child(nova)
	_tela_atual = nova

	elisio_corpo.visible = true
	elisio_corpo.velocity = Vector2.ZERO
	if SaveManager.has_checkpoint(nova.scene_file_path):
		elisio_corpo.global_position = SaveManager.checkpoint_position
	else:
		var respawn := nova.get_node_or_null("Respawn") as Marker2D
		if respawn:
			elisio_corpo.global_position = respawn.global_position
	elisio_corpo.heal()
	elisio_corpo.set_physics_process(true)

	_aplicar_camera_da_tela(nova, true)
	if elisio_corpo.has_method("ao_entrar_na_tela"):
		elisio_corpo.ao_entrar_na_tela(nova)
