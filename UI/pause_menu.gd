extends CanvasLayer

@onready var resume_button: Button = $VBoxContainer/ContinuarButton
@onready var menu_button: Button = $VBoxContainer/MenuButton
@onready var quit_button: Button = $VBoxContainer/SairButton

var _buttons: Array[Button]

func _ready() -> void:
	hide()
	_buttons = [resume_button, menu_button, quit_button]
	_setup_focus_chain(_buttons)
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

## Liga vizinho de cima/baixo em cadeia (com volta no topo/fim) pra setinha +
## Enter navegarem a lista de botões -- mesmo esquema do main_menu.gd.
func _setup_focus_chain(buttons: Array[Button]) -> void:
	for i in buttons.size():
		var prev_button: Button = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next_button: Button = buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(prev_button)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(next_button)

func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel = tecla Esc por padrão no Godot
	if not event.is_action_pressed("ui_cancel"):
		return
	# Só pausa dentro do jogo (cena com player). Nos menus o Esc passa direto.
	if not get_tree().paused and get_tree().get_first_node_in_group("player") == null:
		return
	toggle_pause()
	get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if get_tree().paused:
		_on_resume_pressed()
	else:
		get_tree().paused = true
		show()
		resume_button.grab_focus()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	hide()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_quit_pressed() -> void:
	SaveManager.salvar_tempo()
	get_tree().quit()
