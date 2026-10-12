// Пост-эффекты в низком разрешении: импакт-кадр, линии скорости,
// виньетка, лёгкая постеризация с дизерингом (пиксельный вид).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float impact = 0.0;
uniform int impact_mode = 0;
uniform float speed = 0.0;
uniform float rtime = 0.0;
uniform float vignette = 0.38;
uniform vec3 tint = vec3(1.0);
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(1.0);
uniform float hurt = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb * tint;

	// постеризация с дизерингом
	float levels = 20.0;
	c = floor(c * levels + 0.5 + bayer4(FRAGCOORD.xy) * 0.9) / levels;

	vec2 d = uv - 0.5;
	d.x *= 16.0 / 9.0;
	float r = length(d);
	float ang = atan(d.y, d.x);

	// линии скорости
	if (speed > 0.01) {
		float seg = floor(ang * 70.0);
		float n = hash(seg * 1.7 + floor(rtime * 20.0) * 13.1);
		float len = 0.28 + hash(seg + 3.3) * 0.25;
		float ln = step(0.68, n) * smoothstep(len, len + 0.25, r);
		c = mix(c, vec3(1.0), clamp(ln * speed, 0.0, 1.0) * 0.85);
	}

	// виньетка + красная кайма при ранении
	c *= 1.0 - vignette * smoothstep(0.45, 1.0, r);
	c = mix(c, vec3(0.55, 0.0, 0.05), hurt * smoothstep(0.35, 0.95, r));

	c = mix(c, flash_col, flash);

	// импакт-кадр: мир превращается в тушь
	if (impact > 0.5) {
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		float t = step(0.33, lum);
		if (impact_mode == 0) {
			c = vec3(1.0 - t);
		} else if (impact_mode == 1) {
			c = mix(vec3(0.02, 0.02, 0.05), vec3(1.0, 0.97, 0.92), t);
		} else {
			c = mix(vec3(0.85, 0.04, 0.08), vec3(0.02), t);
		}
	}
	COLOR = vec4(c, 1.0);
}
