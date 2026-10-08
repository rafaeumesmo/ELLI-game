class_name CharacterData
extends Resource
## Ficha de quem fala no sistema de diálogo (ver DialogueManager). Um .tres por
## personagem em res://dialogues/personagens/. Pra trocar a arte, é só arrastar
## os PNGs novos no dicionário `retratos` (chave = expressão).

## Identificador usado pra achar o nó de quem fala na cena (as chaves do
## `speakers` de DialogueManager.start). "elisio" acha o player sozinho.
@export var id: String = ""
## Nome que aparece na aba em cima da caixa.
@export var nome: String = ""
## Retrato por expressão ("neutro", "feliz", "surpreso", "triste"...). Uma
## expressão que faltar cai no "neutro". Arte de 32x32 (aparece 3x maior).
@export var retratos: Dictionary[String, Texture2D] = {}

@export_group("Voz")
## Bip curto tocado durante o typewriter (vazio = mudo).
@export var bip: AudioStream
@export var bip_volume_db: float = -12.0
@export var bip_pitch: float = 1.0
## Variação aleatória do pitch, pra cada bip soar um pouco diferente.
@export_range(0.0, 0.5, 0.01) var bip_variacao: float = 0.08
## Toca o bip a cada N letras (1 = toda letra).
@export_range(1, 6) var bip_a_cada: int = 2
## Velocidade do typewriter desse personagem, em letras por segundo.
@export var letras_por_segundo: float = 35.0

@export_group("Posição")
## Quanto acima da origem do nó (em px locais dele) fica a cabeça -- é ali que
## o rabicho do balão aponta.
@export var altura_cabeca: float = 10.0

func retrato(expressao: String) -> Texture2D:
	if retratos.has(expressao):
		return retratos[expressao]
	return retratos.get("neutro", null)
