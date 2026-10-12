// Хаори из толстых блоков: пиксельный узор на лицевых гранях,
// торцы темнее (цвет вершины), аниме-свет.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D pattern : source_color, filter_nearest, repeat_enable;

void fragment() {
	ALBEDO = texture(pattern, UV).rgb * COLOR.rgb;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = nl > 0.5 ? 1.0 : (nl > 0.08 ? 0.6 : 0.0);
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
