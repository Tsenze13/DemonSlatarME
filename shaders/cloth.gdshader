// Хаори: двусторонняя ткань с узором волн, аниме-свет.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 base : source_color = vec4(0.16, 0.27, 0.55, 1.0);
uniform vec4 pattern : source_color = vec4(0.85, 0.9, 0.95, 1.0);
uniform vec4 trim : source_color = vec4(0.08, 0.08, 0.12, 1.0);

void fragment() {
	vec2 uv = UV;
	vec3 c = base.rgb;
	// узор: полосы-волны в нижней половине
	float wave = sin(uv.x * 28.0) * 0.035;
	float bands = step(0.55, uv.y) * step(0.5, fract((uv.y + wave) * 7.0)) * step(fract((uv.y + wave) * 7.0), 0.62);
	c = mix(c, pattern.rgb, bands);
	// тёмная кайма по низу
	c = mix(c, trim.rgb, step(0.94, uv.y));
	ALBEDO = c;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = mix(0.2, 1.0, smoothstep(0.04, 0.32, nl));
	if (!LIGHT_IS_DIRECTIONAL) {
		l = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
	}
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
