extends Node2D
## Distribui goteiras entre o teto e a primeira superfície abaixo dele.
## As posições acompanham a geometria da fase, inclusive após carregar um save.

const GOTEIRA := preload("res://Environment/Goteira.tscn")
const BLOCOS_INSTAVEIS := [0, 2, 4, 11, 12]

@export var caminho_blocos: NodePath = ^"../Blocos"
@export_range(32.0, 256.0, 8.0) var espacamento: float = 96.0
@export_range(16.0, 256.0, 8.0) var altura_minima: float = 48.0
@export_range(64.0, 1024.0, 16.0) var altura_maxima: float = 640.0

func _ready() -> void:
	# Aguarda todos os blocos restaurarem o estado do checkpoint.
	call_deferred("_distribuir")

func _distribuir() -> void:
	var blocos := get_node_or_null(caminho_blocos) as TileMapLayer
	if blocos == null or blocos.tile_set == null:
		return
	var colunas: Dictionary = {}
	for celula in blocos.get_used_cells():
		if not colunas.has(celula.x):
			colunas[celula.x] = []
		colunas[celula.x].append(celula.y)
	var largura_tile := float(blocos.tile_set.tile_size.x)
	var altura_tile := float(blocos.tile_set.tile_size.y)
	var origens: Array[Vector2] = []
	var xs: Array = colunas.keys()
	xs.sort()
	for x in xs:
		var ys: Array = colunas[x]
		ys.sort()
		for indice in range(ys.size() - 1):
			var teto := Vector2i(x, ys[indice])
			var piso := Vector2i(x, ys[indice + 1])
			var altura := (piso.y - teto.y - 1) * altura_tile
			if altura < altura_minima or altura > altura_maxima:
				continue
			if blocos.get_cell_source_id(teto) in BLOCOS_INSTAVEIS:
				continue
			if blocos.get_cell_source_id(piso) in BLOCOS_INSTAVEIS:
				continue
			var origem := blocos.map_to_local(teto) + Vector2(0, altura_tile * 0.5)
			var perto := false
			for anterior in origens:
				if origem.distance_to(anterior) < maxf(espacamento, largura_tile):
					perto = true
					break
			if perto:
				continue
			origens.append(origem)
			var gota := GOTEIRA.instantiate()
			# Mantém a escala da TileMap mesmo quando a raiz do mapa é ampliada.
			gota.position = origem
			gota.set("altura", altura)
			var variacao := posmod(teto.x * 31 + teto.y * 17, 101) / 100.0
			gota.set("intervalo", lerpf(1.4, 3.6, variacao))
			gota.set("fase", variacao * 5.0)
			blocos.add_child(gota)
