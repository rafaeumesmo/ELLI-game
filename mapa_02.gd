extends Node2D

## Mapa 02: câmera fixa (uma tela só), igual às zonas fixas do mapa_01.
## Liga a FixedCamera e desliga a do player, a não ser que um checkpoint
## já tenha mandado usar outra câmera.

func _ready() -> void:
	if SaveManager.has_checkpoint(scene_file_path):
		# player.gd cuida da câmera do checkpoint no _ready dele.
		return
	for node in find_children("*", "Camera2D", true, false):
		(node as Camera2D).enabled = false
	var fixed_camera := get_node_or_null("FixedCamera") as Camera2D
	if fixed_camera:
		fixed_camera.enabled = true
