extends SceneTree
## Executar com dados de usuário isolados para não alterar uma partida real.

func _initialize() -> void:
	call_deferred("_testar")

func _testar() -> void:
	var save := root.get_node("SaveManager")
	var dialogos := root.get_node("DialogueManager")
	save.clear_save()
	for nome in ["caracol_mae", "caracol_bebe"]:
		var conversa := load("res://dialogues/%s.tres" % nome) as DialogueData
		assert(conversa != null and not conversa.falas.is_empty())
		for fala in conversa.falas:
			assert(fala.personagem != null and not fala.texto.is_empty())
	change_scene_to_file("res://tutorial.tscn")
	await scene_changed
	await create_timer(1.0).timeout
	assert(not dialogos.is_active, "O tutorial não deve iniciar monólogo")
	var dicas := current_scene.get_node("DicasControles")
	assert(dicas is Node2D and not dicas is CanvasLayer)
	assert(dicas.has_method("_tecla") and dicas.has_method("_texto"))
	assert(not dicas.is_processing(), "A colinha de pedra deve ser estática")
	assert(dicas.z_index > current_scene.get_node("FundoDaFase").z_index)
	assert(dicas.z_index > current_scene.get_node("Blocos").z_index)
	assert(not dialogos.is_active)
	print("OK: tutorial sem monólogo; colinha de pedra estática no cenário, sobre a face do chão; diálogos dos caracóis válidos")
	quit(0)
