// Аниме-свет: тени в три тона + лёгкий контровой свет.
// По желанию — пиксельная текстура 16×16 на метр (как в воксельных играх),
// наложенная по трём осям в мировых (мир) или локальных (персонажи) координатах.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission = 0.0;
uniform float rim = 0.18;
uniform float shade_floor = 0.0;
uniform sampler2D tex : filter_nearest, repeat_enable;
uniform bool use_tex = false;
uniform bool tex_local = false;
uniform float tex_scale = 1.0;
uniform vec2 tex_mul = vec2(1.0, 1.0);     // растяжение узора по осям (хаори на рукавах)
uniform vec2 tex_offset = vec2(0.0, 0.0);
uniform bool tex_flat_top = false;          // верх блока — без узора по глубине (хаори)

varying vec3 tp;
varying vec3 tn;

void vertex() {
	if (tex_local) {
		tp = VERTEX;
		tn = NORMAL;
	} else {
		tp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		tn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	if (length(VERTEX) < 0.35) {
		discard;
	}
	vec3 c = albedo.rgb;
	if (use_tex) {
		vec3 an = abs(tn);
		vec2 uv;
		if (an.y >= an.x && an.y >= an.z) {
			uv = tex_flat_top ? vec2(tp.x, 0.0) : tp.xz;
		} else if (an.x >= an.z) {
			uv = vec2(tp.z, -tp.y);
		} else {
			uv = vec2(tp.x, -tp.y);
		}
		c *= texture(tex, uv * tex_scale * tex_mul + tex_offset).rgb * 1.25;
	}
	ALBEDO = c;
	EMISSION = albedo.rgb * emission;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = nl > 0.5 ? 1.0 : (nl > 0.08 ? 0.6 : shade_floor);
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	r = step(0.45, r) * rim * step(0.08, nl);
	DIFFUSE_LIGHT += (l + r) * LIGHT_COLOR;
}
