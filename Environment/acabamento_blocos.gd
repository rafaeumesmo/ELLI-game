extends Node2D
## Acabamento estático das rochas. Reconstrói apenas quando a TileMap muda.
## Não interfere na textura de blocos especiais nem nas colisões.

const ROCHAS := [1, 3, 5, 6, 7, 9, 10, 13, 14, 15, 16, 17]
## IDs do TileSet, não os números dos arquivos: blocos8 corresponde ao 7.
const BLOCO8 := 7
const ROCHAS_FIXAS_NOVAS := [19, 20, 21]

var _blocos: TileMapLayer

func _ready() -> void:
	_blocos = get_parent() as TileMapLayer
	_blocos.changed.connect(queue_redraw)

func _solido(celula: Vector2i) -> bool:
	var fonte := _blocos.get_cell_source_id(celula)
	return fonte >= 0 and fonte != 18 and fonte != 11 and fonte != 12

func _draw() -> void:
	if _blocos == null or _blocos.tile_set == null:
		return
	var tamanho := Vector2(_blocos.tile_set.tile_size)
	for celula in _blocos.get_used_cells():
		var fonte := _blocos.get_cell_source_id(celula)
		if fonte not in ROCHAS and fonte != 4 and fonte not in ROCHAS_FIXAS_NOVAS:
			continue
		# Deixa a textura original nos blocos que sustentam espinhos.
		if _blocos.get_cell_source_id(celula + Vector2i.UP) in [11, 12] \
				or _blocos.get_cell_source_id(celula + Vector2i.DOWN) in [11, 12]:
			continue
		var p := _blocos.map_to_local(celula) - tamanho * 0.5
		# Variação determinística: não cintila nem muda ao carregar o save.
		var detalhe := posmod(celula.x * 73 + celula.y * 37, 97)
		var topo := not _solido(celula + Vector2i.UP)
		if fonte != 4 and _blocos.get_cell_source_id(celula + Vector2i.UP) in [-1, 18]:
			_desenhar_piso(celula, p, tamanho, fonte, detalhe)
		if fonte in ROCHAS_FIXAS_NOVAS:
			continue
		if fonte != BLOCO8:
			_desenhar_alternativo(celula, p, tamanho, fonte, detalhe, topo)
			continue
		var atlas := _blocos.tile_set.get_source(fonte) as TileSetAtlasSource
		if atlas == null:
			continue
		var base := preload("res://Environment/detalhes_bloco.gd").tom_da_textura(atlas.texture)
		var borda := base.lightened(0.12)
		var luz := base.lightened(0.16)
		var sombra := Color(base.darkened(0.25), 0.55)
		var fissura := Color(base.darkened(0.3), 0.65)
		if not _solido(celula + Vector2i.LEFT):
			draw_rect(Rect2(p + Vector2(0, 3 if topo else 0), Vector2(1, tamanho.y - (3 if topo else 0))), Color(borda, 0.45))
		if not _solido(celula + Vector2i.RIGHT):
			draw_rect(Rect2(p + Vector2(tamanho.x - 2, 2 if topo else 0), Vector2(2, tamanho.y - (2 if topo else 0))), sombra)
		# Fissuras esparsas quebram a repetição sem quadricular toda a parede.
		if detalhe % 4 == 0:
			var f := p + Vector2(4 + detalhe % 6, 6 + detalhe % 4)
			draw_rect(Rect2(f, Vector2(3, 1)), fissura)
			draw_rect(Rect2(f + Vector2(2, 1), Vector2(1, 3)), fissura)
			draw_rect(Rect2(f + Vector2(0, -1), Vector2(2, 1)), Color(luz, 0.16))


