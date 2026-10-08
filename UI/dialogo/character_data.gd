class_name CharacterData
extends Resource
## Ficha de quem fala no sistema de diálogo (ver DialogueManager). Um .tres por
## personagem em res://dialogues/personagens/. Pra trocar a arte, é só arrastar
## os PNGs novos no dicionário `retratos` (chave = expressão).

## Identificador usado pra achar o nó de quem fala na cena (as chaves do
## `speakers` de DialogueManager.start). "elisio" acha o player sozinho.
@export var id: String = ""
## Nome que aparece acima do texto.
@export var nome: String = ""

@export_group("Retrato")
## Retrato por expressão ("neutro", "feliz", "surpreso", "triste"...). Uma
## expressão que faltar cai no "neutro". Arte de 32x32 (aparece 4x maior).
@export var retratos: Dictionary[String, Texture2D] = {}
## Opcional: retratos animados (piscar, boca). Cada animação tem o nome da
## expressão ("neutro", "feliz"...); "<expressão>_falando" é usada enquanto o
## texto digita, se existir. Tem prioridade sobre `retratos`.
@export var retratos_animados: SpriteFrames
## Lado da tela do retrato: o Elísio fala da esquerda, os NPCs da direita.
@export var lado_esquerdo: bool = false
## Tamanho do retrato em relação ao normal (0.6 = 60%), pra personagem pequeno
## parecer pequeno. Fica apoiado na mesma base dos outros.
@export_range(0.2, 1.5, 0.05) var escala_retrato: float = 1.0
## Pra onde o desenho do retrato olha. O retrato é espelhado sozinho pra olhar
## sempre pro centro da tela.
@export var retrato_olha_para_direita: bool = true

@export_group("Voz")
## 3-5 resmungos curtos (estilo Hollow Knight). Um é sorteado a cada
## `voz_a_cada_min`..`voz_a_cada_max` letras. Vazio = mudo.
@export var vozes: Array[AudioStream] = []
@export var voz_volume_db: float = -8.0
@export var voz_pitch: float = 1.0
## Variação aleatória do pitch (0.1 = ±10%).
@export_range(0.0, 0.5, 0.01) var voz_variacao: float = 0.1
@export_range(1, 12) var voz_a_cada_min: int = 4
@export_range(1, 12) var voz_a_cada_max: int = 6
## Velocidade do typewriter desse personagem, em letras por segundo.
@export var letras_por_segundo: float = 35.0

func retrato(expressao: String) -> Texture2D:
	if retratos.has(expressao):
		return retratos[expressao]
	return retratos.get("neutro", null)
