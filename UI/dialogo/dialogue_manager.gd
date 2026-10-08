extends Node
## Autoload DialogueManager: roda uma conversa (DialogueData) na DialogueBox.
##
## start(dialogo, speakers) -- speakers é um Dictionary {id do CharacterData:
## Node2D de quem fala}; a caixa pula pra cima de quem estiver falando. Quem
## tiver id "elisio" e não vier no dicionário é achado sozinho (grupo "player").
##
## Enquanto a conversa roda o player fica travado (mesmo esquema do caracol
## tutor: physics_process desligado) e o "interagir" vai pra cá: completa a
## página se ainda digitando, senão avança, e na última fecha.

signal dialogue_started(dialogue: DialogueData)
signal line_shown(line: DialogueLine, index: int)
signal dialogue_finished(dialogue: DialogueData)

const CENA_CAIXA := preload("res://UI/dialogo/DialogueBox.tscn")

var is_active: bool = false

var _caixa: CanvasLayer
var _dialogo: DialogueData
var _falantes: Dictionary = {}
var _idx := 0
var _paginas := PackedStringArray()
var _pagina := 0
var _alvo: Node2D
var _player_travado: Node

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
	_mostrar_fala()
	_caixa.abrir()
	dialogue_started.emit(dialogue)

func _unhandled_input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interagir") and not event.is_echo():
		get_viewport().set_input_as_handled()
		avancar()

func _process(_delta: float) -> void:
	# Quem falava sumiu (troca de cena, morreu...): encerra em vez de deixar a
	# caixa e o player travados.
	if is_active and _alvo != null and not is_instance_valid(_alvo):
		_encerrar()

func avancar() -> void:
	if not is_active:
		return
	if _caixa.digitando:
		_caixa.completar()
		return
	_pagina += 1
	if _pagina < _paginas.size():
		_caixa.mostrar_pagina(_paginas[_pagina])
		return
	_idx += 1
	if _idx < _dialogo.falas.size():
		_mostrar_fala()
		return
	_encerrar()

func _mostrar_fala() -> void:
	var fala := _dialogo.falas[_idx]
	_alvo = _achar_falante(fala.personagem)
	_caixa.definir_falante(fala.personagem, fala.expressao, _alvo)
	_paginas = _caixa.paginar(fala.texto)
	_pagina = 0
	_caixa.mostrar_pagina(_paginas[0])
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
	_dialogo = null
	_falantes = {}
	_alvo = null
	_caixa.fechar()
	_destravar_player()
	dialogue_finished.emit(dialogo)

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
