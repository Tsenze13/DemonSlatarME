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
uniform bool use_vcol = false;             // цвет в вершинах (запечённые блоки мира)
uniform bool tex_local = false;
uniform float tex_scale = 1.0;
uniform vec2 tex_mul = vec2(1.0, 1.0);     // растяжение узора по осям (хаори на рукавах)
uniform vec2 tex_offset = vec2(0.0, 0.0);
uniform bool tex_flat_top = false;          // верх блока — без узора по глубине (хаори)
// Порезы внутри текстуры, по вокселям: плоскость разреза (нормаль + смещение),
// центр и полудлина, ширина. Позиция квантуется сеткой — разрез и его
// затягивание идут целыми «пикселями».
uniform int cut_n = 0;
uniform vec4 cut_pl[8];
uniform vec4 cut_c[8];
uniform float cut_w[8];
uniform float cut_grid = 30.0;

varying vec3 tp;
varying vec3 tn;
varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
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
	if (use_vcol) {
		c *= COLOR.rgb;
	}
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
	float em = 0.0;
	if (cut_n > 0) {
		vec3 q = (floor(lpos * cut_grid) + 0.5) / cut_grid;
		for (int i = 0; i < 8; i++) {
			if (i >= cut_n) {
				break;
			}
			float sd = dot(q, cut_pl[i].xyz) - cut_pl[i].w;
			vec3 along = q - cut_c[i].xyz - cut_pl[i].xyz * sd;
			if (abs(sd) < cut_w[i] && length(along) < cut_c[i].w) {
				float k = abs(sd) / max(cut_w[i], 0.0001);
				// середина — тёмное мясо, края — ярко-красные
				c = k < 0.5 ? vec3(0.3, 0.0, 0.05) : vec3(0.82, 0.08, 0.12);
				em = 0.25;
			}
		}
	}
	ALBEDO = c;
	EMISSION = (use_vcol ? albedo.rgb * COLOR.rgb : albedo.rgb) * emission + c * em;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	// мягкий аниме-свет: две зоны с плавной границей, тень не проваливается в чёрное
	float l = mix(max(shade_floor, 0.2), 1.0, smoothstep(0.04, 0.32, nl));
	if (!LIGHT_IS_DIRECTIONAL) {
		// фонари: светят только в своём радиусе (пол «тени» — только для солнца)
		float ndl = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0);
		l = ndl * ATTENUATION;
	}
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	r = step(0.45, r) * rim * step(0.08, nl);
	DIFFUSE_LIGHT += (l + r) * LIGHT_COLOR;
}
