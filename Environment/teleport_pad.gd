extends Area2D
## Passagem discreta dentro do MESMO mapa: instale em pares. O player que encosta
## num pad reaparece instantaneamente na posição do pad indicado em `destino`
## (o outro da dupla). Sem visual, sem fade -- só atravessa.
##
## Uso: solte duas instâncias no mapa, em cada uma aponte `destino` pro NodePath
## da outra (arraste no Inspector depois de instanciar).

@export var destino: NodePath

var _bloqueado := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _bloqueado or not body.is_in_group("player"):
		return
	var alvo := get_node_or_null(destino) as Node2D
	if alvo == null:
		push_warning("TeleportPad: defina 'Destino' no Inspector.")
		return
	_teleportar(body, alvo)

func _teleportar(player: Node2D, alvo: Node2D) -> void:
	player.global_position = alvo.global_position
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	# Trava o pad de destino um instante pra ele não devolver o player na hora.
	if alvo.has_method("_bloquear_temporario"):
		alvo._bloquear_temporario()

func _bloquear_temporario() -> void:
	_bloqueado = true
	await get_tree().create_timer(0.3).timeout
	_bloqueado = false
