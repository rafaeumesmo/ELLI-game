extends SceneTree

func _initialize() -> void:
	call_deferred("_testar")

func _testar() -> void:
	# Executar a cena diretamente (F6) também deve começar sem piscar o texto.
	change_scene_to_file("res://UI/Creditos.tscn")
	await scene_changed
	assert(not current_scene.get("_conteudo").visible)
	await create_timer(0.5).timeout
	assert(not current_scene.get("_conteudo").visible)
	await create_timer(0.4).timeout
	var conteudo := current_scene.get("_conteudo") as Control
	var janela := current_scene.get_node("Caixa/JanelaCreditos") as Control
	assert(conteudo.visible and current_scene.get("_rolando"))
	assert(conteudo.position.y >= janela.size.y - 12.0, "Texto deve entrar pela parte inferior")
	print("OK: texto invisível na abertura e entrada pela parte inferior após o fade")
	change_scene_to_file("res://mapa_10.tscn")
	await scene_changed
	var fase := current_scene as Node2D
	await physics_frame
	var portal := fase.get_node("PortalFase")
	var jogador := get_first_node_in_group("player") as CharacterBody2D
	portal.call("_on_body_entered", jogador)
	if not portal.call("foi_pego") or jogador.is_physics_processing():
		push_error("Portal final não iniciou o encerramento")
		quit(1)
		return
	await create_timer(2.6).timeout
	if current_scene.scene_file_path != "res://UI/Creditos.tscn":
		push_error("Não chegou aos créditos")
		quit(2)
		return
	if not current_scene.visible or not current_scene.get("_rolando"):
		push_error("Créditos não abriram automaticamente")
		quit(3)
		return
	var texto := ""
	for trecho in current_scene.get("_conteudo").get_children():
		texto += trecho.get_parsed_text() + "\n"
	for esperado in ["ELLI: UNDERSTORY", "Uma pequena história sobre se perder, descobrir e seguir em frente.", "CRIADO E DESENVOLVIDO POR", "RAFAEL SEVERO", "Conceito e narrativa", "Programação e desenvolvimento", "Arte e animação", "Design de fases", "Direção criativa", "AGRADECIMENTOS", "A todos que, de alguma forma, fizeram parte desta jornada.", "E a você, que decidiu seguir as pequenas luzes até o fim.", "Nem toda luz existe para nos mostrar o caminho.", "Algumas aparecem apenas para nos lembrar de que estivemos aqui.", "Obrigado por jogar."]:
		assert(esperado in texto, "Trecho ausente: " + esperado)
	var enxame := current_scene.get_node("VagalumesCreditos")
	assert(enxame.get_child_count() == 12)
	var vagalume := enxame.get_child(0) as Node2D
	var posicao := vagalume.position
	await create_timer(0.2).timeout
	assert(vagalume.position.distance_to(posicao) > 0.01, "Vagalume parado")
	current_scene.call("_process", 10000.0)
	assert(not current_scene.get("_rolando"), "Mensagem final deve permanecer na tela")
	await create_timer(1.5).timeout
	assert(not current_scene.get_node("Caixa").visible)
	var final := current_scene.get_node("ObrigadoFinal") as Label
	assert(final.visible and final.modulate.a > 0.99)
	assert(final.text == "Obrigado por jogar.")
	assert(final.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	assert(final.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
	print("OK: texto completo e vagalumes; ao terminar a rolagem, apenas Obrigado por jogar centralizado, sem título ou botões")
	quit(0)
