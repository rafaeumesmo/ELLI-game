extends CanvasLayer

@onready var retry_button: Button = $VBoxContainer/RetryButton
@onready var menu_button: Button = $VBoxContainer/MenuButton
@onready var quit_button: Button = $VBoxContainer/SairButton

func _ready() -> void:
	add_to_group("death_menu")
	hide()
	_setup_focus_chain([retry_button, menu_button, quit_button])
	retry_button.pressed.connect(_on_retry_pressed)
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

func show_death() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	show()
	retry_button.grab_focus()

func _on_retry_pressed() -> void:
	SaveManager.descartar_pendentes()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
