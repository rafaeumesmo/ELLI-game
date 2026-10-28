extends CanvasLayer
## Dicas contextuais sem interromper o movimento ou abrir diálogos.

var _linha: HBoxContainer
var _dica_atual := ""
var _fade: Tween
var _tempo := 0.0
var _player: Node2D

func _ready() -> void:
	layer = 5
	_linha = HBoxContainer.new()
	_linha.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_linha.offset_left = -220
	_linha.offset_right = 220
	_linha.offset_top = -48
	_linha.offset_bottom = -20
	_linha.alignment = BoxContainer.ALIGNMENT_CENTER
	_linha.add_theme_constant_override("separation", 8)
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.modulate.a = 0.0
	add_child(_linha)
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	_tempo += delta
	if not is_instance_valid(_player) or not _player.visible or DialogueManager.is_active:
		_mostrar("", "")
		return
	if _tempo < 0.5:
		return
	var pos := (get_parent() as Node2D).to_local(_player.global_position)
	if pos.x >= 100.0 and pos.y > -65.0:
		_mostrar("A / D + W", "subir pela parede")
	elif pos.x < -100.0 and pos.y > 0.0:
		_mostrar("A / D  ·  ← / →", "mover")
	elif pos.y > -35.0:
		_mostrar("Espaço / ↑", "pular")
	else:
		_mostrar("", "")

func _mostrar(teclas: String, acao: String) -> void:
	var dica := teclas + acao
	if dica == _dica_atual:
		return
	_dica_atual = dica
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if teclas.is_empty():
		_fade = create_tween()
		_fade.tween_property(_linha, "modulate:a", 0.0, 0.3)
		return
	for filho in _linha.get_children():
		_linha.remove_child(filho)
		filho.queue_free()
	var placa := PanelContainer.new()
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.12, 0.15, 0.45)
	estilo.border_color = Color(0.65, 0.72, 0.75, 0.35)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 3
	estilo.content_margin_bottom = 3
	placa.add_theme_stylebox_override("panel", estilo)
	placa.add_child(_label(teclas, Color(0.85, 0.89, 0.88)))
	_linha.add_child(placa)
	_linha.add_child(_label(acao, Color(0.70, 0.76, 0.75)))
	_linha.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_linha, "modulate:a", 0.7, 0.35)

func _label(texto: String, cor: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", cor)
	return label
