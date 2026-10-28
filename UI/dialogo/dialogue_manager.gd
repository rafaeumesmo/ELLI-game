extends Node
## Autoload DialogueManager: roda uma conversa (DialogueData) na DialogueBox.
##
## start(dialogo, speakers) -- speakers é um Dictionary {id do CharacterData:
## Node2D de quem fala}. Os nós servem pra câmera enquadrar a conversa e pro
## NPC tocar a animação "falando" (se o AnimatedSprite2D dele tiver uma)
## enquanto o texto digita. Quem tiver id "elisio" e não vier no dicionário é
## achado sozinho (grupo "player").
##
## Enquanto a conversa roda o player fica travado (mesmo esquema do caracol
## tutor: physics_process desligado), o HUD some com fade e o "interagir" vai
## pra cá: completa a página se ainda digitando, senão avança, e na última fecha.
## Posição, cores, fonte, velocidade e zoom ficam nos exports da DialogueBox.tscn.

signal dialogue_started(dialogue: DialogueData)
signal line_shown(line: DialogueLine, index: int)
signal dialogue_finished(dialogue: DialogueData)

const CENA_CAIXA := preload("res://UI/dialogo/DialogueBox.tscn")
## CanvasLayers de HUD que somem durante a conversa (além do grupo "hud").
const NOMES_HUD := ["Cronometro"]
const DURACAO_HUD := 0.2

var is_active: bool = false

var _caixa: CanvasLayer
var _dialogo: DialogueData
var _falantes: Dictionary = {}
var _idx := 0
var _paginas: Array[Dictionary] = []
var _pagina := 0
var _alvo: Node2D
var _player_travado: Node
## Sprite do falante tocando "falando" -> animação que ele tocava antes.
var _sprite_falando: AnimatedSprite2D
var _anim_antes := ""
var _hud_escondido: Array[CanvasItem] = []
var _camera: Camera2D
var _camera_zoom := Vector2.ONE
var _camera_pos := Vector2.ZERO
var _tw_camera: Tween

func _ready() -> void:
	_caixa = CENA_CAIXA.instantiate()
	add_child(_caixa)

func start(dialogue: DialogueData, speakers: Dictionary = {}) -> void:
	if is_active or dialogue == null or dialogue.falas.is_empty():
		return
	is_active = true
	_dialogo = dialogue
	_falantes = speakers
	_idx = 0
	_travar_player()
	_esconder_hud(true)
	_caixa.abrir(_player_travado as Node2D)
	_aproximar_camera(true)
	_mostrar_fala()
	dialogue_started.emit(dialogue)

func _unhandled_input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interagir") and not event.is_echo():
		get_viewport().set_input_as_handled()
		avancar()

func _process(_delta: float) -> void:
	if not is_active:
		return
	# Quem falava sumiu (troca de cena, morreu...): encerra em vez de deixar a
	# caixa e o player travados.
	if _alvo != null and not is_instance_valid(_alvo):
		_encerrar()
		return
	if _sprite_falando != null and not _caixa.digitando:
		_parar_falando()

func avancar() -> void:
	if not is_active:
		return
	if _caixa.digitando:
		_caixa.completar()
		return
	_pagina += 1
	if _pagina < _paginas.size():
		_caixa.mostrar_pagina(_paginas[_pagina])
		_tocar_falando()
		return
	_idx += 1
	if _idx < _dialogo.falas.size():
		_mostrar_fala()
		return
	_encerrar()

func _mostrar_fala() -> void:
	var fala := _dialogo.falas[_idx]
	_parar_falando()
	_alvo = _achar_falante(fala.personagem)
	_caixa.definir_falante(fala.personagem, fala.expressao)
	_paginas = _caixa.paginar(fala.texto)
	_pagina = 0
	_caixa.mostrar_pagina(_paginas[0])
	_tocar_falando()
	line_shown.emit(fala, _idx)

func _achar_falante(personagem: CharacterData) -> Node2D:
	if personagem == null:
		return null
	var no: Variant = _falantes.get(personagem.id)
	if is_instance_valid(no) and no is Node2D:
		return no
	if personagem.id == "elisio":
		return get_tree().get_first_node_in_group("player") as Node2D
	return null

