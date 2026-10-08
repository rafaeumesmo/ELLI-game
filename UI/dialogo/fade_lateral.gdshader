shader_type canvas_item;
// Degradê pra transparente nas laterais (painel do diálogo e linhas do
// ornamento). fade_esq / fade_dir = fração da largura que esmaece de cada lado.
// degraus > 0 quantiza o degradê em faixas, pra combinar com o pixel art.

uniform float fade_esq : hint_range(0.0, 1.0) = 0.12;
uniform float fade_dir : hint_range(0.0, 1.0) = 0.12;
uniform float degraus = 6.0;

float rampa(float x, float largura) {
	if (largura <= 0.0) {
		return 1.0;
	}
	float a = clamp(x / largura, 0.0, 1.0);
	if (degraus > 0.0) {
		a = ceil(a * degraus) / degraus;
	}
	return a;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a *= rampa(UV.x, fade_esq) * rampa(1.0 - UV.x, fade_dir);
	COLOR = c;
}
