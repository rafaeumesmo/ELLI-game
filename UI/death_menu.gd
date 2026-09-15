extends CanvasLayer

@onready var retry_button: Button = $VBoxContainer/RetryButton
@onready var menu_button: Button = $VBoxContainer/MenuButton
@onready var quit_button: Button = $VBoxContainer/SairButton

func _ready() -> void:
	add_to_group("death_menu")
	hide()
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func show_death() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	show()

func _on_retry_pressed() -> void:
	SaveManager.descartar_pendentes()
	get_tree().paused = false
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	if mundo != null:
		mundo.recarregar_tela()
	else:
		get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
