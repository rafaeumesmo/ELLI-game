extends Node2D
## Declara o modo de câmera padrão de uma tela gerida pelo Mundo (mundo.gd).
## Não liga câmera nenhuma sozinho -- só avisa o Mundo assim que a tela entra
## na árvore (o próprio Mundo decide se aplica na hora ou com um tween, como
## acontece durante subir_tela()).
##
## Substitui, só para as telas usadas pelo Mundo, o antigo par duplicado
## cena_camera_fixa.gd / mapa_02.gd -- que continuam intactos e em uso pelas
## fases que ainda trocam de cena (mapa_02 a mapa_05).
##
## "ancorada": a Camera do Mundo é reancorada com `camera_posicao`/`camera_zoom`
## -- os valores LOCAIS que a antiga FixedCamera desta tela tinha quando ainda
## era filha direta da raiz (posição/zoom originais, sem nenhuma conversão).
## "seguir": a câmera do Mundo acompanha o Elísio (mundo aberto, tipo mapa_01
## fora da TowerCameraZone).

@export_enum("ancorada", "seguir") var modo_camera: String = "ancorada"
@export var camera_posicao: Vector2 = Vector2.ZERO
@export var camera_zoom: Vector2 = Vector2(0.9, 0.9)

func _ready() -> void:
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	# Durante subir_tela() é o próprio Mundo quem já está montando o tween de
	# câmera pra esta tela -- não pisar nisso aplicando um modo instantâneo aqui.
	if mundo == null or mundo.em_transicao():
		return
	if modo_camera == "seguir":
		mundo.seguir_jogador(true)
		return
	mundo.ancorada(self, camera_posicao, camera_zoom, true)
