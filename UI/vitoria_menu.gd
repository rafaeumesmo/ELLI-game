extends CanvasLayer
## Menu de vitoria: aparece ao terminar a ultima fase. Trava o player do MESMO
## jeito que a conversa obrigatoria do caracol (Environment/caracol.gd::
## _iniciar_dialogo) -- so desliga o physics_process dele, sem pausar a arvore.

const MENU_PRINCIPAL := "res://UI/MainMenu.tscn"

@onready var _fundo: ColorRect = $Fundo
@onready var _caixa: VBoxContainer = $Caixa
@onready var _jogar_de_novo: Button = $Caixa/JogarDeNovoButton
@onready var _menu_principal: Button = $Caixa/MenuPrincipalButton

func _ready() -> void:
	add_to_group("vitoria_menu")
	hide()
	_fundo.modulate.a = 0.0
	_caixa.modulate.a = 0.0
	_jogar_de_novo.pressed.connect(_on_jogar_de_novo_pressed)
	_menu_principal.pressed.connect(_on_menu_principal_pressed)

## Mostra a tela: fade do fundo escuro e so depois os botoes, travando o player.
func mostrar() -> void:
	if visible:
		return
	show()
	_travar_player()

	var tw := create_tween()
	tw.tween_property(_fundo, "modulate:a", 1.0, 0.5)
	tw.tween_property(_caixa, "modulate:a", 1.0, 0.25)
	tw.tween_callback(_jogar_de_novo.grab_focus)

func _travar_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.set_physics_process(false)

func _on_jogar_de_novo_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_principal_pressed() -> void:
	get_tree().change_scene_to_file(MENU_PRINCIPAL)
