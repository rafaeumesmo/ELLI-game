shader_type canvas_item;

// saturation = 0.0 -> totalmente cinza
// saturation = 1.0 -> cor original
uniform float saturation : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float gray = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(vec3(gray), COLOR.rgb, saturation);
}
