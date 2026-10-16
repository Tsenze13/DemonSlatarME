// Контур запечённых (объединённых) блоков: увеличенные копии блоков,
// видны только задние грани; цвет контура — в цвете вершин.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

void fragment() {
	if (length(VERTEX) < 1.2) {
		discard;
	}
	ALBEDO = COLOR.rgb;
}
