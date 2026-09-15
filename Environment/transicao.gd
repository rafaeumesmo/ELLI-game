extends CanvasLayer
## Autoload de transição de tela. Cobre tudo com um retângulo escuro, troca a cena
## por baixo e revela de novo -- sem corte seco entre as fases.
##
## Uso: em vez de `get_tree().change_scene_to_file(x)`, chame
## `Transicao.ir_para_cena(x)`.

## Cor que cobre a tela no meio da transição (quase preto, no tom do jogo).
const COR := Color(0.02, 0.025, 0.05)
const FADE_OUT := 0.35   ## tempo pra cobrir a tela
const FADE_IN := 0.45    ## tempo pra revelar a cena nova
const SEGURA := 0.08     ## respiro com a tela coberta

@onready var _cor: ColorRect = $Cor

var _ocupado := false

func _ready() -> void:
	layer = 128
	_cor.color = Color(COR.r, COR.g, COR.b, 0.0)
	_cor.mouse_filter = Control.MOUSE_FILTER_IGNORE

func ir_para_cena(path: String) -> void:
	if _ocupado:
		return
	_ocupado = true
	await _fade(1.0, FADE_OUT)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	# Espera a cena nova entrar na árvore antes de revelar.
	await get_tree().process_frame
	await get_tree().process_frame
	if SEGURA > 0.0:
		await get_tree().create_timer(SEGURA).timeout
	await _fade(0.0, FADE_IN)
	_ocupado = false

## Só cobre a tela (sem trocar de cena). Útil pra reload etc.
func cobrir() -> void:
	await _fade(1.0, FADE_OUT)

## Revela a tela.
func revelar() -> void:
	await _fade(0.0, FADE_IN)

func _fade(alvo_alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_cor, "color:a", alvo_alpha, dur).set_trans(Tween.TRANS_SINE)
	await tw.finished
