class_name DialogueLine
extends Resource
## Uma fala de um DialogueData: quem fala, com que cara, e o quê. Texto longo
## é quebrado em páginas de 2 linhas sozinho.

@export var personagem: CharacterData
@export_enum("neutro", "feliz", "surpreso", "triste") var expressao: String = "neutro"
@export_multiline var texto: String = ""
