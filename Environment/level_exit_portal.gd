extends Area2D

@export_file("*.tscn") var next_scene: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if next_scene == "":
		push_warning("LevelExitPortal: defina 'Next Scene' no Inspector.")
		return
	# Trocar de fase também commita a espada (senão dá pra perder ela no portal).
	if body.get("tem_espada"):
		SaveManager.tem_espada = true
	if body.get("dash_desbloqueado"):
		SaveManager.tem_dash = true
	SaveManager.save_progress(next_scene)
	get_tree().paused = false
	get_tree().change_scene_to_file(next_scene)
