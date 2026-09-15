extends Area2D

const WAIT_TIME := 2.0
const WARN_STAGE_TIME := 0.4

const COLOR_NORMAL := Color(0, 0, 0, 0)
const COLOR_WARN_1 := Color(1.0, 0.65, 0.0, 0.55)
const COLOR_WARN_2 := Color(1.0, 0.15, 0.0, 0.75)
const COLOR_LAVA := Color(1.0, 0.35, 0.0, 0.9)

const LUZ_TEXTURA := preload("res://Environment/luz_radial.tres")
const LUZ_COR := Color(1.0, 0.35, 0.05)
const LUZ_ENERGIA := 1.6

## Cor das bolhas que sobem e estouram na superfície (mais quente que a lava).
const COR_BOLHA := Color(1.0, 0.72, 0.2, 0.95)

## Se ligado, a lava já nasce ativa — sem precisar pisar para disparar a contagem.
@export var comeca_ativa: bool = true
## Bolhas de lava borbulhando na superfície enquanto a lava está ativa.
@export var borbulha: bool = true

@onready var visual: Polygon2D = $Visual

var _touched: bool = false
var _is_lava: bool = false
var _luz: PointLight2D

var _bolhas_ativas: bool = false
## Superfície da lava (topo do polígono do Visual), no espaço local do Visual.
var _sup_y: float = 0.0
var _sup_x0: float = 0.0
var _sup_x1: float = 0.0

func _ready() -> void:
	visual.color = COLOR_NORMAL
	_medir_superficie()
	_criar_luz()
	body_entered.connect(_on_body_entered)
	if comeca_ativa:
		_ativar_imediatamente.call_deferred()

# Topo do polígono do Visual = linha da superfície onde as bolhas nascem.
func _medir_superficie() -> void:
	var pts := visual.polygon
	if pts.is_empty():
		return
	_sup_y = pts[0].y
	_sup_x0 = pts[0].x
	_sup_x1 = pts[0].x
	for p in pts:
		_sup_y = minf(_sup_y, p.y)
		_sup_x0 = minf(_sup_x0, p.x)
		_sup_x1 = maxf(_sup_x1, p.x)

# Pula a contagem/aviso e já deixa a lava letal, com a luz no talo e pulsando.
# Deferido para a luz criada em _criar_luz() já estar na árvore.
func _ativar_imediatamente() -> void:
	_touched = true
	_is_lava = true
	visual.color = COLOR_LAVA
	_luz.energy = LUZ_ENERGIA
	_pulsar_luz()
	_iniciar_bolhas()
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_kill(body)
		elif body.is_in_group("enemy") and body.has_method("die"):
			body.die()

func _criar_luz() -> void:
	# Luz fica pendurada no mesmo pai (não no LavaFloor), então acende mesmo
	# com o LavaFloor invisível. Começa apagada.
	_luz = PointLight2D.new()
	_luz.texture = LUZ_TEXTURA
	# Gradiente de luz fica em linear; o "nearest" é só para a pixel art.
	_luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_luz.color = LUZ_COR
	_luz.energy = 0.0
	_luz.scale = Vector2(1.5, 0.55)
	_luz.blend_mode = Light2D.BLEND_MODE_ADD
	_luz.position = position + Vector2(47, -4)
	get_parent().call_deferred("add_child", _luz)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if _is_lava and body.has_method("die"):
			body.die()
		return
	if not body.is_in_group("player"):
		return
	if _is_lava:
		_kill(body)
		return
	if not _touched:
		_touched = true
		_start_countdown()

func _start_countdown() -> void:
	await get_tree().create_timer(WAIT_TIME).timeout
	await _turn_to_lava()

func _turn_to_lava() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "color", COLOR_WARN_1, WARN_STAGE_TIME)
	tween.parallel().tween_property(_luz, "energy", LUZ_ENERGIA * 0.35, WARN_STAGE_TIME)
	tween.tween_property(visual, "color", COLOR_WARN_2, WARN_STAGE_TIME)
	tween.parallel().tween_property(_luz, "energy", LUZ_ENERGIA * 0.65, WARN_STAGE_TIME)
	tween.tween_property(visual, "color", COLOR_LAVA, WARN_STAGE_TIME)
	tween.parallel().tween_property(_luz, "energy", LUZ_ENERGIA, WARN_STAGE_TIME)
	await tween.finished
	_is_lava = true
	_pulsar_luz()
	_iniciar_bolhas()
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_kill(body)
		elif body.is_in_group("enemy") and body.has_method("die"):
			body.die()

func _pulsar_luz() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_luz, "energy", LUZ_ENERGIA * 0.8, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(_luz, "energy", LUZ_ENERGIA, 0.7).set_trans(Tween.TRANS_SINE)

func _kill(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(body.max_health)

# --- Bolhas de lava -----------------------------------------------------------

func _iniciar_bolhas() -> void:
	if _bolhas_ativas or not borbulha:
		return
	_bolhas_ativas = true
	var timer := Timer.new()
	timer.name = "BolhaTimer"
	timer.one_shot = false
	timer.wait_time = randf_range(0.25, 0.8)
	timer.timeout.connect(_on_bolha_timer)
	add_child(timer)
	timer.start()

func _on_bolha_timer() -> void:
	if not _is_lava:
		return
	_soltar_bolha()
	# Intervalo irregular: às vezes uma sequência rápida, às vezes uma pausa.
	($BolhaTimer as Timer).wait_time = randf_range(0.18, 0.9)

func _soltar_bolha() -> void:
	if _sup_x1 - _sup_x0 < 12.0:
		return
	var r := randf_range(2.0, 4.5)
	var b := Polygon2D.new()
	b.polygon = _circulo_unitario()
	b.color = COR_BOLHA
	b.z_index = 1
	b.position = Vector2(
		randf_range(_sup_x0 + 6.0, _sup_x1 - 6.0),
		_sup_y + randf_range(0.0, 2.5)
	)
	b.scale = Vector2.ZERO
	visual.add_child(b)

	var subida := randf_range(0.35, 0.7)
	var t := b.create_tween()
	# incha e sobe um tiquinho pra fora da lava
	t.tween_property(b, "scale", Vector2(r, r), subida) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(b, "position:y", b.position.y - randf_range(1.5, 4.0), subida)
	# estoura: estica pros lados, achata e some
	t.tween_property(b, "scale", Vector2(r * 1.6, r * 0.35), 0.1)
	t.parallel().tween_property(b, "modulate:a", 0.0, 0.12)
	t.tween_callback(b.queue_free)

func _circulo_unitario() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a), sin(a)))
	return pts