func _encerrar() -> void:
	var dialogo := _dialogo
	is_active = false
	_parar_falando()
	_dialogo = null
	_falantes = {}
	_alvo = null
	_caixa.fechar()
	_esconder_hud(false)
	_aproximar_camera(false)
	_destravar_player()
	dialogue_finished.emit(dialogo)

# --- Animação "falando" do NPC no mundo --------------------------------------

func _tocar_falando() -> void:
	if not is_instance_valid(_alvo):
		return
	var sprite := _alvo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("falando"):
		return
	_sprite_falando = sprite
	_anim_antes = sprite.animation
	sprite.play("falando")

func _parar_falando() -> void:
	if _sprite_falando != null and is_instance_valid(_sprite_falando):
		_sprite_falando.play(_anim_antes)
	_sprite_falando = null

# --- HUD ---------------------------------------------------------------------

## Some com o HUD (cronômetro, vida...) durante a conversa e traz de volta ao
## fechar. Mexe no modulate dos filhos de cada CanvasLayer de HUD.
func _esconder_hud(esconder: bool) -> void:
	if esconder:
		_hud_escondido.clear()
		var camadas: Array[Node] = get_tree().get_nodes_in_group("hud")
		for nome: String in NOMES_HUD:
			camadas.append_array(get_tree().root.find_children(nome, "CanvasLayer", true, false))
		for camada in camadas:
			for filho in camada.get_children():
				if filho is CanvasItem and not _hud_escondido.has(filho):
					_hud_escondido.append(filho)
	for item in _hud_escondido:
		if is_instance_valid(item):
			create_tween().tween_property(item, "modulate:a", 0.0 if esconder else 1.0, DURACAO_HUD)
	if not esconder:
		_hud_escondido.clear()

# --- Câmera ------------------------------------------------------------------

## Zoom-in leve enquadrando o Elísio e quem fala, sem mostrar nada fora do que
## a câmera já mostrava (a tela fixa não tem nada desenhado além da borda).
func _aproximar_camera(aproximar: bool) -> void:
	if not _caixa.zoom_camera:
		return
	if _tw_camera != null and _tw_camera.is_valid():
		_tw_camera.kill()
	if not aproximar:
		if is_instance_valid(_camera):
			_tw_camera = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tw_camera.tween_property(_camera, "zoom", _camera_zoom, _caixa.duracao_zoom)
			_tw_camera.tween_property(_camera, "global_position", _camera_pos, _caixa.duracao_zoom)
		_camera = null
		return
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return
	_camera_zoom = _camera.zoom
	_camera_pos = _camera.global_position
	var pontos: Array[Vector2] = []
	if is_instance_valid(_player_travado):
		pontos.append((_player_travado as Node2D).global_position)
	for no: Variant in _falantes.values():
		if is_instance_valid(no) and no is Node2D:
			pontos.append((no as Node2D).global_position)
	var centro := _camera.get_screen_center_position()
	var alvo := centro
	if not pontos.is_empty():
		var soma := Vector2.ZERO
		for p in pontos:
			soma += p
		alvo = soma / pontos.size()
	var zoom_novo: Vector2 = _camera_zoom * float(_caixa.zoom_fator)
	var tela := get_viewport().get_visible_rect().size
	var folga: Vector2 = tela * 0.5 / _camera_zoom - tela * 0.5 / zoom_novo
	var desloc := (alvo - centro).clamp(-folga, folga)
	_tw_camera = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_camera.tween_property(_camera, "zoom", zoom_novo, _caixa.duracao_zoom)
	_tw_camera.tween_property(_camera, "global_position", _camera_pos + desloc, _caixa.duracao_zoom)

# --- Player ------------------------------------------------------------------

func _travar_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_player_travado = player
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.set_physics_process(false)
	# Sem o physics_process a animação congelaria no que estava (correndo...).
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and "last_dir" in player:
		sprite.play("idle_" + str(player.last_dir))

func _destravar_player() -> void:
	if _player_travado != null and is_instance_valid(_player_travado):
		_player_travado.set_physics_process(true)
	_player_travado = null
