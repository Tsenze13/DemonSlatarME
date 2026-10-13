// Дуга стихии вокруг удара — как в аниме, плоские краски с контуром.
// style 0 — чистый срез, 1 — вода (гравюра укиё-э: тёмный контур, синие струи
// вдоль течения, белые завитки пены на гребне), 2 — кольцо, 3 — пламя (языки огня
// по внешнему краю, жёлто-белая сердцевина, красная кромка), 4 — молния (золотая
// лента с рваной белой искрой внутри).
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
		// --- вода ---
		vec3 ink = col_a.rgb * vec3(0.18, 0.25, 0.4);
		vec3 deep = col_a.rgb * 0.75;
		vec3 light = mix(col_a.rgb, col_b.rgb, 0.45);
		// струи вдоль течения: полосы чуть волнистые и бегут вперёд
		float flow = fract(y * 4.0 + sin(x * 18.0 - t * 5.0) * 0.12);
		c = mix(deep, col_a.rgb * 1.15, step(0.5, flow));
		c = mix(c, light, step(0.86, flow));
		// гребень: ряд завитков пены (как «Большая волна»)
		if (y > 0.62) {
			float cx = fract(x * 16.0 - t * 1.5);
			vec2 q = vec2((cx - 0.5) * 2.0, (y - 0.82) / 0.2);
			float r = length(q);
			float curl = step(r, 0.95) * step(0.45, r);
			float inner = step(r, 0.3);
			float foam = max(curl, step(0.9, y));
			c = mix(c, col_b.rgb, foam);
			c = mix(c, ink, inner * step(0.7, y));
		}
		// брызги-«когти» над гребнем
		float claw = step(0.97, hash(floor(vec2(x * 50.0, y * 10.0)))) * step(0.55, y);
		c = mix(c, col_b.rgb, claw);
		// чернильный контур по краям ленты
		float edge = step(taper - 0.12, w);
		c = mix(c, ink, edge);
	} else if (style == 3) {
		// --- пламя: внешний край — языки огня, рвутся и колышутся ---
		float fl = fract(x * 13.0 - t * 3.0 + sin(x * 31.0 + t * 7.0) * 0.15);
		float tongue = 1.0 - abs(fl * 2.0 - 1.0);
		float outer = taper * (0.55 + 0.45 * tongue * tongue);
		float lim = y > 0.5 ? outer : taper * 0.85;
		shape = step(w, lim);
		a = shape * vis;
		float k = w / max(lim, 0.001);
		vec3 yel = col_b.rgb;
		vec3 org = mix(col_a.rgb, col_b.rgb, 0.45);
		c = mix(yel, org, smoothstep(0.25, 0.55, k));
		c = mix(c, col_a.rgb, smoothstep(0.6, 0.85, k));
		c = mix(c, col_a.rgb * 0.35, step(0.9, k));
		// завитки огня внутри
		float swirl = step(0.93, fract(x * 9.0 + y * 3.0 - t * 2.0));
		c = mix(c, yel, swirl * 0.7);
	} else if (style == 4) {
		// --- молния: золотая лента, внутри рваная белая искра ---
		float zig = abs(fract(x * 22.0 + floor(t * 20.0) * 0.37) * 2.0 - 1.0);
		float centre = 0.5 + (zig - 0.5) * 0.45 * taper;
		float spark = step(abs(y - centre), 0.07 * taper);
		c = mix(col_a.rgb, col_a.rgb * 0.5, step(taper - 0.15, w));
		c = mix(c, col_b.rgb, spark);
		// вспышки — лента мерцает
		a *= 0.6 + 0.4 * step(0.3, hash(vec2(floor(t * 24.0), 1.0)));
	} else if (style == 0) {
		// чистый срез как в аниме: полумесяц, к внешнему краю — белая режущая линия,
		// внутрь — цвет стиля и прозрачность, поверх — тонкие линии скорости
		c = mix(col_a.rgb * 0.95, col_b.rgb, smoothstep(0.55, 0.8, y));
		a *= 0.25 + 0.75 * smoothstep(0.1, 0.65, y);
		float speed = step(0.94, fract(y * 9.0 + hash(vec2(floor(x * 10.0), 3.0)) * 0.5)) * step(0.4, hash(vec2(floor(x * 14.0), 7.0)));
		c = mix(c, col_b.rgb, speed);
		c = mix(c, col_a.rgb * 0.45, step(0.93, y) * step(w, taper));
	} else {
		c = mix(col_a.rgb, col_b.rgb, step(0.6, w));
	}
	// рваный хвост
	float rag = step(tail + hash(floor(vec2(x * 40.0, y * 4.0))) * 0.18, x);
	ALBEDO = c;
	ALPHA = clamp(a * rag * opacity, 0.0, 1.0);
}
