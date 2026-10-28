extends Node2D
## Superfície do poço e respingos, no mesmo tamanho de pixel do personagem.

var _tempo := 0.0
var _desde_impacto := -1.0
var _impacto_x := 24.0

func mergulhar(x: float) -> void:
	if _desde_impacto >= 0.0:
		return
	_impacto_x = clampf(x, 5.0, 43.0)
	_desde_impacto = 0.0

func _process(delta: float) -> void:
	_tempo += delta
	if _desde_impacto >= 0.0:
		_desde_impacto += delta
	queue_redraw()

func _draw() -> void:
	# A água em primeiro plano encobre o personagem quando ele submerge.
	draw_rect(Rect2(0, 1, 48, 300), Color(0.025, 0.11, 0.18, 0.94))
	for x in range(48):
		var y := floorf(sin(x * 0.24 + _tempo * 2.2))
		draw_rect(Rect2(x, y, 1, 2), Color(0.25, 0.6, 0.78, 0.85))
	for faixa in range(4):
		var x := 5.0 + fposmod(faixa * 13.0 + _tempo * 3.0, 32.0)
		draw_rect(Rect2(floorf(x), 8 + faixa * 9, 6, 1), Color(0.15, 0.37, 0.5, 0.4))
	if _desde_impacto < 0.0:
		return
	var t := _desde_impacto
	# Gotas em arcos para os dois lados, com gravidade.
	if t < 1.1:
		for i in range(12):
			var lado := -1.0 if i % 2 == 0 else 1.0
			var velocidade := 10.0 + (i % 6) * 3.0
			var x := _impacto_x + lado * velocidade * t
			var y := -(34.0 + (i % 4) * 10.0) * t + 65.0 * t * t
			if x > 1.0 and x < 47.0 and y < 0.0:
				draw_rect(Rect2(floorf(x), floorf(y), 1, 2), Color(0.63, 0.87, 1.0, 1.0 - t / 1.1))
	# Ondas se abrem e desaparecem depois do mergulho.
	for i in range(3):
		var idade := t - i * 0.16
		if idade < 0.0 or idade > 1.5:
			continue
		var raio := idade * 19.0
		var esquerda := maxf(1.0, _impacto_x - raio)
		var direita := minf(47.0, _impacto_x + raio)
		draw_line(Vector2(esquerda, 2 + i * 2), Vector2(direita, 2 + i * 2), Color(0.65, 0.88, 1.0, (1.0 - idade / 1.5) * 0.8))
