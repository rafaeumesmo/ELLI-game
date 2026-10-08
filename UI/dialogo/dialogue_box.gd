extends CanvasLayer
## Caixa de diálogo estilo Celeste + Hollow Knight (instanciada pelo
## DialogueManager).
##
## Faixa fixa na tela (em cima, ou embaixo se o player estiver no topo), com
## painel escuro translúcido que esmaece nas laterais, ornamento fino em cima e
## embaixo do texto, retrato grande sem moldura colado na lateral (Elísio à
## esquerda, NPCs à direita), nome pequeno em azul-vagalume e texto que entra
## letra a letra com fade + subida. Aceita [shake], [wave] e [p=segundos] no
## texto.
##
## Texto e nome ficam centralizados no painel, pra leitura ficar no meio da
## tela. O texto não "anda" no typewriter porque a página inteira já está no
## layout desde o começo -- o [aparecer] só deixa as letras ainda não ditas
## invisíveis.

signal pagina_completa

## 1 pixel da arte de UI = P pixels da tela.
const P := 3
const EFEITO_APARECER := preload("res://UI/dialogo/efeito_aparecer.gd")
const PONTUACAO_FORTE := ".?!…"
const PONTUACAO_FRACA := ",;:"

enum Posicao { AUTO, TOPO, BAIXO }

@export_group("Posição")
## AUTO = em cima, mas vai pra baixo se o player estiver no terço de cima da tela.
@export var posicao: Posicao = Posicao.AUTO
## Largura do painel em fração da tela.
@export_range(0.3, 1.0, 0.01) var largura_fracao: float = 0.85
## Distância do painel até a borda de cima/baixo da tela.
@export var margem_borda: int = 18

@export_group("Cores")
@export var cor_painel: Color = Color(0.051, 0.051, 0.102, 0.75)
@export var cor_texto: Color = Color("f0ead6")
@export var cor_nome: Color = Color("7ec8ff")
@export var cor_ornamento: Color = Color(0.79, 0.76, 0.66, 0.55)
## Fração da largura do painel que esmaece em cada lateral.
@export_range(0.0, 0.5, 0.01) var fade_lateral: float = 0.1

@export_group("Texto")
## Fonte do texto e do nome. Vazio = fonte padrão do Godot, sem suavização.
## Pra usar uma fonte pixel, arraste o .ttf/.otf aqui (precisa ter ã, ê, ç...).
@export var fonte: Font
@export var tamanho_fonte: int = 16
@export var tamanho_nome: int = 13
@export var espaco_linhas: int = 6
@export var linhas_por_pagina: int = 2

@export_group("Ornamento e retrato")
## Detalhe no meio das linhas de ornamento (broto placeholder). A linha em si
## é desenhada com `cor_ornamento`.
@export var textura_ornamento: Texture2D = preload("res://assets/dialogo/ornamento_broto.png")
@export var textura_avancar: Texture2D = preload("res://assets/dialogo/vagalume_avancar.png")
## Lado do retrato em px de tela (arte 32x32 x4).
@export var tamanho_retrato: int = 128
## Quanto o retrato sai pra fora do painel, pro lado e pra cima/baixo.
@export var retrato_para_fora: Vector2 = Vector2(18, 24)

@export_group("Animação")
## Abrir/fechar: o painel expande na vertical a partir do meio.
@export var duracao_abrir: float = 0.15
## Troca de quem fala: o retrato entra deslizando `deslize_retrato` px com fade.
@export var duracao_retrato: float = 0.12
@export var deslize_retrato: float = 8.0
## Fade + subida de cada letra.
@export var duracao_letra: float = 0.12
@export var subida_letra: float = 4.0

@export_group("Typewriter")
## Pausa depois de . ? ! …
@export var pausa_ponto: float = 0.3
## Pausa depois de , ; :
@export var pausa_virgula: float = 0.1

@export_group("Câmera")
## Zoom-in leve enquadrando o Elísio e o NPC durante a conversa.
@export var zoom_camera: bool = true
@export var zoom_fator: float = 1.1
@export var duracao_zoom: float = 0.35

@onready var _raiz: Control = $Raiz
@onready var _painel: ColorRect = $Raiz/Painel
@onready var _retrato_esq: TextureRect = $Raiz/RetratoEsq
@onready var _retrato_dir: TextureRect = $Raiz/RetratoDir
@onready var _nome: Label = $Raiz/Nome
@onready var _texto: RichTextLabel = $Raiz/Texto
@onready var _avancar: TextureRect = $Raiz/Avancar
@onready var _voz: AudioStreamPlayer = $Voz

