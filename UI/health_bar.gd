extends CanvasLayer

@onready var pips: Control = $Pips

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if pips.health != player.health or pips.max_health != player.max_health:
		pips.health = player.health
		pips.max_health = player.max_health
		pips.queue_redraw()
