// Земля и горы из вокселей: верх — трава / вытоптанная земля / камень,
// бока уступов — полосы грунта и скала. Пиксельные текстуры 16 px на метр
// в мировых координатах, мягкий свет без чёрных теней.
// COLOR.rgb — оттенок, COLOR.a — материал: 0 трава, 0.5 земля, 1 камень.
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D tex_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_side : source_color, filter_nearest, repeat_enable;
uniform float px = 1.0;            // плотность текстуры: повторов на метр

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 c;
	float mat_id = COLOR.a;
	if (wn.y > 0.5) {
		vec2 uv = wp.xz * px;
		vec3 g = texture(tex_grass, uv).rgb;
		vec3 d = texture(tex_dirt, uv).rgb;
		vec3 r = texture(tex_rock, uv).rgb;
		c = mat_id < 0.25 ? g : (mat_id < 0.75 ? d : r);
		// крупные пятна оттенка (по 4 м) — луг не однотонный
		vec2 cell = floor(wp.xz / 4.0);
		c *= 0.93 + 0.12 * hash(cell);
	} else {
		vec2 uv = (abs(wn.x) > 0.5 ? wp.zy : wp.xy) * px;
		uv.y = -uv.y;
		vec3 s = texture(tex_side, uv).rgb;
		vec3 r = texture(tex_rock, uv).rgb;
		// верхний метр уступа — земля под дёрном, ниже — скала с полосами
		float top_band = fract(wp.y);
		c = mat_id < 0.75 ? s : r;
		// у самой кромки — край травы
		if (mat_id < 0.25 && top_band > 0.82) {
			c = texture(tex_grass, uv).rgb;
		}
	}
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = mix(0.28, 1.0, smoothstep(0.03, 0.35, nl));
	if (!LIGHT_IS_DIRECTIONAL) {
		l = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
	}
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
