// Трава из воксельных травинок: цвет ступенями от корня к кончику (пиксельно),
// качается на ветру, расступается вокруг героя. flower — цветок: стебель зелёный,
// головка — цвет экземпляра.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 col_root : source_color = vec4(0.16, 0.34, 0.12, 1.0);
uniform vec4 col_mid : source_color = vec4(0.33, 0.56, 0.2, 1.0);
uniform vec4 col_tip : source_color = vec4(0.55, 0.76, 0.3, 1.0);
uniform vec3 player_pos = vec3(0.0);
uniform float wind = 1.0;
uniform bool flower = false;
uniform vec3 shock_pos = vec3(0.0, -100.0, 0.0);
uniform float shock_age = 99.0;

varying float h;
varying vec3 inst_col;

void vertex() {
	h = clamp(VERTEX.y / 0.55, 0.0, 1.0);
	inst_col = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// порывы ветра бегут волнами по лугу
	float gust = sin(TIME * 0.9 + base.x * 0.08 - base.z * 0.05) * 0.5 + 0.5;
	float sway = sin(TIME * 2.2 + base.x * 0.35 + base.z * 0.25) * (0.06 + 0.1 * gust) + sin(TIME * 5.3 + base.x * 1.3) * 0.02;
	vec3 off = vec3(sway, 0.0, sway * 0.5) * wind * h * h;
	vec2 dp = base.xz - player_pos.xz;
	float dist = length(dp);
	float push = (1.0 - smoothstep(0.0, 1.3, dist)) * h * step(abs(base.y - player_pos.y), 1.5);
	off.xz += normalize(dp + 0.0001) * push * 0.4;
	off.y -= push * 0.18;
	// ударная волна: кольцо бежит от места взрыва, травинки ложатся наружу
	vec2 sd = base.xz - shock_pos.xz;
	float sdist = length(sd);
	float front = shock_age * 14.0;
	float band = (1.0 - smoothstep(0.0, 2.2, abs(sdist - front))) * (1.0 - smoothstep(0.3, 1.0, shock_age));
	band *= step(sdist, 14.0);
	off.xz += normalize(sd + 0.0001) * band * h * 0.5;
	off.y -= band * h * 0.2;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	vec3 c;
	if (flower) {
		c = h > 0.55 ? inst_col : col_mid.rgb;
	} else {
		float q = floor(h * 4.0) / 3.0;          // 4 ступени цвета — «пиксели» по высоте
		c = q < 0.5 ? mix(col_root.rgb, col_mid.rgb, q * 2.0) : mix(col_mid.rgb, col_tip.rgb, (q - 0.5) * 2.0);
		c *= inst_col;
	}
	ALBEDO = c;
	NORMAL = vec3(0.0, 1.0, 0.0) * mat3(INV_VIEW_MATRIX);
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = mix(0.5, 1.0, smoothstep(0.15, 0.5, nl));
	if (!LIGHT_IS_DIRECTIONAL) {
		l = ATTENUATION;
	}
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
