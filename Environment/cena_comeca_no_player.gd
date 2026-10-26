extends Node2D
## Cena que SEMPRE começa com a câmera do player ativa (seguindo ele livre) e
## só fixa quando ele alcança uma FixedCamera (via fixed_camera_zone.gd nas
## Area2D da cena). O oposto de cena_camera_fixa.gd (que já nasce fixa).
##
## Roda no _ready() em vez de depender de uma sobrescrita de `enabled` na
## instância do Player dentro da cena -- essa sobrescrita se perde toda vez
## que a cena é resalva no editor (ex.: desenhando tiles), então o estado
## inicial ficava quebrando sozinho. Aqui é garantido em código, imune a
## isso.

func _ready() -> void:
	if SaveManager.has_checkpoint(scene_file_path):
		# player.gd cuida da câmera do checkpoint no _ready dele.
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		player_camera.enabled = true
	for node in get_children():
		if node is Camera2D:
			(node as Camera2D).enabled = false
