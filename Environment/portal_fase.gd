extends Area2D
## Portal de fim de fase, discreto mas visível. Basta o player encostar: o portal
## se fecha suave e troca de cena. A lógica de save é a mesma do LevelExitPortal.
##
## O visual (um anel fino girando devagar + um vão escuro + um respiro de luz) é
## montado por código a partir do `raio` e da `cor`.

@export_file("*.tscn") var next_scene: String = ""
## Cor base do portal (anel e brilho). Puxada pra um tom apagado de propósito.
@export var cor: Color = Color(0.42, 0.44, 0.6)
## Raio do portal em pixels. A área andável (CollisionShape2D) é independente.
@export var raio: float = 15.0

var _ativando := false
var _t := 0.0
var _anel: Line2D
var _glow: Line2D
var _nucleo: Polygon2D

@onready var particulas: CPUParticles2D = $Particulas

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_montar_visual()

func _montar_visual() -> void:
	# Vão escuro translúcido no meio.
	_nucleo = Polygon2D.new()
	_nucleo.polygon = _circulo(raio * 0.85, 28)
	_nucleo.color = Color(0.05, 0.05, 0.09, 0.4)
	_nucleo.z_index = -1
	add_child(_nucleo)
	# Respiro de luz difuso atrás.
	_glow = _criar_anel(raio * 1.05, 5.0, 36, Color(cor.r, cor.g, cor.b, 0.1))
	_glow.z_index = -2
	add_child(_glow)
	# Um anel fino só, girando devagar.
	_anel = _criar_anel(raio, 1.5, 40, Color(cor.r, cor.g, cor.b, 0.85))
	add_child(_anel)

func _circulo(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _criar_anel(r: float, w: float, n: int, c: Color) -> Line2D:
	var l := Line2D.new()
	l.closed = true
	l.width = w
	l.default_color = c
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.antialiased = true
	l.points = _circulo(r, n)
	return l

func _process(delta: float) -> void:
	if _ativando:
		return
	_t += delta
	_anel.rotation += delta * 0.35
	var pulso := 1.0 + sin(_t * 1.6) * 0.02
	_nucleo.scale = Vector2(pulso, pulso)
	_glow.modulate.a = 0.6 + sin(_t * 1.6) * 0.25

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
	# Fecha suave: o anel encolhe pro centro e tudo apaga, sem flash.
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_anel, "scale", Vector2(0.15, 0.15), 0.4)
	tw.tween_property(_anel, "modulate:a", 0.0, 0.4)
	tw.tween_property(_glow, "modulate:a", 0.0, 0.4)
	tw.tween_property(_nucleo, "scale", Vector2(0.1, 0.1), 0.4)
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
