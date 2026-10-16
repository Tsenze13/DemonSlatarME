// Водопад: пиксельные струи бегут вниз, белые полосы пены, края рваные.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float px = 10.0;          // пикселей на метр (как у текстур мира)
uniform vec2 size = vec2(3.2, 17.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 q = floor(UV * size * px) / px;
	float col = floor(q.x * 2.5);
	// каждая струя бежит со своей скоростью
	float spd = 5.0 + hash(vec2(col, 1.0)) * 4.0;
	float y = q.y - TIME * spd;
	float n = hash(vec2(col, floor(y * 1.6)));
	vec3 deep = vec3(0.32, 0.56, 0.72);
	vec3 light = vec3(0.7, 0.86, 0.95);
	vec3 c = mix(deep, light, step(0.55, n));
	// пена
	float foam = step(0.86, hash(vec2(col * 3.1, floor(y * 3.0))));
	c = mix(c, vec3(0.96, 0.98, 1.0), foam);
	// внизу — сплошная пена, вверху — гребень
	float bottom = smoothstep(0.82, 1.0, UV.y);
	c = mix(c, vec3(0.95, 0.97, 1.0), bottom * 0.8);
	c = mix(c, vec3(0.9, 0.95, 1.0), step(UV.y, 0.025));
	// рваные края
	float edge = min(UV.x, 1.0 - UV.x) * size.x;
	float rag = 0.12 + hash(vec2(floor(y * 2.0), step(0.5, UV.x))) * 0.25;
	ALBEDO = c;
	ALPHA = step(rag, edge) * 0.92;
}
