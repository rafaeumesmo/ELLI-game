extends GPUParticles2D
## Poeira contínua ao correr no chão. Liga sozinha lendo `is_on_floor()` e
## `velocity.x` do player (nó pai) -- os mesmos usados no movimento dele, só
## que lidos aqui, sem mexer em nada.

## Velocidade horizontal mínima (px/s) pra poeira começar a sair.
@export var limiar_velocidade: float = 40.0
@export var quantidade: int = 8
@export var vida: float = 0.4
@export var escala_min: float = 1.0
@export var escala_max: float = 2.2

@onready var _player = get_parent()
var _mat: ParticleProcessMaterial

func _ready() -> void:
	local_coords = false
	one_shot = false
	amount = quantidade
	lifetime = vida
	emitting = false
	position = Vector2(0, 8)  # altura dos pés (colisão do player: size 10x12, position y=2)
	texture = DustFxComum.textura_placeholder()  # TODO ARTE
	_mat = ParticleProcessMaterial.new()
	_mat.spread = 20.0
	_mat.gravity = Vector3(0, 40, 0)
	_mat.initial_velocity_min = 10.0
	_mat.initial_velocity_max = 22.0
	_mat.scale_min = escala_min
	_mat.scale_max = escala_max
	_mat.scale_curve = DustFxComum.curva_escala_decrescente()
	_mat.color_ramp = DustFxComum.rampa_alpha_sumindo(DustFxComum.COR_POEIRA)
	process_material = _mat

func _physics_process(_delta: float) -> void:
	emitting = _player.is_on_floor() and absf(_player.velocity.x) > limiar_velocidade
	if not emitting:
		return
	# Sai pro lado oposto ao movimento, com uma leve puxada pra cima.
	var direcao_oposta := -signf(_player.velocity.x)
	_mat.direction = Vector3(direcao_oposta, -0.3, 0.0)
