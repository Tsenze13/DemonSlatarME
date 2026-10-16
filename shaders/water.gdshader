// Вода пруда: пиксельная рябь, отражение неба (светлее под косым углом),
// бегущие блики солнца, белая пена у берега.
shader_type spatial;
render_mode specular_disabled, cull_disabled, blend_mix, depth_draw_always;

uniform vec4 deep : source_color = vec4(0.12, 0.32, 0.45, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.55, 0.6, 1.0);
uniform vec4 sky : source_color = vec4(0.65, 0.8, 0.95, 1.0);
uniform vec4 rect = vec4(-46.0, -12.0, -22.0, 2.0);   // x0, z0, x1, z1
uniform float px = 8.0;                                 // пикселей на метр

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.4 + wp.x * 0.6) * 0.025 + cos(TIME * 1.1 + wp.z * 0.8) * 0.02;
}

void fragment() {
	vec2 q = floor(wp.xz * px) / px;
	// расстояние до берега
	float edge = min(min(q.x - rect.x, rect.z - q.x), min(q.y - rect.y, rect.w - q.y));
	float depth = clamp(edge / 3.0, 0.0, 1.0);
	vec3 c = mix(shallow.rgb, deep.rgb, depth);
	// рябь: полоски, бегущие по ветру
	float wave = sin(q.x * 2.3 + q.y * 1.1 + TIME * 1.6) + sin(q.x * -1.2 + q.y * 2.7 - TIME * 1.1);
	c = mix(c, c * 1.18 + vec3(0.03, 0.05, 0.06), step(1.35, wave));
	// отражение неба по углу взгляда (френель)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c = mix(c, sky.rgb, fres * 0.35);
	// блики: редкие яркие пиксели, мигают
	float g = hash(q * 7.0 + floor(TIME * 3.0));
	c += vec3(1.0, 0.97, 0.9) * step(0.985, g) * 0.8;
	// пена у берега, «дышит»
	float foam = step(edge, 0.35 + 0.15 * sin(TIME * 2.0 + q.x * 3.0 + q.y * 2.0));
	c = mix(c, vec3(0.92, 0.96, 1.0), foam * 0.85);
	ALBEDO = c;
	ALPHA = mix(0.82, 0.95, depth);
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += mix(0.5, 1.0, clamp(dot(NORMAL, LIGHT), 0.0, 1.0)) * ATTENUATION * LIGHT_COLOR;
}
