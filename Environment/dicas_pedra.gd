extends Node2D
## Colinha feita de pequenas pedras na parede do tutorial. Desenho estático.

const LETRAS := {
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"I": ["111", "010", "010", "010", "111"],
	"L": ["100", "100", "100", "100", "111"],
	"N": ["101", "111", "111", "111", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"],
	"U": ["101", "101", "101", "101", "111"],
}
const TINTA := Color("a3a698")
const LEGENDA := Color("73796e")
const PEDRA := Color("41434a")

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func _texto(texto: String, p: Vector2, cor: Color) -> void:
	for i in texto.length():
		var letra: String = texto[i]
		if not LETRAS.has(letra):
			continue
		var linhas: Array = LETRAS[letra]
		for y in 5:
			for x in 3:
				if linhas[y][x] == "1":
					var ponto := p + Vector2(i * 4 + x, y)
					draw_rect(Rect2(ponto + Vector2.DOWN, Vector2.ONE), Color(0.08, 0.08, 0.10, 0.65))
					draw_rect(Rect2(ponto, Vector2.ONE), cor)

func _tecla(texto: String, p: Vector2, largura: float = 11.0) -> void:
	# Cantos lascados e junta escura: parecem pequenas placas de rocha.
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(largura - 2, 10)), Color("272932"))
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(largura, 7)), PEDRA)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(largura - 2, 1)), Color("6a6d68"))
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(largura - 4, 1)), Color("50534f"))
	draw_rect(Rect2(p + Vector2(largura - 2, 4), Vector2(1, 4)), Color("343640"))
	_texto(texto, p + Vector2(floorf((largura - (texto.length() * 4 - 1)) * 0.5), 4), TINTA)

func _draw() -> void:
	# Colinha na face do chão, abaixo da superfície caminhável.
	var p := Vector2(-157, 72)
	_tecla("A", p)
	_tecla("D", p + Vector2(16, 0))
	_texto("ANDAR", p + Vector2(4, 15), LEGENDA)
	# Espaço na face do primeiro degrau, sem ocupar o corredor.
	p = Vector2(-87, 40)
	_tecla("ESPACO", p, 32)
	_texto("PULAR", p + Vector2(6, 15), LEGENDA)
