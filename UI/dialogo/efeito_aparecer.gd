extends RichTextEffect
## [aparecer] -- cada letra entra com fade e sobe um pouquinho (estilo Celeste).
## Quem decide QUANDO cada letra aparece é a DialogueBox: ela guarda em
## `caixa.tempos_letras[i]` o instante (no relógio `caixa.relogio`) em que a
## letra i foi revelada; -1 = ainda escondida.

var bbcode := "aparecer"
## A DialogueBox dona do texto (precisa de `tempos_letras`, `relogio`,
## `duracao_letra` e `subida_letra`).
var caixa: Object

func _process_custom_fx(fx: CharFXTransform) -> bool:
	var i := fx.range.x
	var tempos: PackedFloat32Array = caixa.tempos_letras
	if i < 0 or i >= tempos.size() or tempos[i] < 0.0:
		fx.color.a = 0.0
		return true
	var k := clampf((caixa.relogio - tempos[i]) / caixa.duracao_letra, 0.0, 1.0)
	fx.color.a *= k
	fx.offset.y += roundf((1.0 - k) * caixa.subida_letra)
	return true
