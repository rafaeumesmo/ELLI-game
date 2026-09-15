extends AnimatedSprite2D

## Demo do wall-jump no tutorial: a Elli sobe a parede em ziguezague, em loop.
##
## Só aparece quando o player chega perto (Area2D filho "AreaDica"); continua
## rodando mesmo com o player grudado na parede.

## Nome da animação no SpriteFrames.
@export var anim: String = "subir"

func _ready() -> void:
	visible = false
	stop()
	var area := $AreaDica as Area2D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	visible = true
	frame = 0
	play(anim)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	visible = false
	stop()
