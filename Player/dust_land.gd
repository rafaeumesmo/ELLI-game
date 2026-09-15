extends GPUParticles2D
## Poeira em burst ao aterrissar. Ouve o sinal `landed(impact_speed)` do
## player (emitido em player.gd::_physics_process, exposto só pra isso) em
## vez de tentar reler a velocity depois -- pós move_and_slide() ela já
## chega ~0 no chão.

## Velocidade vertical mínima (px/s) de impacto pra disparar o burst. Quedas
## mais curtas que isso são ignoradas.
@export var limiar_impacto: float = 220.0
@export var quantidade: int = 14
@export var vida: float = 0.5

@onready var _player = get_parent()

func _ready() -> void:
	local_coords = false
	one_shot = true
	explosiveness = 1.0
	amount = quantidade
	lifetime = vida
	emitting = false
	position = Vector2(0, 8)  # altura dos pés
	texture = DustFxComum.textura_placeholder()  # TODO ARTE

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 85.0  # leque abrindo pros dois lados
	mat.gravity = Vector3(0, 60, 0)
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 70.0
	mat.scale_min = 1.0
	mat.scale_max = 2.2
	mat.scale_curve = DustFxComum.curva_escala_decrescente()
	mat.color_ramp = DustFxComum.rampa_alpha_sumindo(DustFxComum.COR_POEIRA)
	process_material = mat

	_player.landed.connect(_on_landed)

func _on_landed(impact_speed: float) -> void:
	if impact_speed < limiar_impacto:
		return
	restart()
	emitting = true
