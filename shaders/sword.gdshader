// Мечи из набора игрока: та же пиксельная текстура, но аниме-свет как у всего мира,
// у клинка — светлая режущая кромка, волнистая линия закалки (хамон)
// и блик, пробегающий от гарды к острию.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_k = 0.0;
uniform mat4 to_norm;               // меш → система меча: гарда в 0, клинок −Y, лезвие −Z
uniform bool is_blade = false;
uniform float blade_len = 0.85;
uniform float edge_lo[9];           // где лезвие (min z) по длине клинка
uniform float edge_w[9];            // ширина клинка по длине
uniform float glint_speed = 0.32;
uniform float glint_boost = 0.0;    // во время удара блик ярче

varying vec3 np;

void vertex() {
	np = (to_norm * vec4(VERTEX, 1.0)).xyz;
}

float prof(float f, bool lo) {
	float x = clamp(f, 0.0, 1.0) * 8.0;
	int i = int(floor(x));
	int j = min(i + 1, 8);
	float t = x - float(i);
	return lo ? mix(edge_lo[i], edge_lo[j], t) : mix(edge_w[i], edge_w[j], t);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.05) {
		discard;
	}
	vec3 col = c.rgb;
	if (tint_k > 0.0) {
		col = mix(col, col * tint.rgb * 1.3, tint_k);
	}
	float em = 0.0;
	if (is_blade) {
		float f = -np.y / blade_len;
		float lo = prof(f, true);
		float w = max(prof(f, false), 0.01);
		float k = (np.z - lo) / w;             // 0 — кромка, 1 — обух
		// режущая кромка: светлая полоска стали, пиксельная
		float qk = floor(k * 12.0) / 12.0;
		float edge = step(qk, 0.09);
		col = mix(col, vec3(0.93, 0.96, 1.0), edge * 0.75);
		// хамон: волнистая линия закалки чуть выше кромки
		float wave = 0.2 + 0.05 * sin(floor(f * 48.0) * 1.7) + 0.03 * sin(floor(f * 48.0) * 0.6);
		float ham = step(abs(qk - wave), 0.045);
		col = mix(col, col * 0.6 + vec3(0.45), ham * 0.55 * step(0.06, f));
		// блик: диагональная полоса бежит от гарды к острию
		float ph = fract(TIME * glint_speed) * 1.8 - 0.4;
		float d = abs(f + k * 0.12 - ph);
		float g = (1.0 - smoothstep(0.0, 0.05 + glint_boost * 0.04, d));
		em = g * (0.55 + glint_boost * 0.8);
		// у острия — маленькая искра
		em += step(0.97, f) * 0.25 * glint_boost;
	}
	ALBEDO = col;
	EMISSION = vec3(0.95, 0.97, 1.0) * em;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = mix(0.22, 1.0, smoothstep(0.04, 0.32, nl));
	if (!LIGHT_IS_DIRECTIONAL) {
		l = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
	}
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	r = step(0.45, r) * 0.25 * step(0.08, nl);
	DIFFUSE_LIGHT += (l + r) * LIGHT_COLOR;
}
