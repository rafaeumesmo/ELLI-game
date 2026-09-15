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
@onready var porta_camera: Node2D = $PortaCamera
@onready var camera: Camera2D = $PortaCamera/Camera

var _tela_atual: Node2D = null
var _tela_atual_packed: PackedScene = null
var _em_transicao: bool = false
var _seguindo: bool = true

func _ready() -> void:
	add_to_group("gerenciador")
	camera.position_smoothing_enabled = false
	camera.make_current()
	if tela_inicial:
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
##
## A PortaCamera precisa voltar pra identidade aqui: em modo "ancorada" ela
## fica com o transform (e a escala 3.65) da tela, e uma Camera2D herda a
## escala do pai no cálculo do zoom -- sem resetar, o zoom_padrao (1,1)
## renderizaria escalado por engano.
func seguir_jogador(instantaneo: bool = false) -> void:
	porta_camera.global_transform = Transform2D.IDENTITY
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

## Câmera fixa relativa à `tela`: a PortaCamera assume o global_transform
## da tela (mesma posição/escala que o root tinha quando era ela a mãe
## direta da câmera fixa original) e a Camera recebe `posicao_local`/`zoom`
## exatamente como foram autorados -- sem nenhuma conversão. `instantaneo`
## pula o tween.
func ancorada(tela: Node2D, posicao_local: Vector2, zoom: Vector2 = ZOOM_PADRAO, instantaneo: bool = false) -> void:
	_seguindo = false
	porta_camera.global_transform = tela.global_transform
	if instantaneo or _em_transicao:
		camera.position = posicao_local
		camera.zoom = zoom
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "position", posicao_local, DURACAO_ANCORA)
	tw.tween_property(camera, "zoom", zoom, DURACAO_ANCORA)

# --- Carregamento de telas -----------------------------------------------

func _carregar_tela_inicial() -> void:
	var nova: Node2D = tela_inicial.instantiate()
	nova.position = Vector2.ZERO
	telas.add_child(nova)
	_tela_atual = nova
	_tela_atual_packed = tela_inicial
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
		var posicao_local: Vector2 = tela.camera_posicao if "camera_posicao" in tela else Vector2.ZERO
		var zoom: Vector2 = tela.camera_zoom if "camera_zoom" in tela else ZOOM_PADRAO
		ancorada(tela, posicao_local, zoom, instantaneo)
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
	# Preserva a posição global atual da câmera ANTES de trocar o transform da
	# PortaCamera -- senão o valor local antigo de camera.position passaria a
	# apontar pra outro ponto do mundo assim que o contexto mudar de baixo dela.
	var pos_global_atual: Vector2 = camera.global_position
	if modo == "ancorada":
		pos_destino = nova.camera_posicao if "camera_posicao" in nova else Vector2.ZERO
		zoom_destino = nova.camera_zoom if "camera_zoom" in nova else ZOOM_PADRAO
		porta_camera.global_transform = nova.global_transform
	else:
		porta_camera.global_transform = Transform2D.IDENTITY
	camera.global_position = pos_global_atual

	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "position", pos_destino, DURACAO)
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
