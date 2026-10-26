extends Area2D
## Zona que troca entre duas câmeras fixas da cena (ex.: sala que sobe e
## precisa de uma segunda FixedCamera pra parte de cima, ou uma corrente de
## telas encadeadas tipo mapa_07). Assim que o player TOCA a zona (não
## importa de que lado, nem em que ponto dela), ela alterna pra câmera que
## ainda não está ativa entre camera_a/camera_b -- não espera ele chegar no
## meio do caminho, então funciona mesmo em salas pequenas onde a zona nem
## cabe uma tela inteira. Sair da zona não faz nada (a troca já aconteceu no
## toque); assim funciona indo ou voltando, e não importa a posição relativa
## das duas câmeras (lado a lado, uma em cima da outra, ou na diagonal).

@export var camera_a: NodePath
@export var camera_b: NodePath
@export var transition_time: float = 0.5

var _ready_physics_frame: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_ready_physics_frame = Engine.get_physics_frames()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var cam_a := get_node_or_null(camera_a) as Camera2D
	var cam_b := get_node_or_null(camera_b) as Camera2D
	if not cam_a or not cam_b or cam_a == cam_b:
		return
	# Alterna pra quem não está ativa -- não precisa saber de que lado o
	# player veio, só precisa saber qual das duas já está mostrando a cena.
	var alvo := cam_b if cam_a.enabled else cam_a
	var outra := cam_a if alvo == cam_b else cam_b
	if _is_initial_overlap():
		_snap(outra, alvo)
	else:
		_switch(outra, alvo)

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
	outgoing.enabled = false

func _switch(outgoing: Camera2D, incoming: Camera2D) -> void:
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
