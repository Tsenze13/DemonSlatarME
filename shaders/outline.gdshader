// Контур: оболочка чуть больше модели, видны только её задние грани.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 color : source_color = vec4(0.04, 0.03, 0.05, 1.0);
uniform float width = 0.022;

void vertex() {
	VERTEX += sign(VERTEX) * width;
}

void fragment() {
	// камера внутри объекта (крона дерева) — не закрывать обзор
	if (length(VERTEX) < 1.2) {
		discard;
	}
	ALBEDO = color.rgb;
}
