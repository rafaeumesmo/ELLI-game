extends SceneTree

class Jogador extends CharacterBody2D:
	var morreu := false
	func die() -> void:
		morreu = true
	func _physics_process(_delta: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("_testar")

func _testar() -> void:
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	for escala in [1.0, 3.65]:
		for caso in ["borda_esquerda", "borda_direita", "centro", "lateral_baixa", "por_baixo"]:
			var grupo := Node2D.new()
			grupo.scale = Vector2.ONE * escala
			cena.add_child(grupo)
			var agua := load("res://Environment/AguaViva.tscn").instantiate() as Node2D
			grupo.add_child(agua)
			agua.set_physics_process(false)
			var jogador := Jogador.new()
			var colisao := CollisionShape2D.new()
			var forma := RectangleShape2D.new()
			forma.size = Vector2(10, 12)
			colisao.shape = forma
			colisao.position.y = 2
			jogador.add_child(colisao)
			jogador.collision_layer = 1
			jogador.collision_mask = 0
			jogador.add_to_group("player")
			grupo.add_child(jogador)
			match caso:
				"borda_esquerda": jogador.position = Vector2(-14, -8)
				"borda_direita": jogador.position = Vector2(14, -8)
				"centro": jogador.position = Vector2(0, -16)
				"lateral_baixa": jogador.position = Vector2(8, 0)
				"por_baixo": jogador.position = Vector2(0, 14)
			jogador.velocity.y = 200
			for i in 3:
				await physics_frame
			agua.call("_checar_contato")
			var deve_quicar: bool = caso in ["borda_esquerda", "borda_direita", "centro"]
			if deve_quicar and (jogador.velocity.y >= 0 or jogador.morreu):
				push_error("Falhou o quique: %s escala %s" % [caso, escala])
				quit(1)
				return
			if not deve_quicar and not jogador.morreu:
				push_error("Contato inferior deveria continuar mortal: %s escala %s" % [caso, escala])
				quit(2)
				return
			grupo.queue_free()
			await process_frame
	print("OK: 10 cenários; centro e bordas quicam, laterais baixas e parte inferior continuam mortais, escalas 1 e 3.65")
	quit(0)
