extends CanvasLayer
## Caixa de diálogo "retrato + caixa" (instanciada pelo DialogueManager).
##
## Da esquerda pra direita: card do retrato, aba de nome em cima da caixa,
## caixa de texto com 2 linhas por página, seta ▼ quicando quando a página
## termina e rabicho embaixo apontando pra quem fala. Fica numa CanvasLayer e
## acompanha o falante convertendo a posição dele com
## get_global_transform_with_canvas() -- zoom da câmera e o scale 3.65 dos
## mapas não interferem. Sempre clampeada dentro da tela.
##
## A arte (assets/dialogo/) já vem "assada" em 3x: 1 pixel de arte = P px de
## tela. Todas as medidas são múltiplos de P pra nada sair do grid.

signal pagina_completa

## 1 pixel da arte = P pixels da UI.
const P := 3
const PONTUACAO_FORTE := ".?!…"
const PONTUACAO_FRACA := ",;:"

@export_group("Texto")
## Fonte do texto e do nome. Vazio = fonte padrão do Godot, sem suavização.
## Pra usar uma fonte pixel, arraste o .ttf/.otf aqui (precisa ter ã, ê, ç...).
@export var fonte: Font
@export var tamanho_fonte: int = 16
@export var cor_texto: Color = Color("e8e8f0")
@export var cor_nome: Color = Color("e8e8f0")
## Espaço extra entre as linhas (px).
@export var espaco_linhas: int = 6
@export var linhas_por_pagina: int = 2

@export_group("Caixa")
## Largura da caixa de texto (sem o retrato), em px de tela.
@export var largura_caixa: int = 420
## Margem interna da caixa (px). Arredondada pra múltiplo de P.
@export var margem_x: int = 18
@export var margem_y: int = 15
## Distância mínima da caixa até a borda da tela.
@export var margem_tela: int = 8
## Duração da animação de abrir/fechar.
@export var duracao_abrir: float = 0.1

@export_group("Typewriter")
## Pausa depois de . ? ! …
@export var pausa_ponto: float = 0.3
## Pausa depois de , ; :
@export var pausa_virgula: float = 0.1

@onready var _raiz: Control = $Raiz
@onready var _card: NinePatchRect = $Raiz/Retrato
@onready var _retrato: TextureRect = $Raiz/Retrato/Imagem
@onready var _caixa: NinePatchRect = $Raiz/Caixa
@onready var _texto: Label = $Raiz/Caixa/Texto
@onready var _seta: TextureRect = $Raiz/Caixa/Seta
@onready var _aba: NinePatchRect = $Raiz/Aba
@onready var _nome: Label = $Raiz/Aba/Nome
@onready var _rabicho: TextureRect = $Raiz/Rabicho
@onready var _bip: AudioStreamPlayer = $Bip

## true enquanto a página atual ainda está sendo datilografada.
var digitando: bool = false

var _fonte: Font
var _alvo: Node2D
var _personagem: CharacterData
var _pagina := ""
var _visiveis := 0
var _acumulado := 0.0
var _espera := 0.0
var _letras_desde_bip := 0
var _tempo := 0.0
var _tw: Tween

func _ready() -> void:
	_fonte = fonte if fonte != null else _fonte_padrao_sem_suavizacao()
	for label: Label in [_texto, _nome]:
		label.add_theme_font_override("font", _fonte)
		label.add_theme_font_size_override("font_size", tamanho_fonte)
	_texto.add_theme_color_override("font_color", cor_texto)
	_texto.add_theme_constant_override("line_spacing", espaco_linhas)
	_nome.add_theme_color_override("font_color", cor_nome)
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

func _arredondar_p(valor: float) -> int:
	return int(ceilf(valor / P)) * P

