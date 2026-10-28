extends CanvasLayer
## Menu de vitoria: aparece ao terminar a ultima fase. Trava o player do MESMO
## jeito que a conversa obrigatoria do caracol (Environment/caracol.gd::
## _iniciar_dialogo) -- so desliga o physics_process dele, sem pausar a arvore.

const MENU_PRINCIPAL := "res://UI/MainMenu.tscn"
const VAGALUME := preload("res://Environment/Vagalume.tscn")

## Blocos de texto dos créditos, com formatação BBCode.
@export var creditos: PackedStringArray = [
	"[font_size=34][b]ELLI: UNDERSTORY[/b][/font_size]\n\n[i]Uma pequena história sobre se perder, descobrir e seguir em frente.[/i]",
	"[font_size=15]CRIADO E DESENVOLVIDO POR[/font_size]\n\n[font_size=30][b]@RAFAEUMESMU[/b][/font_size]",
	"Conceito e narrativa\nProgramação e desenvolvimento\nArte e animação\nDesign de fases\nDireção criativa",
	"[font_size=15]AGRADECIMENTOS[/font_size]\n\nA todos que, de alguma forma, fizeram parte desta jornada.\n\nE a você, que decidiu seguir as pequenas luzes até o fim.",
	"[i]Nem toda luz existe para nos mostrar o caminho.[/i]\n\n[i]Algumas aparecem apenas para nos lembrar de que estivemos aqui.[/i]",
	"[font_size=28][b]Obrigado por jogar.[/b][/font_size]"
]
@export_range(10.0, 100.0, 1.0) var velocidade_creditos: float = 32.0

var _rolando := false
var _conteudo: VBoxContainer
var _vagalumes: Node2D
var _mensagem_final: Label
var _finalizado := false

@onready var _fundo: ColorRect = $Fundo
@onready var _caixa: VBoxContainer = $Caixa
@onready var _jogar_de_novo: Button = $Caixa/JogarDeNovoButton
@onready var _menu_principal: Button = $Caixa/MenuPrincipalButton
@onready var _janela_creditos: Control = $Caixa/JanelaCreditos

func _ready() -> void:
	add_to_group("vitoria_menu")
	hide()
	_fundo.modulate.a = 0.0
	_caixa.modulate.a = 0.0
	_jogar_de_novo.pressed.connect(_on_jogar_de_novo_pressed)
	_menu_principal.pressed.connect(_on_menu_principal_pressed)
	_criar_creditos()
	_criar_vagalumes()
	_criar_mensagem_final()
	get_viewport().size_changed.connect(_ajustar_layout)
	call_deferred("_ajustar_layout")

func _criar_creditos() -> void:
	_conteudo = VBoxContainer.new()
	# O layout começa em y=0; mantém invisível até posicionar abaixo da janela.
	_conteudo.hide()
	_conteudo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_conteudo.add_theme_constant_override("separation", 28)
	_conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela_creditos.add_child(_conteudo)
	for trecho in creditos:
		var texto := RichTextLabel.new()
		texto.bbcode_enabled = true
		texto.text = "[center]" + trecho + "[/center]"
		texto.fit_content = true
		texto.scroll_active = false
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texto.add_theme_font_size_override("normal_font_size", 21)
		texto.add_theme_font_size_override("italics_font_size", 21)
		texto.add_theme_font_size_override("bold_font_size", 21)
		texto.add_theme_color_override("default_color", Color("d6dcd4"))
		_conteudo.add_child(texto)

func _criar_vagalumes() -> void:
	_vagalumes = Node2D.new()
	_vagalumes.name = "VagalumesCreditos"
	add_child(_vagalumes)
	move_child(_vagalumes, 1) # Entre o fundo e o texto.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8127
	for i in 12:
		var vagalume := VAGALUME.instantiate() as Node2D
		var lado := 0.12 if i % 2 == 0 else 0.88
		vagalume.position = Vector2((lado + rng.randf_range(-0.06, 0.06)) * 1280, rng.randf_range(30, 690))
		vagalume.set("raio_voo", rng.randf_range(35, 85))
		vagalume.set("velocidade", rng.randf_range(0.18, 0.35))
		vagalume.set("energia_halo", 0.55)
		vagalume.set("energia_core", 1.0)
		vagalume.scale = Vector2.ONE * rng.randf_range(1.1, 1.7)
		vagalume.set("cor_luz", Color("a3cbd5") if i % 5 == 0 else Color("ddc477"))
		_vagalumes.add_child(vagalume)
		# Na interface, usa a ordem dos nós em vez das camadas do mapa.
		for visual in vagalume.get_children():
			if visual is CanvasItem:
				visual.z_as_relative = true
				visual.z_index = 0

func _ajustar_layout() -> void:
	var largura := _janela_creditos.size.x
	var margem := maxf((largura - 720.0) * 0.5, 12.0)
	_conteudo.offset_left = margem
	_conteudo.offset_right = -margem
	if _vagalumes != null:
		_vagalumes.scale = get_viewport().get_visible_rect().size / Vector2(1280, 720)

func _iniciar_creditos() -> void:
	_ajustar_layout()
	_conteudo.position.y = _janela_creditos.size.y
	_conteudo.show()
	_rolando = true

func _criar_mensagem_final() -> void:
	_mensagem_final = Label.new()
	_mensagem_final.name = "ObrigadoFinal"
	_mensagem_final.text = "Obrigado por jogar."
	_mensagem_final.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mensagem_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensagem_final.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mensagem_final.add_theme_font_size_override("font_size", 30)
	_mensagem_final.add_theme_color_override("font_color", Color("d6dcd4"))
	_mensagem_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mensagem_final.modulate.a = 0.0
	_mensagem_final.hide()
	add_child(_mensagem_final)

func _mostrar_final() -> void:
	if _finalizado:
		return
	_finalizado = true
	_rolando = false
	_jogar_de_novo.disabled = true
	_menu_principal.disabled = true
	var tw := create_tween()
	tw.tween_property(_caixa, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_caixa.hide)
	tw.tween_callback(_mensagem_final.show)
	tw.tween_property(_mensagem_final, "modulate:a", 1.0, 0.9)

func _unhandled_input(event: InputEvent) -> void:
	if _finalizado and _mensagem_final.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_menu_principal_pressed()

func _process(delta: float) -> void:
	if not _rolando or not visible:
		return
	_conteudo.position.y -= velocidade_creditos * delta
	if _conteudo.position.y + _conteudo.size.y <= 0.0:
		_mostrar_final()

## Mostra a tela: fade do fundo escuro e so depois os botoes, travando o player.
func mostrar() -> void:
	if visible:
		return
	show()
	_travar_player()

	var tw := create_tween()
	tw.tween_property(_fundo, "modulate:a", 1.0, 0.5)
	tw.tween_property(_caixa, "modulate:a", 1.0, 0.25)
	tw.tween_callback(_iniciar_creditos)
	tw.tween_callback(_jogar_de_novo.grab_focus)

func _travar_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.set_physics_process(false)

func _on_jogar_de_novo_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_principal_pressed() -> void:
	get_tree().change_scene_to_file(MENU_PRINCIPAL)
