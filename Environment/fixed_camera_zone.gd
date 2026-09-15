extends Area2D
## Zona de câmera fixa dentro de uma tela do Mundo (hoje só a torre do
## mapa_01): ao entrar, ancora a câmera do Mundo num Marker2D; ao sair,
## volta a seguir o Elísio. Antes fazia isso ligando/desligando duas
## Camera2D (a do player e uma fixa) diretamente -- agora delega pro
## Mundo, que é quem de fato possui a câmera persistente.

@export var ancora_camera_path: NodePath
@export var zoom_camera: Vector2 = Vector2(0.9, 0.9)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var ancora := get_node_or_null(ancora_camera_path) as Marker2D
	if ancora == null:
		return
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	if mundo:
		# ancora.position é local à tela (a própria mãe do Marker2D) -- os
		# mesmos valores que a antiga IntroCamera tinha como filha direta dela.
		mundo.ancorada(ancora.get_parent() as Node2D, ancora.position, zoom_camera)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	if mundo:
		mundo.seguir_jogador()
