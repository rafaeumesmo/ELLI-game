class_name DustFxComum
extends RefCounted
## Pedacinhos compartilhados pelos 3 efeitos de poeira do player (DustRun,
## DustLand, DustWall): a mesma cor, a mesma curva de escala (encolhe até
## sumir) e a mesma rampa de alpha (some suave no fim, sem piscar).

const COR_POEIRA := Color(0.78, 0.7, 0.56)

## TODO ARTE: quadradinho branco placeholder até ter uma textura de poeira de verdade.
static func textura_placeholder() -> ImageTexture:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

## Partícula nasce no tamanho cheio e encolhe até 0 ao longo da vida.
static func curva_escala_decrescente() -> CurveTexture:
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curva
	return tex

## Fica visível a maior parte da vida e só desvanece o alpha no fim (sem sumir de repente).
static func rampa_alpha_sumindo(cor: Color) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(cor.r, cor.g, cor.b, 0.85),
		Color(cor.r, cor.g, cor.b, 0.85),
		Color(cor.r, cor.g, cor.b, 0.0),
	])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex
