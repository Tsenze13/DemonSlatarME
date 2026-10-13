// Хаори из толстых блоков: пиксельный узор на лицевых гранях,
// торцы темнее (цвет вершины), аниме-свет.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D pattern : source_color, filter_nearest, repeat_enable;
uniform vec4 lining : source_color = vec4(0.12, 0.1, 0.16, 1.0);   // подкладка (изнанка, COLOR.a = 0)

void fragment() {
	if (COLOR.a < 0.5) {
		// подкладка: однотонная, с мелкой пиксельной фактурой
		vec2 q = floor(UV * vec2(32.0, 16.0));
		float n = fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453);
		ALBEDO = lining.rgb * (0.92 + 0.12 * n);
	} else {
		ALBEDO = texture(pattern, UV).rgb * COLOR.rgb;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = nl > 0.5 ? 1.0 : (nl > 0.08 ? 0.6 : 0.0);
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
