extends Area2D

## Revela um nó (deixa `visible = true`) quando o player entra nesta área.
##
## Usado para ligar o parallax do fundo cogumelo só depois do checkpoint: o
## `FundoCogumelo` nasce com `visible = false` e este gatilho o acende quando o
## player passa. É de mão única — uma vez aceso, fica aceso (inclusive depois de
## renascer no checkpoint, que faz o player cruzar a área de novo).

## Nó que fica escondido até o player passar por aqui.
@export var alvo: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var node := get_node_or_null(alvo) as CanvasItem
	if node:
		node.visible = true