## true enquanto a página atual ainda está sendo datilografada.
var digitando: bool = false
## Lidos pelo efeito [aparecer]: instante em que cada letra apareceu (-1 =
## escondida) e o relógio da caixa.
var tempos_letras := PackedFloat32Array()
var relogio := 0.0

var _fonte: Font
var _personagem: CharacterData
var _expressao := "neutro"
var _retrato_ativo: TextureRect
var _pagina: Dictionary = {}
var _revelados := 0
var _acumulado := 0.0
var _espera := 0.0
var _letras_ate_voz := 0
var _embaixo := false
var _tw: Tween
var _tw_retrato: Tween
var _ornamentos: Array[Control] = []

func _ready() -> void:
	# Roda com o jogo pausado só pra se esconder atrás do menu de pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = fonte if fonte != null else _fonte_padrao_sem_suavizacao()

	_painel.color = cor_painel
	_painel.material = _material_fade(fade_lateral, fade_lateral)
	_nome.add_theme_font_override("font", _fonte)
	_nome.add_theme_font_size_override("font_size", tamanho_nome)
	_nome.add_theme_color_override("font_color", cor_nome)
	_texto.add_theme_font_override("normal_font", _fonte)
	_texto.add_theme_font_size_override("normal_font_size", tamanho_fonte)
	_texto.add_theme_color_override("default_color", cor_texto)
	_texto.add_theme_constant_override("line_separation", espaco_linhas)
	var efeito := EFEITO_APARECER.new()
	efeito.caixa = self
	_texto.install_effect(efeito)
	_avancar.texture = textura_avancar
	for i in 2:
		var orn := _criar_ornamento()
		_raiz.add_child(orn)
		_raiz.move_child(orn, 1)
		_ornamentos.append(orn)
	_montar_layout()
	_raiz.visible = false

## Fonte padrão do Godot com o antialiasing desligado, pra combinar com o
## pixel art enquanto o projeto não tem uma fonte pixel própria.
func _fonte_padrao_sem_suavizacao() -> Font:
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var f := (base as FontFile).duplicate() as FontFile
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NORMAL
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		return f
	return base

