extends Area2D
## Espada largada no chão (deitada). Player chega perto → aparece o "E"; aperta E →
## a espada dá um flourish (levanta girando e some) e o player equipa (`equip_gun`),
## o que já liga o ataque (`shoot` vira golpe).

@onready var _sprite: Sprite2D = $Sprite
@onready var _dica: Label = $Dica/Texto
@onready var _brilho: CPUParticles2D = $Brilho

var _player_perto := false
var _coletando := false

func _ready() -> void:
	# Já pegou a espada num save anterior: não reaparece.
	if SaveManager.tem_espada:
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_dica.text = "E"
	_dica.modulate.a = 0.0
	_dica.reset_size()

func _process(delta: float) -> void:
	# Ancora a dica "E" acima da espada, em pixels de tela (não escala com o zoom).
	var xf := get_viewport().get_canvas_transform()
	var ancora := xf * (global_position + Vector2(0, -16))
	_dica.position = (ancora - Vector2(_dica.size.x * 0.5, _dica.size.y)).round()
	var alvo := 1.0 if (_player_perto and not _coletando) else 0.0
	_dica.modulate.a = move_toward(_dica.modulate.a, alvo, delta * 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if _coletando or not _player_perto:
		return
	if event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		_coletar()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_perto = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_perto = false

func _coletar() -> void:
	_coletando = true
	_brilho.emitting = false
	# Flourish: a espada levanta girando e some.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "rotation", -TAU * 0.75, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position:y", _sprite.position.y - 12.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sprite, "scale", Vector2(1.4, 1.4), 0.32)
	tw.set_parallel(false)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.14)
	tw.tween_callback(_equipar)

func _equipar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("equip_gun"):
		player.equip_gun()
	queue_free()
