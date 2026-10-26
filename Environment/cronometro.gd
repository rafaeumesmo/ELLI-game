extends CanvasLayer
## Autoload do cronometro estilo Celeste: canto superior esquerdo, tempo total do
## save (grande) e tempo da fase atual (pequeno, embaixo).
##
## - Só conta com player na árvore (menus não contam) e para quando o jogo pausa.
## - Morrer / recarregar a cena NÃO zera a fase -- só trocar pra outra cena.
## - O total mora em SaveManager.tempo_total e vai pro arquivo junto com o save.
## - Liga/desliga em Options no menu principal (settings.cfg, gameplay/cronometro).

const SETTINGS_PATH := "user://settings.cfg"

var visivel: bool = false:
	set(v):
		visivel = v
		if is_node_ready():
			_caixa.visible = v

var tempo_fase: float = 0.0
var _cena_atual: String = ""
var _tinha_player := false

var _caixa: VBoxContainer
var _label_total: Label
var _label_fase: Label

func _ready() -> void:
	layer = 100  # acima do jogo, abaixo da Transicao (128)
	_caixa = VBoxContainer.new()
	_caixa.position = Vector2(12, 8)
	_caixa.add_theme_constant_override("separation", -4)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caixa)
	_label_total = _criar_label(22, Color(1, 1, 1))
	_label_fase = _criar_label(14, Color(0.85, 0.85, 0.85))

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		visivel = config.get_value("gameplay", "cronometro", false)
	_caixa.visible = visivel
	_atualizar_texto()

func _criar_label(tamanho: int, cor: Color) -> Label:
	var label := Label.new()
	# Números de largura fixa, senão o texto treme a cada dígito.
	var fonte := FontVariation.new()
	fonte.base_font = ThemeDB.fallback_font
	fonte.opentype_features = {"tnum": 1}
	label.add_theme_font_override("font", fonte)
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", cor)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_child(label)
	return label

func _process(delta: float) -> void:
	var tem_player := get_tree().get_first_node_in_group("player") != null
	# Acabou de sair do jogo (menu / tela de morte): grava o tempo acumulado.
	if _tinha_player and not tem_player:
		SaveManager.salvar_tempo()
	_tinha_player = tem_player

	var cena := get_tree().current_scene
	if cena != null and cena.scene_file_path != _cena_atual:
		_cena_atual = cena.scene_file_path
		tempo_fase = 0.0

	_caixa.visible = visivel and tem_player
	if not tem_player:
		return
	SaveManager.tempo_total += delta
	tempo_fase += delta
	if _caixa.visible:
		_atualizar_texto()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.salvar_tempo()

func _atualizar_texto() -> void:
	_label_total.text = formatar(SaveManager.tempo_total)
	_label_fase.text = formatar(tempo_fase)

## 83.456 -> "1:23.456"; com hora: "1:02:03.456".
static func formatar(segundos: float) -> String:
	var ms := int(segundos * 1000.0)
	var h := ms / 3600000
	var m := (ms / 60000) % 60
	var s := (ms / 1000) % 60
	var resto := ms % 1000
	if h > 0:
		return "%d:%02d:%02d.%03d" % [h, m, s, resto]
	return "%d:%02d.%03d" % [m, s, resto]
