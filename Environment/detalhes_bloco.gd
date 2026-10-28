extends Node2D
## Relevo e fissuras estáticos com tons derivados da textura original.

var tamanho := Vector2(16, 16)
var textura: Texture2D
static var _tons: Dictionary = {}

static func tom_da_textura(tex: Texture2D) -> Color:
	if tex == null:
		return Color("55505e")
	if _tons.has(tex):
		return _tons[tex]
	var imagem := tex.get_image()
	var soma := Vector3.ZERO
	var peso := 0.0
	if imagem != null:
		for y in imagem.get_height():
			for x in imagem.get_width():
				var pixel := imagem.get_pixel(x, y)
				soma += Vector3(pixel.r, pixel.g, pixel.b) * pixel.a
				peso += pixel.a
	var tom := Color("55505e")
	if peso > 0.0:
		soma /= peso
		tom = Color(soma.x, soma.y, soma.z)
	_tons[tex] = tom
	return tom

func _draw() -> void:
	var tom := tom_da_textura(textura)
	for y in int(tamanho.y / 16):
		for x in int(tamanho.x / 16):
			var p := -tamanho * 0.5 + Vector2(x, y) * 16
			desenhar(self, p, tom, posmod(x * 7 + y * 11, 5))

static func desenhar(alvo: CanvasItem, p: Vector2, tom: Color, variacao: int) -> void:
	# Planos curtos e rachadura em degraus; evita a moldura fechada.
	var luz := Color(tom.lightened(0.12), 0.55)
	var sombra := Color(tom.darkened(0.3), 0.65)
	alvo.draw_rect(Rect2(p + Vector2(2, 2), Vector2(6 + variacao % 3, 1)), luz)
	alvo.draw_rect(Rect2(p + Vector2(2, 3), Vector2(3, 1)), Color(tom.lightened(0.06), 0.45))
	var f := p + Vector2(7 + variacao % 3, 5)
	alvo.draw_rect(Rect2(f, Vector2(1, 3)), sombra)
	alvo.draw_rect(Rect2(f + Vector2(-2, 2), Vector2(3, 1)), sombra)
	alvo.draw_rect(Rect2(f + Vector2(-2, 3), Vector2(1, 3)), sombra)
	alvo.draw_rect(Rect2(f + Vector2(1, 0), Vector2(1, 2)), Color(tom.lightened(0.12), 0.35))
	alvo.draw_rect(Rect2(p + Vector2(3, 12), Vector2(4, 1)), sombra)
	alvo.draw_rect(Rect2(p + Vector2(10, 11), Vector2(3, 1)), luz)
