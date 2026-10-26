extends Area2D
## Zona de morte "errou o portal": se o player entrar nela sem ter encostado
## no vagalume-portal (PortalFase), morre. Serve pro pulo final até o portal --
## se ele pular e não pegar, cai aqui e renasce em vez de ficar caindo pra
## sempre. Se já pegou o portal, a zona não faz nada (ele pode cair à vontade
## enquanto o vagalume foge e a cena troca).
##
## Uso: arraste `ZonaMortePortal.tscn` pro mapa, embaixo/depois do pulo, e
## estica o CollisionShape2D pra cobrir a área. Por padrão vale qualquer
## PortalFase da cena; pra amarrar a um portal específico, preencha `portal`.

## Portal específico a checar. Vazio = qualquer PortalFase da cena.
@export var portal: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _portal_pego():
		return
	if body.has_method("die") and body.is_physics_processing():
		body.die()

func _portal_pego() -> bool:
	if not portal.is_empty():
		var p := get_node_or_null(portal)
		return p != null and p.has_method("foi_pego") and p.foi_pego()
	for p in get_tree().get_nodes_in_group("portal_fase"):
		if p.foi_pego():
			return true
	return false
