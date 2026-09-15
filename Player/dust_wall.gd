extends GPUParticles2D
## Poeira contínua ao deslizar na parede. Liga sozinha lendo `is_wall_sliding`
## do player -- espelho exposto do `sticking_to_wall` que já decide o sprite
## wall_A/wall_D em _update_animation, mesma detecção, sem duplicar lógica.

@export var quantidade: int = 6
@export var vida: float = 0.4
## Distância (px) do centro do player até o emissor, espelhada pro lado da parede.
@export var offset_x: float = 4.0

@onready var _player = get_parent()
var _mat: ParticleProcessMaterial

func _ready() -> void:
	local_coords = false
	one_shot = false
	amount = quantidade
	lifetime = vida
	emitting = false
	texture = DustFxComum.textura_placeholder()  # TODO ARTE
	_mat = ParticleProcessMaterial.new()
	_mat.direction = Vector3(0, 1, 0)  # predominante pra baixo (escorregando)
	_mat.spread = 15.0
	_mat.gravity = Vector3(0, 90, 0)
	_mat.initial_velocity_min = 8.0
	_mat.initial_velocity_max = 20.0
	_mat.scale_min = 1.0
	_mat.scale_max = 1.8
	_mat.scale_curve = DustFxComum.curva_escala_decrescente()
	_mat.color_ramp = DustFxComum.rampa_alpha_sumindo(DustFxComum.COR_POEIRA)
	process_material = _mat

func _physics_process(_delta: float) -> void:
	emitting = _player.is_wall_sliding
	if not emitting:
		return
	# get_wall_normal() aponta da parede pro player; espelha o X pro lado dela.
	var lado := signf(_player.get_wall_normal().x)
	position = Vector2(-lado * offset_x, 4)
