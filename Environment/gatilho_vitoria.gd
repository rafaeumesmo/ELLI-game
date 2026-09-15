extends Area2D
## Gatilho de fim de jogo: posicione no ponto final da ultima fase. Quando o
## player encosta, mostra o menu de vitoria (uma unica vez).

var _disparado := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _disparado or not body.is_in_group("player"):
		return
	_disparado = true
	set_deferred("monitoring", false)
	var menu := get_tree().get_first_node_in_group("vitoria_menu")
	if menu != null:
		menu.mostrar()
