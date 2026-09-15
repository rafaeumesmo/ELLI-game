extends Area2D
## Espada fincada no chão. Começa mostrando o último frame ("só a ponta pra fora").
## Quando o player está perto e aperta E, a animação roda do último pro primeiro frame
## (a espada "cresce" saindo do chão) e aí o player equipa.

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var dica: Label = $Dica/Texto
@onready var brilho: CPUParticles2D = $Brilho

var _player_perto: bool = false
var _coletando: bool = false

func _ready() -> void:
	# Já pegou a espada num save anterior: o pickup não reaparece.
	if SaveManager.tem_espada:
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.animation = &"surgir"
	sprite.frame = sprite.sprite_frames.get_frame_count(&"surgir") - 1
	sprite.pause()
	dica.text = "E"
	dica.modulate.a = 0.0
	dica.reset_size()

func _process(delta: float) -> void:
	# Ancora a dica "E" acima da espada, em pixels de tela (não escala com o zoom).
	var xf := get_viewport().get_canvas_transform()
	var ancora := xf * (global_position + Vector2(0, -20))
	dica.position = (ancora - Vector2(dica.size.x * 0.5, dica.size.y)).round()
	var alvo := 1.0 if (_player_perto and not _coletando) else 0.0
	dica.modulate.a = move_toward(dica.modulate.a, alvo, delta * 6.0)

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
	# Última cintilada: solta as partículas que ainda existem e para de emitir.
	brilho.emitting = false
	sprite.animation_finished.connect(_equipar, CONNECT_ONE_SHOT)
	sprite.play_backwards(&"surgir")

func _equipar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("equip_gun"):
		player.equip_gun()
	queue_free()