func _desenhar_piso(celula: Vector2i, p: Vector2, tamanho: Vector2, fonte: int, detalhe: int) -> void:
	var atlas := _blocos.tile_set.get_source(fonte) as TileSetAtlasSource
	if atlas == null:
		return
	var base := preload("res://Environment/detalhes_bloco.gd").tom_da_textura(atlas.texture)
	var superficie := base.lightened(0.09)
	var relevo := base.lightened(0.18)
	var luz := base.lightened(0.24)
	var sombra := base.darkened(0.28)
	# Camada superior compacta e legível, toda dentro da área sólida.
	draw_rect(Rect2(p, Vector2(tamanho.x, 3)), superficie)
	# Placas irregulares encadeadas: o topo não vira uma régua de cor única.
	for i in 3:
		var x := float(i * 5)
		var variacao := posmod(detalhe + i * 13, 7)
		var largura := minf(4.0 + variacao % 2, tamanho.x - x)
		var altura := float(2 + variacao % 3)
		draw_rect(Rect2(p + Vector2(x, 1), Vector2(largura, altura)), relevo)
		draw_rect(Rect2(p + Vector2(x, 0), Vector2(largura - 1, 1)), luz)
		draw_rect(Rect2(p + Vector2(x + 1, altura + 1), Vector2(largura - 1, 1)), Color(sombra, 0.75))
		# Meia-luz na transição da crosta para o corpo da rocha.
		draw_rect(Rect2(p + Vector2(x, altura), Vector2(2, 1)), superficie)
	var f := float(3 + detalhe % 8)
	draw_rect(Rect2(p + Vector2(f, 2), Vector2(1, 2)), Color(sombra, 0.65))
	draw_rect(Rect2(p + Vector2(f + 1, 3), Vector2(2, 1)), Color(sombra, 0.5))
	# Cantos viram para a lateral em vez de terminar num corte quadrado claro.
	if not _solido(celula + Vector2i.LEFT):
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 5)), relevo)
	if not _solido(celula + Vector2i.RIGHT):
		draw_rect(Rect2(p + Vector2(tamanho.x - 1, 1), Vector2(1, 5)), sombra)
	# Grãos esparsos, com variantes de posição para não repetir a mesma placa.
	if detalhe % 3 == 0:
		draw_rect(Rect2(p + Vector2(2 + detalhe % 5, 6), Vector2(2, 1)), Color(relevo, 0.45))

func _desenhar_alternativo(celula: Vector2i, p: Vector2, tamanho: Vector2, fonte: int, detalhe: int, topo: bool) -> void:
	var atlas := _blocos.tile_set.get_source(fonte) as TileSetAtlasSource
	if atlas == null:
		return
	var base := preload("res://Environment/detalhes_bloco.gd").tom_da_textura(atlas.texture)
	var tom := base.lightened(0.12)
	var sombra := Color(base.darkened(0.25), 0.22)
	# Marcas pequenas, sem contorno contínuo nem mudança de paleta.
	var x := float(3 + detalhe % 7)
	var y := float(5 + detalhe % 5)
	match fonte:
		4: # Mesmo relevo antes e durante a queda.
			preload("res://Environment/detalhes_bloco.gd").desenhar(self, p, base, 0)
		1, 6, 13: # Alvenaria: juntas horizontais e pequenos cantos gastos.
			draw_rect(Rect2(p + Vector2(1, 8), Vector2(tamanho.x - 2, 1)), sombra)
			draw_rect(Rect2(p + Vector2(5 if fonte == 1 else 10, 9), Vector2(1, 6)), sombra)
			draw_rect(Rect2(p + Vector2(x, 7), Vector2(3, 1)), Color(tom, 0.18))
		3, 10, 16: # Pedra laminada: estratos curtos e deslocados.
			draw_rect(Rect2(p + Vector2(2, y), Vector2(5 + detalhe % 4, 1)), Color(tom, 0.18))
			draw_rect(Rect2(p + Vector2(6, y + 3), Vector2(7, 1)), sombra)
		5, 14, 17: # Inclusões minerais angulares, sem luzes ou animação.
			if detalhe % 3 != 0:
				draw_rect(Rect2(p + Vector2(x, y), Vector2(1, 3)), Color(tom, 0.22))
				draw_rect(Rect2(p + Vector2(x + 1, y + 1), Vector2(2, 1)), Color(tom, 0.18))
		9, 15: # Pedra porosa: grãos claros e pequenas cavidades.
			draw_rect(Rect2(p + Vector2(x, y), Vector2(2, 1)), Color(tom, 0.20))
			draw_rect(Rect2(p + Vector2(13 - x, y + 3), Vector2(2, 2)), sombra)
