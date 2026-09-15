extends Area2D

const ENERGIA_LUZ := 1.3

@onready var visual: Sprite2D = $Visual
@onready var particles: CPUParticles2D = $Particles
@onready var luz: PointLight2D = $Luz

var activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Se este já é o checkpoint salvo (voltou de um renascimento),
	# começa colorido e aceso, sem efeito.
	if _ja_e_o_checkpoint_ativo():
		activated = true
		_set_saturacao(1.0)
		luz.energy = ENERGIA_LUZ
	else:
		_set_saturacao(0.0)
		luz.energy = 0.0

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# Salva UMA vez. Re-entrar num checkpoint ja ativo (ex.: cair de volta nele
	# depois de quebrar um bloco mais acima) NAO pode re-congelar o que voce fez
	# desde que ativou — isso so acontece no proximo checkpoint.
	if activated:
		return
	activated = true
	_ativar_visual()
	var scene := get_tree().current_scene
	# Cura total na primeira vez que o player ativa este checkpoint.
	if not SaveManager.checkpoint_ja_ativado(scene.scene_file_path, global_position):
		SaveManager.registrar_checkpoint_ativado(scene.scene_file_path, global_position)
		if body.has_method("heal"):
			body.heal()
	# Se o player já pegou a espada, o checkpoint grava isso de vez.
	if body.get("tem_espada"):
		SaveManager.tem_espada = true
	if body.get("dash_desbloqueado"):
		SaveManager.tem_dash = true
	var player_camera := body.get_node_or_null("Camera2D")
	var active_camera := get_viewport().get_camera_2d()
	var camera_path := ""
	if active_camera and active_camera != player_camera:
		camera_path = str(scene.get_path_to(active_camera))
	SaveManager.set_checkpoint(scene.scene_file_path, global_position, camera_path)

func _ja_e_o_checkpoint_ativo() -> bool:
	return SaveManager.checkpoint_active \
		and global_position.distance_to(SaveManager.checkpoint_position) < 1.0

func _ativar_visual() -> void:
	particles.emitting = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_saturacao, 0.0, 1.0, 0.3)
	tween.tween_property(luz, "energy", ENERGIA_LUZ, 0.4)

func _set_saturacao(valor: float) -> void:
	visual.material.set_shader_parameter("saturation", valor)