func _material_fade(esq: float, dir: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://UI/dialogo/fade_lateral.gdshader")
	m.set_shader_parameter("fade_esq", esq)
	m.set_shader_parameter("fade_dir", dir)
	return m

## Linha fina que some nas pontas + o detalhe (broto) no meio.
func _criar_ornamento() -> Control:
	var orn := Control.new()
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in 2:
		var linha := ColorRect.new()
		linha.name = "LinhaEsq" if lado == 0 else "LinhaDir"
		linha.color = cor_ornamento
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.material = _material_fade(0.7, 0.0) if lado == 0 else _material_fade(0.0, 0.7)
		orn.add_child(linha)
	var detalhe := TextureRect.new()
	detalhe.name = "Detalhe"
	detalhe.texture = textura_ornamento
	detalhe.modulate = Color(1, 1, 1, cor_ornamento.a + 0.3)
	detalhe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.add_child(detalhe)
	return orn

func _arredondar_p(valor: float) -> int:
	return int(ceilf(valor / P)) * P

## Medidas do painel pro tamanho de tela atual. Ordem vertical dentro do
## painel: ornamento, nome, texto (2 linhas), ornamento.
func _montar_layout() -> void:
	var tela := get_viewport().get_visible_rect().size
	var largura := _arredondar_p(tela.x * largura_fracao)
	var alt_orn := textura_ornamento.get_height() if textura_ornamento != null else P
	var alt_nome := ceilf(_fonte.get_height(tamanho_nome))
	var alt_linha := _fonte.get_height(tamanho_fonte)
	var alt_texto := ceilf(alt_linha * linhas_por_pagina + espaco_linhas * (linhas_por_pagina - 1))
	var folga := 3 * P
	var altura := _arredondar_p(folga + alt_orn + 2 * P + alt_nome + P + alt_texto + 2 * P + alt_orn + folga)

	_raiz.size = Vector2(largura, altura)
	_painel.size = _raiz.size
	var x := roundf((tela.x - largura) * 0.5)
	_raiz.position = Vector2(x, tela.y - margem_borda - altura if _embaixo else margem_borda)
	_raiz.pivot_offset = _raiz.size * 0.5

	# Área do texto: a mesma pros dois lados, livre dos dois retratos.
	var recuo := tamanho_retrato - retrato_para_fora.x + 6 * P
	var texto_x := recuo
	var texto_l := largura - recuo * 2
	var y := folga
	_posicionar_ornamento(_ornamentos[0], y, largura)
	y += alt_orn + 2 * P
	_nome.position = Vector2(texto_x, y)
	_nome.size = Vector2(texto_l, alt_nome)
	y += alt_nome + P
	_avancar.size = _avancar.texture.get_size()
	# Recua dos dois lados o espaço do vagalume, pro texto centralizar no meio.
	var recuo_avancar := _avancar.size.x + 2 * P
	_texto.position = Vector2(texto_x + recuo_avancar, y)
	_texto.size = Vector2(texto_l - recuo_avancar * 2, alt_texto + P)
	y += alt_texto + 2 * P
	_posicionar_ornamento(_ornamentos[1], y, largura)

	_avancar.position = Vector2(texto_x + texto_l - _avancar.size.x, _texto.position.y + alt_texto - _avancar.size.y)

	# Retratos: colados nas laterais, saindo um pouco pro lado e na direção do
	# meio da tela (pra baixo quando o painel está no topo, e vice-versa).
	for r: TextureRect in [_retrato_esq, _retrato_dir]:
		var area := _area_retrato(r == _retrato_esq, 1.0)
		r.size = area.size
		r.position = area.position

## Onde fica o retrato de um lado. Retrato menor (`escala_retrato` < 1, ex.: o
## caracol bebê) fica centralizado no espaço do retrato normal e apoiado na
## mesma base, como se estivesse "em pé" no mesmo chão.
func _area_retrato(esquerda: bool, escala: float) -> Rect2:
	var cheio := float(tamanho_retrato)
	var lado := roundf(cheio * escala / P) * P
	var x := -retrato_para_fora.x if esquerda else _raiz.size.x - cheio + retrato_para_fora.x
	var y := _raiz.size.y - cheio + retrato_para_fora.y if not _embaixo else -retrato_para_fora.y
	return Rect2(x + roundf((cheio - lado) * 0.5), y + cheio - lado, lado, lado)

func _posicionar_ornamento(orn: Control, y: float, largura: float) -> void:
	var detalhe := orn.get_node("Detalhe") as TextureRect
	var tam := detalhe.texture.get_size() if detalhe.texture != null else Vector2.ZERO
	var meio := roundf(largura * 0.5 / P) * P
	var margem := roundf(largura * 0.18 / P) * P
	orn.position = Vector2(0, y)
	orn.size = Vector2(largura, tam.y)
	detalhe.size = tam
	detalhe.position = Vector2(meio - roundf(tam.x * 0.5 / P) * P, 0)
	var linha_y := tam.y - P
	var esq := orn.get_node("LinhaEsq") as ColorRect
	var dir := orn.get_node("LinhaDir") as ColorRect
	esq.position = Vector2(margem, linha_y)
	esq.size = Vector2(detalhe.position.x - margem, P)
	dir.position = Vector2(detalhe.position.x + tam.x, linha_y)
	dir.size = Vector2(largura - margem - dir.position.x, P)

func _process(delta: float) -> void:
	# Pausado: some atrás do menu de pausa e congela o typewriter.
	visible = not get_tree().paused
	if get_tree().paused or not _raiz.visible:
		return
	relogio += delta
	if digitando:
		_digitar(delta)
	_atualizar_retrato_animado()
	if _avancar.visible:
		# Vagalume quicando suave (arredondado pro pixel) e piscando.
		_avancar.position.y = _texto.position.y + _texto.size.y - P - _avancar.size.y - roundf(2.0 + 2.0 * sin(relogio * 4.0))
		_avancar.modulate.a = 0.55 + 0.45 * absf(sin(relogio * 3.0))

# --- Abrir / fechar ----------------------------------------------------------

## `player` decide se o painel vai pra cima ou pra baixo (modo AUTO).
func abrir(player: Node2D) -> void:
	match posicao:
		Posicao.TOPO:
			_embaixo = false
		Posicao.BAIXO:
			_embaixo = true
		_:
			var tela_y := get_viewport().get_visible_rect().size.y
			_embaixo = player != null and player.get_global_transform_with_canvas().origin.y < tela_y / 3.0
	_montar_layout()
	_raiz.visible = true
	_raiz.scale = Vector2(1, 0)
	_raiz.modulate.a = 1.0
	_animar(1.0, 1.0)

func fechar() -> void:
	digitando = false
	_avancar.visible = false
	_animar(0.0, 0.0).tween_callback(_ao_fechar)

func _ao_fechar() -> void:
	_raiz.visible = false
	_personagem = null
	for r: TextureRect in [_retrato_esq, _retrato_dir]:
		r.modulate.a = 0.0

func _animar(escala_y: float, alfa: float) -> Tween:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_raiz, "scale:y", escala_y, duracao_abrir).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_raiz, "modulate:a", alfa, duracao_abrir)
	_tw.chain()
	return _tw

