// Дуга стихии вокруг удара. style 0 — чистый срез, 1 — волна Прилива
// (как на японских гравюрах: синее тело, белая пена завитками), 2 — кольцо.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 col_a : source_color = vec4(0.12, 0.35, 0.85, 1.0);
uniform vec4 col_b : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float head = 1.0;   // докуда дуга нарисована
uniform float tail = 0.0;   // откуда уже исчезла
uniform float opacity = 1.0;
uniform int style = 1;
uniform float t = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float vis = step(tail, x) * step(x, head);
	// заострённые концы дуги
	float taper = smoothstep(0.0, 0.12, x) * smoothstep(1.0, 0.8, x);
	float w = abs(y - 0.5) * 2.0;
	float shape = step(w, taper);
	vec3 c = col_a.rgb;
	float a = shape * vis;
	if (style == 1) {
		// волна: тёмная нижняя часть, светлая середина, пенный гребень
		float band = smoothstep(0.0, 1.0, y);
		c = mix(col_a.rgb * 0.7, col_a.rgb * 1.25, band);
		float curls = sin(x * 46.0 - y * 9.0 + t * 6.0);
		float foam = step(0.62, y) * step(0.35, curls);
		float crest = step(0.8, y + hash(floor(vec2(x * 60.0, 0.0))) * 0.15);
		c = mix(c, col_b.rgb, max(foam, crest));
		float stripe = step(0.92, fract(x * 14.0 + y * 2.0));
		c = mix(c, col_b.rgb, stripe * 0.6);
	} else if (style == 0) {
		c = mix(col_a.rgb, col_b.rgb, smoothstep(0.2, 0.0, w));
	} else {
		c = mix(col_a.rgb, col_b.rgb, step(0.6, w));
	}
	// рваный хвост
	float rag = step(tail + hash(floor(vec2(x * 40.0, y * 4.0))) * 0.18, x);
	ALBEDO = c;
	ALPHA = clamp(a * rag * opacity, 0.0, 1.0);
}
