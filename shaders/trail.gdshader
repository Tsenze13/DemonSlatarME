// Мазок клинка в стиле дыхания (как в аниме): лента тянется ровно за клинком.
// style 0 — белый срез; 1 — вода-гравюра (синие струи, белые завитки пены,
// чернильный контур); 3 — пламя (языки огня по внешнему краю, жёлтая сердцевина);
// 4 — молния (золотая лента с белой рваной искрой).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 col_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 col_edge : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform vec4 col_a : source_color = vec4(0.1, 0.35, 0.85, 1.0);
uniform vec4 col_b : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform int style = 0;
uniform float opacity = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float age = UV.x;          // 0 — свежий край, 1 — хвост
	float across = UV.y;       // 0 — у рукояти, 1 — внешний край
	vec3 c;
	float a;
	// пиксельная сетка ленты — эффекты из «блоков», как весь мир
	vec2 q = vec2(floor(age * 28.0) / 28.0, floor(across * 10.0) / 10.0);
	if (style == 1) {
		// вода: лента сужается к хвосту, внешний край — гребень с пеной
		float width = 1.0 - q.x * 0.85;
		float inner = 1.0 - width;                    // лента «отрывается» от клинка к хвосту
		float body = step(inner * 0.6, q.y) * step(q.y, 1.0);
		vec3 ink = col_a.rgb * vec3(0.18, 0.25, 0.4);
		vec3 deep = col_a.rgb * 0.8;
		float flow = fract(q.y * 3.0 - q.x * 2.0 + TIME * 2.5 + sin(q.x * 9.0) * 0.2);
		c = mix(deep, col_a.rgb * 1.2, step(0.5, flow));
		c = mix(c, mix(col_a.rgb, col_b.rgb, 0.55), step(0.85, flow));
		// завитки пены на гребне
		if (q.y > 0.7) {
			float cx = fract(q.x * 7.0 - TIME * 0.8);
			vec2 cc = vec2((cx - 0.5) * 2.0, (q.y - 0.86) / 0.16);
			float r = length(cc);
			c = mix(c, col_b.rgb, step(r, 0.95) * step(0.4, r));
			c = mix(c, ink, step(r, 0.25));
		}
		// чернильный контур по краям и рваный хвост
		float edge = step(0.92, q.y) + step(q.y, inner * 0.6 + 0.1) * 0.0;
		c = mix(c, ink, clamp(edge, 0.0, 1.0) * 0.8);
		float rag = step(q.x, 1.0 - hash(vec2(floor(q.y * 10.0), 3.0)) * 0.35);
		// брызги-капли за хвостом
		a = body * rag;
		a = max(a, step(0.94, hash(floor(vec2(age * 40.0, across * 14.0)) + floor(TIME * 6.0))) * step(0.5, q.x) * 0.9);
	} else if (style == 3) {
		// пламя: внешний край — языки, бегущие вдоль ленты
		float fl = fract(q.x * 6.0 - TIME * 3.0 + hash(vec2(floor(q.x * 6.0 - TIME * 3.0), 1.0)) * 0.3);
		float tongue = 1.0 - abs(fl * 2.0 - 1.0);
		float lim = 0.55 + 0.45 * tongue * tongue * (1.0 - q.x * 0.5);
		float body = step(q.y, lim) * step(q.x * 0.5, q.y);
		float k = q.y / max(lim, 0.01);
		c = mix(col_b.rgb, mix(col_a.rgb, col_b.rgb, 0.45), smoothstep(0.2, 0.5, k));
		c = mix(c, col_a.rgb, smoothstep(0.55, 0.85, k));
		c = mix(c, col_a.rgb * 0.3, step(0.9, k));
		c = mix(c, col_a.rgb, smoothstep(0.4, 1.0, q.x));     // хвост темнее
		a = body * step(q.x, 0.95 - hash(vec2(floor(q.y * 10.0), 7.0)) * 0.3);
	} else if (style == 4) {
		// молния: золотая лента, внутри рваная белая искра, лента мерцает
		float zig = abs(fract(q.x * 9.0 + floor(TIME * 18.0) * 0.37) * 2.0 - 1.0);
		float centre = 0.55 + (zig - 0.5) * 0.4;
		float spark = step(abs(q.y - centre), 0.09);
		float body = step(0.25, q.y) * step(q.y, 0.95);
		c = mix(col_a.rgb, col_b.rgb, spark);
		c = mix(c, col_a.rgb * 0.5, step(0.88, q.y) * (1.0 - spark));
		a = body * step(q.x, 0.9) * (0.65 + 0.35 * step(0.3, hash(vec2(floor(TIME * 24.0), 2.0))));
		a = max(a, spark * step(q.x, 1.0));
	} else {
		vec2 cell = floor(vec2(UV.x * 18.0, UV.y * 6.0));
		float n = hash(cell);
		float body = smoothstep(0.0, 0.25, across);
		float ragged = step(age, 1.0 - n * 0.55);
		a = body * ragged * (1.0 - age * 0.6);
		c = mix(col_edge.rgb, col_core.rgb, smoothstep(0.55, 0.92, across) * (1.0 - age));
	}
	ALBEDO = c;
	ALPHA = clamp(a * opacity, 0.0, 1.0);
}