# --- Falante / retrato -------------------------------------------------------

## Troca quem está falando. Se mudou o personagem, o retrato dele entra
## deslizando com fade do lado dele, e o do outro lado some.
func definir_falante(personagem: CharacterData, expressao: String) -> void:
	var mudou := personagem != _personagem
	_personagem = personagem
	_expressao = expressao
	var esquerda := personagem != null and personagem.lado_esquerdo
	var ativo := _retrato_esq if esquerda else _retrato_dir
	var outro := _retrato_dir if esquerda else _retrato_esq

	_nome.text = personagem.nome if personagem != null else ""
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ativo.flip_h = personagem != null and (personagem.retrato_olha_para_direita != esquerda)
	_retrato_ativo = ativo
	_atualizar_retrato_animado()
	if personagem != null and not personagem.retratos_animados:
		ativo.texture = personagem.retrato(expressao)

	if not mudou:
		return
	if _tw_retrato != null and _tw_retrato.is_valid():
		_tw_retrato.kill()
	var area := _area_retrato(esquerda, personagem.escala_retrato if personagem != null else 1.0)
	ativo.size = area.size
	ativo.position.y = area.position.y
	var base_x := area.position.x
	ativo.position.x = base_x + (-deslize_retrato if esquerda else deslize_retrato)
	ativo.modulate.a = 0.0
	_tw_retrato = create_tween().set_parallel(true)
	_tw_retrato.tween_property(ativo, "position:x", base_x, duracao_retrato).set_ease(Tween.EASE_OUT)
	_tw_retrato.tween_property(ativo, "modulate:a", 1.0 if ativo.texture != null else 0.0, duracao_retrato)
	_tw_retrato.tween_property(outro, "modulate:a", 0.0, duracao_retrato * 0.7)

## Retrato animado (SpriteFrames): usa "<expressão>_falando" enquanto digita,
## se existir, senão "<expressão>".
func _atualizar_retrato_animado() -> void:
	if _personagem == null or _retrato_ativo == null or _personagem.retratos_animados == null:
		return
	var frames := _personagem.retratos_animados
	var anim := _expressao + "_falando"
	if not (digitando and frames.has_animation(anim)):
		anim = _expressao if frames.has_animation(_expressao) else "neutro"
	if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		return
	var quadro := int(relogio * frames.get_animation_speed(anim)) % frames.get_frame_count(anim)
	_retrato_ativo.texture = frames.get_frame_texture(anim, quadro)

# --- Páginas -----------------------------------------------------------------

## Quebra o texto (com tags) em páginas de `linhas_por_pagina` linhas. Cada
## página é {"bbcode": String, "pausas": {letra: segundos}, "letras": int}.
## A quebra de linha é feita aqui e não pelo autowrap pra a linha não "pular"
## no meio do typewriter; tags que atravessam a página são fechadas e reabertas.
func paginar(texto: String) -> Array[Dictionary]:
	var itens := _tokenizar(texto)
	var letras := ""
	for item in itens:
		if item.has("c"):
			letras += item.c

	# Onde cada linha começa (índices em `letras`) e quais espaços viram quebra.
	var largura := _texto.size.x
	var inicios: Array[int] = [0]
	var separadores := {}
	var inicio := 0
	var ultimo_espaco := -1
	for i in letras.length():
		var c := letras[i]
		if c == "\n":
			separadores[i] = true
			inicio = i + 1
			inicios.append(inicio)
			ultimo_espaco = -1
			continue
		if c == " ":
			ultimo_espaco = i
		if ultimo_espaco > inicio and _largura(letras.substr(inicio, i - inicio + 1)) > largura:
			separadores[ultimo_espaco] = true
			inicio = ultimo_espaco + 1
			inicios.append(inicio)
			ultimo_espaco = -1
	var inicios_pagina := {}
	for l in range(linhas_por_pagina, inicios.size(), linhas_por_pagina):
		inicios_pagina[inicios[l]] = true

	var paginas: Array[Dictionary] = []
	var atual := {"bbcode": "", "pausas": {}, "letras": 0}
	var abertas: Array[Dictionary] = []
	var pos := 0
	for item in itens:
		if item.has("pausa"):
			atual.pausas[atual.letras] = atual.pausas.get(atual.letras, 0.0) + item.pausa
		elif item.has("tag"):
			atual.bbcode += item.tag
			if item.fecha:
				for j in range(abertas.size() - 1, -1, -1):
					if abertas[j].nome == item.nome:
						abertas.remove_at(j)
						break
			else:
				abertas.append(item)
		else:
			if inicios_pagina.has(pos) and atual.letras > 0:
				paginas.append(_fechar_pagina(atual, abertas))
				atual = {"bbcode": "", "pausas": {}, "letras": 0}
				for t in abertas:
					atual.bbcode += t.tag
			if separadores.has(pos):
				# Separador no fim da página some; no meio vira quebra de linha.
				if not inicios_pagina.has(pos + 1):
					atual.bbcode += "\n"
					atual.letras += 1
			else:
				atual.bbcode += item.c
				atual.letras += 1
			pos += 1
	paginas.append(_fechar_pagina(atual, abertas))
	return paginas

