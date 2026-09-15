@tool
extends Sprite2D

## Cristal de granito (cenário). Só um Sprite2D com escolha de desenho.
##
## É uma cena única reutilizável: arraste "Granito.tscn" para dentro do nó
## "Cenario" do mapa quantas vezes quiser. O nó "Cenario" já joga tudo para
## trás (z_index negativo).

enum Variacao { GRANITO_00, GRANITO_01, GRANITO_02, GRANITO_03 }

const TEXTURAS := {
	Variacao.GRANITO_00: preload("res://assets/pedras/granito00.png"),
	Variacao.GRANITO_01: preload("res://assets/pedras/granito01.png"),
	Variacao.GRANITO_02: preload("res://assets/pedras/granito02.png"),
	Variacao.GRANITO_03: preload("res://assets/pedras/granito03.png"),
}

## Qual desenho de granito usar.
@export var variacao: Variacao = Variacao.GRANITO_00:
	set(value):
		variacao = value
		_atualizar_textura()

## Se ligado, cada pedra nasce espelhada aleatoriamente para variar o visual.
@export var espelhar_aleatorio: bool = false

func _ready() -> void:
	_atualizar_textura()
	if not Engine.is_editor_hint() and espelhar_aleatorio:
		flip_h = randf() < 0.5

func _atualizar_textura() -> void:
	texture = TEXTURAS[variacao]
