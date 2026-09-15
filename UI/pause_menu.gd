extends CanvasLayer

@onready var resume_button: Button = $VBoxContainer/ContinuarButton
@onready var menu_button: Button = $VBoxContainer/MenuButton
@onready var quit_button: Button = $VBoxContainer/SairButton

func _ready() -> void:
	hide()
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

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

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	hide()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
