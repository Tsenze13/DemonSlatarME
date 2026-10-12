// Мазок клинка: светлый край у острия, цвет дыхания, рваный хвост как от кисти.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 col_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 col_edge : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform float opacity = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float age = UV.x;          // 0 — свежий край, 1 — хвост
	float across = UV.y;       // 0 — у рукояти, 1 — у острия
	vec2 cell = floor(vec2(UV.x * 18.0, UV.y * 6.0));
	float n = hash(cell);
	float body = smoothstep(0.0, 0.25, across);
	float ragged = step(age, 1.0 - n * 0.55);
	float a = body * ragged * (1.0 - age * 0.6) * opacity;
	vec3 c = mix(col_edge.rgb, col_core.rgb, smoothstep(0.55, 0.92, across) * (1.0 - age));
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}
