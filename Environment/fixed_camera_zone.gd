extends Area2D

@export var fixed_camera_path: NodePath
@export var activate: bool = true
@export var transition_time: float = 0.5

var _ready_physics_frame: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ready_physics_frame = Engine.get_physics_frames()

func _on_body_entered(body: Node) -> void:
	_set_state(body, activate, _is_initial_overlap())

func _on_body_exited(body: Node) -> void:
	_set_state(body, not activate, false)

func _is_initial_overlap() -> bool:
	# Area2D body_entered is emitted via a deferred call, so a body already
	# overlapping when the scene loads still fires this a frame or two after
	# _ready. Treat anything that close to scene start as "already there"
	# and snap instead of animating; a real walk-in happens far later.
	return Engine.get_physics_frames() - _ready_physics_frame <= 2

func _set_state(body: Node, is_active: bool, instant: bool) -> void:
	if not body.is_in_group("player"):
		return
	var fixed_camera := get_node_or_null(fixed_camera_path) as Camera2D
	var player_camera := body.get_node_or_null("Camera2D")
	if not fixed_camera or not player_camera:
		return
	var incoming := fixed_camera if is_active else player_camera
	var outgoing := player_camera if is_active else fixed_camera
	if instant:
		_snap_camera(outgoing, incoming)
	else:
		_switch_camera(outgoing, incoming)

func _snap_camera(outgoing: Camera2D, incoming: Camera2D) -> void:
	var previous_tween: Tween = incoming.get_meta("transition_tween", null)
	if previous_tween:
		previous_tween.kill()
	incoming.offset = Vector2.ZERO
	incoming.reset_smoothing()
	incoming.enabled = true
	outgoing.enabled = false

func _switch_camera(outgoing: Camera2D, incoming: Camera2D) -> void:
	var start_offset := outgoing.global_position - incoming.global_position
	var start_zoom := outgoing.zoom
	var target_zoom := incoming.zoom

	var previous_tween: Tween = incoming.get_meta("transition_tween", null)
	if previous_tween:
		previous_tween.kill()

	incoming.offset = start_offset
	incoming.zoom = start_zoom
	incoming.reset_smoothing()
	incoming.enabled = true
	outgoing.enabled = false

	var tween := incoming.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(incoming, "offset", Vector2.ZERO, transition_time)
	tween.tween_property(incoming, "zoom", target_zoom, transition_time)
	incoming.set_meta("transition_tween", tween)