## Monta as medidas fixas (tudo em múltiplos de P). A caixa e o card ficam
## alinhados pela base; a aba de nome senta no topo da caixa, ao lado do card.
func _montar_layout() -> void:
	var mx := _arredondar_p(margem_x)
	var my := _arredondar_p(margem_y)
	var altura_linha := _fonte.get_height(tamanho_fonte)
	var altura_texto := altura_linha * linhas_por_pagina + espaco_linhas * (linhas_por_pagina - 1)
	var altura_caixa := _arredondar_p(altura_texto + my * 2)
	var largura := _arredondar_p(largura_caixa)

	# Card: 32 px de arte de retrato + 1 de borda e 1 de folga de cada lado.
	var lado_card := (32 + 4) * P
	var vao := 2 * P
	var aba_visivel := 8 * P
	var topo_caixa := maxf(aba_visivel, lado_card - altura_caixa)
	var base := topo_caixa + altura_caixa

	_card.size = Vector2(lado_card, lado_card)
	_card.position = Vector2(0, base - lado_card)
	_retrato.position = Vector2(2 * P, 2 * P)
	_retrato.size = Vector2(32 * P, 32 * P)

	_caixa.position = Vector2(lado_card + vao, topo_caixa)
	_caixa.size = Vector2(largura, altura_caixa)
	_texto.position = Vector2(mx, my)
	_texto.size = Vector2(largura - mx * 2, altura_caixa - my * 2)
	_seta.size = _seta.texture.get_size()
	_seta.position = Vector2(largura - 3 * P - _seta.size.x, altura_caixa - 3 * P - _seta.size.y)

	# A aba tem 11 px de arte de altura: 8 visíveis + 3 que cobrem o canto
	# chanfrado de cima da caixa (pra borda dela emendar na da caixa).
	_aba.position = Vector2(_caixa.position.x, topo_caixa - aba_visivel)
	_nome.position = Vector2(4 * P, P)
	_nome.size.y = 7 * P

	_rabicho.size = _rabicho.texture.get_size()
	_rabicho.position.y = base - P

	_raiz.size = Vector2(_caixa.position.x + largura, base - P + _rabicho.size.y)

func _process(delta: float) -> void:
	_tempo += delta
	if not _raiz.visible:
		return
	_atualizar_posicao()
	if digitando:
		_digitar(delta)
	elif _seta.visible:
		# Quica 1 pixel de arte, em degrau (nada de subpixel).
		_seta.position.y = _caixa.size.y - 3 * P - _seta.size.y - (P if fmod(_tempo, 0.6) < 0.3 else 0)

# --- Falante / posição -------------------------------------------------------

## Troca quem está falando: retrato, nome, voz e o nó que a caixa acompanha.
func definir_falante(personagem: CharacterData, expressao: String, alvo: Node2D) -> void:
	_personagem = personagem
	_alvo = alvo
	_retrato.texture = personagem.retrato(expressao) if personagem != null else null
	_nome.text = personagem.nome if personagem != null else ""
	_aba.visible = not _nome.text.is_empty()
	_nome.size.x = _fonte.get_string_size(_nome.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_fonte).x
	# Aba: 4 px de arte à esquerda do nome + a ponta diagonal (9) à direita.
	_aba.size = Vector2(_arredondar_p(_nome.size.x + 4 * P + 9 * P + P), _aba.texture.get_height())
	_bip.stream = personagem.bip if personagem != null else null
	if is_inside_tree() and _raiz.visible:
		_atualizar_posicao()

## Centraliza a caixa no falante, acima da cabeça, presa dentro da tela. O
## rabicho corre por baixo da caixa pra continuar apontando pro falante mesmo
## quando a caixa foi empurrada pela borda.
func _atualizar_posicao() -> void:
	var tela := get_viewport().get_visible_rect().size
	var ponta := Vector2(tela.x * 0.5, tela.y - margem_tela)
	var tem_alvo := _alvo != null and is_instance_valid(_alvo) and _alvo.is_inside_tree()
	if tem_alvo:
		var altura := _personagem.altura_cabeca if _personagem != null else 10.0
		ponta = _alvo.get_global_transform_with_canvas() * Vector2(0, -altura)

	var tam := _raiz.size
	var pos := Vector2(ponta.x - tam.x * 0.5, ponta.y - tam.y)
	pos.x = clampf(pos.x, margem_tela, maxf(margem_tela, tela.x - tam.x - margem_tela))
	pos.y = clampf(pos.y, margem_tela, maxf(margem_tela, tela.y - tam.y - margem_tela))
	_raiz.position = pos.round()

	var min_x := _caixa.position.x + 3 * P
	var max_x := _caixa.position.x + _caixa.size.x - 3 * P - _rabicho.size.x
	var rx := clampf(ponta.x - _raiz.position.x - _rabicho.size.x * 0.5, min_x, max_x)
	_rabicho.position.x = floorf(rx / P) * P
	# Se a caixa foi empurrada pra longe da cabeça (falante colado no topo da
	# tela, por ex.), o rabicho apontaria pro nada -- some.
	_rabicho.visible = tem_alvo and absf(_raiz.position.y + tam.y - ponta.y) <= 2 * P
	_raiz.pivot_offset = Vector2(_rabicho.position.x + _rabicho.size.x * 0.5, tam.y)

