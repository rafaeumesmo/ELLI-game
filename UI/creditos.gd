extends "res://UI/vitoria_menu.gd"
## Cena final: usa os créditos existentes e abre assim que a transição termina.

func _ready() -> void:
	super._ready()
	mostrar()

func _on_jogar_de_novo_pressed() -> void:
	SaveManager.clear_save()
	SaveManager.clear_checkpoint()
	Transicao.ir_para_cena("res://queda_inicial.tscn")