func _fechar_pagina(pagina: Dictionary, abertas: Array[Dictionary]) -> Dictionary:
	for j in range(abertas.size() - 1, -1, -1):
		pagina.bbcode += "[/%s]" % abertas[j].nome
	pagina.bbcode = "[aparecer]" + pagina.bbcode + "[/aparecer]"
	return pagina

## Separa letras, tags ([wave], [/shake]...) e pausas ([p=0.5]).
func _tokenizar(texto: String) -> Array[Dictionary]:
	var re := RegEx.create_from_string("\\[(/?)([a-z_]+)(?:=([^\\]]*))?\\]")
	var itens: Array[Dictionary] = []
	var pos := 0
	for m in re.search_all(texto):
		for c in texto.substr(pos, m.get_start() - pos):
			itens.append({"c": c})
		var fecha := m.get_string(1) == "/"
		var nome := m.get_string(2)
		if nome == "p" and not fecha:
			itens.append({"pausa": m.get_string(3).to_float()})
		else:
			itens.append({"tag": m.get_string(), "nome": nome, "fecha": fecha})
		pos = m.get_end()
	for c in texto.substr(pos):
		itens.append({"c": c})
	return itens

func _largura(s: String) -> float:
	return _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_fonte).x

# --- Typewriter --------------------------------------------------------------

func mostrar_pagina(pagina: Dictionary) -> void:
	_pagina = pagina
	_texto.text = "[center]%s[/center]" % pagina.bbcode
	tempos_letras = PackedFloat32Array()
	tempos_letras.resize(pagina.letras)
	tempos_letras.fill(-1.0)
	_revelados = 0
	_acumulado = 0.0
	_espera = pagina.pausas.get(0, 0.0)
	_letras_ate_voz = 0
	_avancar.visible = false
	digitando = true

func completar() -> void:
	for i in range(_revelados, tempos_letras.size()):
		tempos_letras[i] = relogio
	_revelados = tempos_letras.size()
	digitando = false
	_avancar.visible = true
	pagina_completa.emit()

func _digitar(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		return
	var lps := _personagem.letras_por_segundo if _personagem != null else 35.0
	_acumulado += delta * lps
	var letras: String = _texto.get_parsed_text()
	while _acumulado >= 1.0 and digitando:
		_acumulado -= 1.0
		tempos_letras[_revelados] = relogio
		_revelados += 1
		if _revelados >= tempos_letras.size():
			completar()
			return
		var letra := letras[_revelados - 1] if _revelados - 1 < letras.length() else ""
		var proxima := letras[_revelados] if _revelados < letras.length() else ""
		_falar(letra)
		if _pagina.pausas.has(_revelados):
			_espera = _pagina.pausas[_revelados]
		# Pausa só no fim de "..." / "?!" (a próxima já não é pontuação).
		elif not PONTUACAO_FORTE.contains(proxima) and not PONTUACAO_FRACA.contains(proxima):
			if PONTUACAO_FORTE.contains(letra):
				_espera = pausa_ponto
			elif PONTUACAO_FRACA.contains(letra):
				_espera = pausa_virgula
		if _espera > 0.0:
			_acumulado = 0.0
			return

## Voz estilo Hollow Knight: um resmungo sorteado a cada 4-6 letras.
func _falar(letra: String) -> void:
	if _personagem == null or _personagem.vozes.is_empty() or letra.strip_edges().is_empty():
		return
	_letras_ate_voz -= 1
	if _letras_ate_voz > 0:
		return
	_letras_ate_voz = randi_range(_personagem.voz_a_cada_min, maxi(_personagem.voz_a_cada_min, _personagem.voz_a_cada_max))
	_voz.stream = _personagem.vozes.pick_random()
	_voz.volume_db = _personagem.voz_volume_db
	_voz.pitch_scale = _personagem.voz_pitch * randf_range(1.0 - _personagem.voz_variacao, 1.0 + _personagem.voz_variacao)
	_voz.play()
