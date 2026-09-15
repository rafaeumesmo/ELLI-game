extends Area2D
## Gatilho solto: posicione onde quiser. Quando o player encosta, manda cada
## bloco de `blocos` (arraste os BlocoQueCai aqui no Inspector) despencar.

## Nós BlocoQueCai que esse gatilho derruba.
@export var blocos: Array[NodePath] = []
## Se true, o gatilho para de valer depois do primeiro toque.
@export var uma_vez_so: bool = true

## Cor base das partículas (segue a cor da Marca).
const COR := Color(0.22, 0.32, 0.45)

@onready var _marca: Polygon2D = $Marca

var _usado := false
var _t := 0.0
## Fagulhas que sobem devagar da marca enquanto o gatilho está armado.
var _brilho: CPUParticles2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_criar_brilho()

func _criar_brilho() -> void:
	_brilho = CPUParticles2D.new()
	_brilho.amount = 16
	_brilho.lifetime = 1.6
	_brilho.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_brilho.emission_rect_extents = Vector2(7, 7)
	_brilho.direction = Vector2(0, -1)
	_brilho.spread = 20.0
	_brilho.gravity = Vector2.ZERO
	_brilho.initial_velocity_min = 5.0
	_brilho.initial_velocity_max = 13.0
	_brilho.scale_amount_min = 1.0
	_brilho.scale_amount_max = 2.5
	_brilho.color = Color.WHITE
	# Envelope de alpha: nasce transparente, acende e some.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([
		Color(COR.r, COR.g, COR.b, 0.0),
		Color(COR.r, COR.g, COR.b, 0.85),
		Color(COR.r, COR.g, COR.b, 0.0),
	])
	_brilho.color_ramp = grad
	add_child(_brilho)
	_brilho.emitting = true

func _process(delta: float) -> void:
	if _usado:
		return
	_t += delta
	_marca.modulate.a = 0.5 + sin(_t * 3.0) * 0.35

func _on_body_entered(body: Node) -> void:
	if _usado or not body.is_in_group("player"):
		return
	_estourar()
	if uma_vez_so:
		_usado = true
		set_deferred("monitoring", false)
		_brilho.emitting = false
		var tw := create_tween()
		tw.tween_property(_marca, "modulate:a", 0.0, 0.25)
	for caminho in blocos:
		var bloco := get_node_or_null(caminho)
		if bloco != null and bloco.has_method("derrubar"):
			bloco.derrubar()

## Puff de partículas no momento em que o gatilho dispara.
func _estourar() -> void:
	var po := CPUParticles2D.new()
	po.one_shot = true
	po.explosiveness = 1.0
	po.amount = 20
	po.lifetime = 0.55
	po.direction = Vector2(0, -1)
	po.spread = 180.0
	po.gravity = Vector2(0, 160)
	po.initial_velocity_min = 40.0
	po.initial_velocity_max = 110.0
	po.scale_amount_min = 1.5
	po.scale_amount_max = 3.0
	po.color = Color(COR.r, COR.g, COR.b, 0.9)
	add_child(po)
	po.emitting = true
	get_tree().create_timer(1.0).timeout.connect(po.queue_free)
