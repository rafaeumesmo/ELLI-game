class_name DialogueData
extends Resource
## Uma conversa inteira, editável no Inspector (res://dialogues/*.tres). As
## falas podem ser de personagens diferentes -- a caixa pula pra cima de quem
## estiver falando.

@export var falas: Array[DialogueLine] = []