# --- Abrir / fechar ----------------------------------------------------------

func abrir() -> void:
	_raiz.visible = true
	_atualizar_posicao()
	_raiz.scale = Vector2(1, 0)
	_raiz.modulate.a = 0.0
	_animar(1.0)

func fechar() -> void:
	digitando = false
	_seta.visible = false
	_animar(0.0).tween_callback(func() -> void: _raiz.visible = false)

func _animar(alvo: float) -> Tween:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_raiz, "scale:y", alvo, duracao_abrir)
	_tw.tween_property(_raiz, "modulate:a", alvo, duracao_abrir)
	_tw.chain()
	return _tw

# --- Páginas / typewriter ----------------------------------------------------

## Quebra o texto em linhas que cabem na caixa (deixando espaço pra seta) e
## agrupa em páginas de `linhas_por_pagina`. A quebra é feita aqui e não pelo
## autowrap do Label pra a linha não "pular" de lugar no meio do typewriter.
func paginar(texto: String) -> PackedStringArray:
	var largura := _texto.size.x - _seta.size.x - P
	var linhas := PackedStringArray()
	for paragrafo in texto.split("\n"):
		var atual := ""
		for palavra in paragrafo.split(" ", false):
			var tentativa := palavra if atual.is_empty() else atual + " " + palavra
			if atual.is_empty() or _largura(tentativa) <= largura:
				atual = tentativa
			else:
				linhas.append(atual)
				atual = palavra
		linhas.append(atual)
	var paginas := PackedStringArray()
	for i in range(0, linhas.size(), linhas_por_pagina):
		paginas.append("\n".join(linhas.slice(i, i + linhas_por_pagina)))
	return paginas

func _largura(s: String) -> float:
	return _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_fonte).x

func mostrar_pagina(pagina: String) -> void:
	_pagina = pagina
	_visiveis = 0
	_acumulado = 0.0
	_espera = 0.0
	_letras_desde_bip = 0
	_texto.text = ""
	_seta.visible = false
	digitando = true

func completar() -> void:
	_visiveis = _pagina.length()
	_texto.text = _pagina
	digitando = false
	_seta.visible = true
	pagina_completa.emit()

func _digitar(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		return
	var lps := _personagem.letras_por_segundo if _personagem != null else 35.0
	_acumulado += delta * lps
	while _acumulado >= 1.0 and digitando:
		_acumulado -= 1.0
		_visiveis += 1
		_texto.text = _pagina.substr(0, _visiveis)
		if _visiveis >= _pagina.length():
			completar()
			return
		var letra := _pagina[_visiveis - 1]
		var proxima := _pagina[_visiveis]
		_tocar_bip(letra)
		# Pausa só no fim de "..." / "?!" (a próxima já não é pontuação).
		if not PONTUACAO_FORTE.contains(proxima) and not PONTUACAO_FRACA.contains(proxima):
			if PONTUACAO_FORTE.contains(letra):
				_espera = pausa_ponto
			elif PONTUACAO_FRACA.contains(letra):
				_espera = pausa_virgula
			if _espera > 0.0:
				_acumulado = 0.0
				return

func _tocar_bip(letra: String) -> void:
	if _bip.stream == null or letra.strip_edges().is_empty():
		return
	_letras_desde_bip += 1
	if _letras_desde_bip < _personagem.bip_a_cada:
		return
	_letras_desde_bip = 0
	_bip.volume_db = _personagem.bip_volume_db
	_bip.pitch_scale = _personagem.bip_pitch * randf_range(1.0 - _personagem.bip_variacao, 1.0 + _personagem.bip_variacao)
	_bip.play()
