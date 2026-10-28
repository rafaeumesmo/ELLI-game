class_name DustFxComum
extends RefCounted
## Pedacinhos compartilhados pelos 3 efeitos de poeira do player (DustRun,
## DustLand, DustWall): a mesma cor, a mesma curva de escala (encolhe até
## sumir) e a mesma rampa de alpha (some suave no fim, sem piscar).

const COR_POEIRA := Color(0.78, 0.7, 0.56)
static var _textura: ImageTexture
static var _curva_escala: CurveTexture
static var _rampas: Dictionary = {}

## TODO ARTE: quadradinho branco placeholder até ter uma textura de poeira de verdade.
static func textura_placeholder() -> ImageTexture:
	if _textura != null:
		return _textura
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_textura = ImageTexture.create_from_image(img)
	return _textura

## Partícula nasce no tamanho cheio e encolhe até 0 ao longo da vida.
static func curva_escala_decrescente() -> CurveTexture:
	if _curva_escala != null:
		return _curva_escala
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curva
	_curva_escala = tex
	return tex

## Fica visível a maior parte da vida e só desvanece o alpha no fim (sem sumir de repente).
static func rampa_alpha_sumindo(cor: Color) -> GradientTexture1D:
	if _rampas.has(cor):
		return _rampas[cor]
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(cor.r, cor.g, cor.b, 0.85),
		Color(cor.r, cor.g, cor.b, 0.85),
		Color(cor.r, cor.g, cor.b, 0.0),
	])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	_rampas[cor] = tex
	return tex
