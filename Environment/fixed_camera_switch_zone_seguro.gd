extends Area2D
## Variante do fixed_camera_switch_zone.gd usada SÓ pela SubidaCameraZone do
## mapa_05. Mesmo comportamento de entrar/sair (troca camera_a <-> camera_b),
## mas com uma rede de segurança: a cada frame de física, enquanto camera_b
## estiver ativa, confere de verdade se o player ainda está dentro da zona.
## Se não estiver (ex.: errou o pulo, caiu rápido demais e o sinal de saída
## do Area2D não veio limpo), força a volta pra camera_a na mesma hora, em
## vez de ficar preso mostrando a câmera errada.
##
## Existe como arquivo separado -- e não uma mudança no
## fixed_camera_switch_zone.gd original -- de propósito: aquele script é
## usado por outras fases já fechadas (mapa_06, por exemplo), e essa correção
## é só pra esta cena.

@export var camera_a: NodePath
@export var camera_b: NodePath
@export var transition_time: float = 0.5

var _ready_physics_frame: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ready_physics_frame = Engine.get_physics_frames()

func _physics_process(_delta: float) -> void:
	var cam_b := get_node_or_null(camera_b) as Camera2D
	if not cam_b or not cam_b.enabled:
		return
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("player"):
			return
	var cam_a := get_node_or_null(camera_a) as Camera2D
	if cam_a:
		_switch(cam_b, cam_a)

func _on_body_entered(body: Node) -> void:
	_trocar(body, camera_a, camera_b, _is_initial_overlap())

func _on_body_exited(body: Node) -> void:
	_trocar(body, camera_b, camera_a, false)

func _is_initial_overlap() -> bool:
	# Mesma ressalva do fixed_camera_zone.gd: body_entered de quem já está
	# sobrepondo no _ready só dispara depois, então trata como "já estava
	# aqui" (snap em vez de animar).
	return Engine.get_physics_frames() - _ready_physics_frame <= 2

func _trocar(body: Node, de_path: NodePath, para_path: NodePath, instant: bool) -> void:
	if not body.is_in_group("player"):
		return
	var de := get_node_or_null(de_path) as Camera2D
	var para := get_node_or_null(para_path) as Camera2D
	if not de or not para or de == para:
		return
	if instant:
		_snap(de, para)
	else:
		_switch(de, para)

func _snap(outgoing: Camera2D, incoming: Camera2D) -> void:
	_matar_tween_anterior(incoming)
	incoming.offset = Vector2.ZERO
	incoming.reset_smoothing()
	incoming.enabled = true
	outgoing.enabled = false

func _switch(outgoing: Camera2D, incoming: Camera2D) -> void:
	if incoming.enabled:
		return
	var start_offset := outgoing.global_position - incoming.global_position
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
