extends Area2D
## Borda de saída de uma tela gerida pelo Mundo: encostar aqui (sendo do
## grupo "player") sobe pra próxima tela via Mundo.subir_tela() -- sem
## trocar de cena, sem fade.
##
## É a versão "mundo contínuo" do PortalFase.gd, que continua intacto e em
## uso pelas fases que ainda trocam de cena (mapa_02 a mapa_05).

@export var proxima_tela: PackedScene

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if proxima_tela == null or not body.is_in_group("player"):
		return
	var mundo := get_tree().get_first_node_in_group("gerenciador")
	if mundo == null:
		push_warning("BordaSuperior: nenhum nó no grupo 'gerenciador' encontrado.")
		return
	# Mesma lógica de commit que o PortalFase já fazia antes de trocar de fase.
	if body.get("tem_espada"):
		SaveManager.tem_espada = true
	if body.get("dash_desbloqueado"):
		SaveManager.tem_dash = true
	SaveManager.save_progress(proxima_tela.resource_path)
	mundo.subir_tela(proxima_tela)
