extends Area2D
## Zona de uma tela numa corrente de FixedCameras (fases compridas tipo
## mapa_10). Cada zona cobre a área de UMA tela e aponta pra câmera dela:
## o player entrou na zona -> essa câmera assume, deslizando a partir da que
## estava ativa. Diferente do fixed_camera_switch_zone.gd (que alterna A<->B
## no toque e pode errar se o player encostar e voltar), aqui a câmera é
## sempre a da tela onde o player está -- dá pra ir e voltar à vontade.
## Se as zonas se sobrepõem e ele sai de uma ainda dentro de outra, a outra
## reassume.
##
## Uso: uma ZonaCamera por tela, CollisionShape2D cobrindo a tela inteira
## (encostando na zona vizinha) e `camera` apontando pra FixedCamera dela.

@export var camera: NodePath
@export var transition_time: float = 0.5

var _ready_physics_frame: int = -1

func _ready() -> void:
	add_to_group("zona_camera")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ready_physics_frame = Engine.get_physics_frames()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		ativar(_is_initial_overlap())

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	for zona in get_tree().get_nodes_in_group("zona_camera"):
		if zona != self and zona.overlaps_body(body):
			zona.ativar(false)
			return

func ativar(instantaneo: bool) -> void:
	var incoming := get_node_or_null(camera) as Camera2D
	if incoming == null or incoming.enabled:
		return
	var outgoing := get_viewport().get_camera_2d()
	if instantaneo or outgoing == null or outgoing == incoming:
		_snap(outgoing, incoming)
	else:
		_switch(outgoing, incoming)

func _is_initial_overlap() -> bool:
	# Mesma ressalva do fixed_camera_zone.gd: body_entered de quem já está
	# sobrepondo no _ready só dispara depois, então trata como "já estava
	# aqui" (snap em vez de animar).
	return Engine.get_physics_frames() - _ready_physics_frame <= 2

func _snap(outgoing: Camera2D, incoming: Camera2D) -> void:
	_matar_tween_anterior(incoming)
	incoming.offset = Vector2.ZERO
	incoming.reset_smoothing()
	incoming.enabled = true
	if outgoing and outgoing != incoming:
		outgoing.enabled = false

func _switch(outgoing: Camera2D, incoming: Camera2D) -> void:
	var start_offset := outgoing.get_screen_center_position() - incoming.global_position
	var start_zoom := outgoing.zoom
	var target_zoom := incoming.zoom

	_matar_tween_anterior(incoming)

	incoming.offset = start_offset
	incoming.zoom = start_zoom
	incoming.reset_smoothing()
	incoming.enabled = true
	outgoing.enabled = false

	var tween := incoming.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(incoming, "offset", Vector2.ZERO, transition_time)
	tween.tween_property(incoming, "zoom", target_zoom, transition_time)
	incoming.set_meta("transition_tween", tween)

## get_meta(key, null) ainda solta erro no console se a chave nunca foi
## setada -- null explícito não conta como "tem padrão" pro Godot.
func _matar_tween_anterior(incoming: Camera2D) -> void:
	if incoming.has_meta("transition_tween"):
		var previous_tween: Tween = incoming.get_meta("transition_tween")
		if previous_tween:
			previous_tween.kill()
