extends Node2D
## Cena de tela única (ou de várias FixedCamera encadeadas, tipo mapa_07):
## liga a FixedCamera mais perto do player e desliga as demais, a não ser que
## um checkpoint já tenha mandado usar outra câmera. Acha a câmera mais
## próxima em vez de travar sempre na primeira ("FixedCamera") -- assim, se o
## player for reposicionado manualmente (testar direto de outro trecho do
## mapa no editor), a câmera já nasce fixada onde ele realmente está.

func _ready() -> void:
	if SaveManager.has_checkpoint(scene_file_path):
		# player.gd cuida da câmera do checkpoint no _ready dele.
		return
	# Só as FixedCamera que ficam soltas na cena (filhas diretas), não a
	# câmera que já vem dentro do próprio Player -- busca recursiva pegava
	# ela também, e como está grudada na posição dele a distância sempre dá
	# zero, então a "mais perto" acabava sendo sempre a do player.
	var cameras: Array[Camera2D] = []
	for node in get_children():
		if node is Camera2D:
			cameras.append(node)
	if cameras.is_empty():
		return
	var escolhida := cameras[0] as Camera2D
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		var menor_distancia := INF
		for node in cameras:
			var cam := node as Camera2D
			var distancia := cam.global_position.distance_squared_to((player as Node2D).global_position)
			if distancia < menor_distancia:
				menor_distancia = distancia
				escolhida = cam
	for node in cameras:
		(node as Camera2D).enabled = false
	escolhida.enabled = true
