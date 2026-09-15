extends Area2D
## Portal de fim de fase, disfarçado de vagalume de luz azul. Basta o player
## encostar: ele murcha suave e troca de cena. A lógica de save é a mesma de
## antes -- só o visual é o mesmo bicho do `Vagalume.tscn` (asas + halo/core),
## mas azul e sempre visível, pra dar pra distinguir dos vagalumes amarelos
## de ambientação/guia.

@export_file("*.tscn") var next_scene: String = ""
## Cor da luz do portal-vagalume (halo e núcleo).
@export var cor: Color = Color("#3DA9FC")
## Energia base do halo (luz grande e suave).
@export var energia_halo: float = 1.1
## Energia base do núcleo (luz pequena e forte).
@export var energia_core: float = 2.4
## Amplitude da flutuação em lemniscata, em pixels.
@export var raio_voo: float = 10.0
## Velocidade angular da flutuação.
@export var velocidade_voo: float = 0.5

var _ativando := false
var _t := 0.0
var _origem := Vector2.ZERO
var _offset := Vector2.ZERO

@onready var particulas: CPUParticles2D = $Particulas
@onready var _corpo: AnimatedSprite2D = $Corpo
@onready var _halo: PointLight2D = $Halo
@onready var _core: PointLight2D = $Core

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_origem = position
	_corpo.play("voar")
	_halo.color = cor

func _process(delta: float) -> void:
	if _ativando:
		return
	_t += delta
	# Flutuação tipo lemniscata, igual o Vagalume decorativo -- ainda dentro
	# do alcance do CollisionShape2D, então continua tocável o tempo todo.
	var voo := _t * velocidade_voo
	_offset.x = sin(voo) * raio_voo
	_offset.y = sin(voo * 2.0) * raio_voo * 0.5
	position = _origem + _offset
	_corpo.flip_h = cos(voo) < 0.0
	var pulso := 0.85 + 0.15 * sin(_t * 2.0)
	_halo.energy = energia_halo * pulso
	_core.energy = energia_core * pulso

func _on_body_entered(body: Node) -> void:
	if _ativando or not body.is_in_group("player"):
		return
	if next_scene == "":
		push_warning("PortalFase: defina 'Next Scene' no Inspector.")
		return
	_ativar()

func _ativar() -> void:
	_ativando = true
	particulas.emitting = true
	# Fecha suave: o vagalume encolhe e apaga, sem flash.
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_corpo, "scale", Vector2(0.15, 0.15), 0.4)
	tw.tween_property(_corpo, "modulate:a", 0.0, 0.4)
	tw.tween_property(_halo, "energy", 0.0, 0.4)
	tw.tween_property(_core, "energy", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_interval(0.1)
	tw.tween_callback(_trocar_cena)

func _trocar_cena() -> void:
	# Trocar de fase também commita a espada (senão dá pra perder ela no portal).
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.get("tem_espada"):
		SaveManager.tem_espada = true
	if player != null and player.get("dash_desbloqueado"):
		SaveManager.tem_dash = true
	SaveManager.save_progress(next_scene)
	get_tree().paused = false
	Transicao.ir_para_cena(next_scene)
