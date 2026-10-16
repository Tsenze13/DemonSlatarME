// Хаори из толстых блоков: пиксельный узор на лицевых гранях,
// торцы темнее (цвет вершины), аниме-свет.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D pattern : source_color, filter_nearest, repeat_enable;
uniform vec4 lining : source_color = vec4(0.12, 0.1, 0.16, 1.0);   // подкладка (изнанка, COLOR.a = 0)
// стихия на ткани: 0 нет, 1 вода (ткань темнеет — мокрая, капли бликуют),
// 2 пламя (низ тлеет: бегущие угли по краю), 3 гром (искры-разряды)
uniform int elem = 0;
uniform float elem_k = 0.0;
uniform vec4 elem_col : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float v_bottom = 1.0;      // где на узоре низ полы (v)

void fragment() {
	if (COLOR.a < 0.5) {
		// подкладка: однотонная, с мелкой пиксельной фактурой
		vec2 q = floor(UV * vec2(32.0, 16.0));
		float n = fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453);
		ALBEDO = lining.rgb * (0.92 + 0.12 * n);
	} else {
		ALBEDO = texture(pattern, UV).rgb * COLOR.rgb;
	}
	if (elem_k > 0.01 && elem > 0) {
		vec2 q = floor(UV * vec2(64.0, 24.0));
		float n = fract(sin(dot(q + floor(TIME * 8.0), vec2(12.9898, 78.233))) * 43758.5453);
		float low = smoothstep(v_bottom - 0.35, v_bottom, UV.y);
		if (elem == 1) {
			ALBEDO *= mix(1.0, 0.72, elem_k);                         // мокрая ткань темнее
			EMISSION = elem_col.rgb * step(0.985, n) * elem_k * 0.8;  // блики капель
		} else if (elem == 2) {
			float ember = low * step(0.82 - low * 0.3, n);
			ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.55, 0.3, 0.2), low * elem_k * 0.6);   // подпалина
			EMISSION = elem_col.rgb * ember * elem_k * 2.2;
		} else {
			float sp = step(0.97, n) * (0.4 + low);
			EMISSION = elem_col.rgb * sp * elem_k * 2.5;
		}
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = mix(0.38, 1.0, smoothstep(0.04, 0.32, nl));   // тень не чёрная — узор читается
	if (!LIGHT_IS_DIRECTIONAL) {
		l = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
	}
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
