extends PointLight2D
## Luz sutil que acompanha o Elísio no escuro -- brilho pequeno tipo vagalume,
## não holofote. A textura (`luz_personagem.tres`) é branca e sem cor própria;
## quem dá a cor é o `cor_luz` daqui, com alpha caindo rápido perto do centro
## pra não ficar com o meio chapado.

@export var cor_luz: Color = Color("#FFD98A"):
	set(v):
		cor_luz = v
		color = v
@export var energia: float = 0.6:
	set(v):
		energia = v
		energy = v
## Controla `texture_scale` -- o raio visível da luz.
@export var raio: float = 0.25:
	set(v):
		raio = v
		texture_scale = v

func _ready() -> void:
	color = cor_luz
	energy = energia
	texture_scale = raio
