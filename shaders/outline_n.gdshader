// Контур по нормалям — для моделей, у которых блоки не в центре меша (мечи игрока).
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 color : source_color = vec4(0.04, 0.03, 0.05, 1.0);
uniform float width = 0.01;
uniform sampler2D tex : source_color, filter_nearest;  // прозрачные пиксели модели — без контура

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	if (texture(tex, UV).a < 0.05) {
		discard;
	}
	ALBEDO = color.rgb;
}
