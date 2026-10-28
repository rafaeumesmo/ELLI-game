shader_type canvas_item;
render_mode unshaded;

uniform vec2 tamanho = vec2(64.0, 160.0);
uniform float velocidade = 48.0;

void fragment() {
    // Coordenadas inteiras preservam os pixels na escala das fases.
    vec2 pixel = floor(UV * tamanho);
    float tempo = floor(TIME * 12.0) / 12.0;
    float faixa = floor(pixel.x / 3.0);
    float variacao = sin(faixa * 5.7);
    float fluxo = mod(pixel.y - tempo * velocidade * (1.0 + variacao * 0.18)
        + faixa * 13.0, 37.0);
    float filete = step(27.0, fluxo);
    float borda = min(pixel.x, tamanho.x - 1.0 - pixel.x);
    float recorte = 2.0 + floor(sin(pixel.y * 0.12 - tempo * 3.0) * 1.5);
    float mascara = step(recorte, borda);
    float opacidade = mix(0.28, 0.55, smoothstep(0.0, 9.0, borda));
    vec3 agua = mix(vec3(0.23, 0.44, 0.49), vec3(0.54, 0.72, 0.70), filete * 0.65);
    // Espuma irregular no impacto e pequenos fios claros descendo.
    float espuma = step(tamanho.y - 7.0 + sin(faixa * 2.0 + tempo * 5.0) * 2.0, pixel.y);
    agua = mix(agua, vec3(0.69, 0.82, 0.77), espuma * 0.8);
    opacidade = mix(opacidade, 0.7, espuma);
    COLOR = vec4(agua, opacidade * mascara);
}
