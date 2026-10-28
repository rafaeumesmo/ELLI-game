shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 claro = pow(tex.rgb, vec3(0.55)) * 1.15;
    COLOR = vec4(clamp(claro, vec3(0.0), vec3(1.0)), tex.a);
}
