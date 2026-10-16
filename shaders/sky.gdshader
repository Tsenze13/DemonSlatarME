// Небо: градиент по времени суток, солнце с ореолом, пушистые облака
// (крупными «пикселями», как в воксельных играх), звёзды и луна ночью.
shader_type sky;

uniform vec3 top_col : source_color = vec3(0.25, 0.48, 0.85);
uniform vec3 hor_col : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_col : source_color = vec3(0.35, 0.4, 0.38);
uniform vec3 sun_col : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 cloud_lit : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.6, 0.66, 0.78);
uniform vec3 sun_dir = vec3(0.3, 0.5, -0.8);
uniform float sun_size = 0.035;
uniform float halo = 0.6;          // сила ореола вокруг солнца (закат)
uniform float cloud_cover = 0.45;
uniform float stars = 0.0;
uniform vec3 moon_dir = vec3(-0.45, 0.55, -0.7);
uniform float moon = 0.0;
uniform float pix = 220.0;          // «пиксели» облаков на радиан

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	// градиент: у горизонта светлее, вниз — земля в дымке
	float t = pow(clamp(y, 0.0, 1.0), 0.55);
	vec3 c = mix(hor_col, top_col, t);
	if (y < 0.0) {
		c = mix(hor_col, ground_col, clamp(-y * 4.0, 0.0, 1.0));
	}
	vec3 sd = normalize(sun_dir);
	float sdot = dot(d, sd);
	// ореол: широкое тёплое свечение вокруг солнца и у горизонта
	float glow = pow(max(sdot, 0.0), 6.0) * halo + pow(max(sdot, 0.0), 40.0) * halo * 0.8;
	float hband = exp(-abs(y) * 9.0) * pow(max(sdot * 0.5 + 0.5, 0.0), 3.0) * halo;
	c += sun_col * (glow + hband * 0.7);
	// диск солнца
	float disk = smoothstep(cos(sun_size * 1.15), cos(sun_size), sdot);
	c = mix(c, sun_col * 1.6 + vec3(0.3), disk * step(-0.05, sd.y));

	// звёзды
	if (stars > 0.0 && y > 0.0) {
		vec2 sp = floor(vec2(atan(d.x, d.z), asin(y)) * 260.0);
		float s = step(0.996, hash(sp));
		float tw = 0.6 + 0.4 * sin(TIME * 3.0 + hash(sp + 3.0) * 30.0);
		c += vec3(0.9, 0.92, 1.0) * s * tw * stars * smoothstep(0.0, 0.25, y);
	}
	// луна с ореолом
	if (moon > 0.0) {
		vec3 md = normalize(moon_dir);
		float mdot = dot(d, md);
		float mdisk = smoothstep(cos(0.06), cos(0.055), mdot);
		vec3 mc = vec3(1.0, 0.97, 0.86);
		// кратеры: пятна в пикселях
		vec2 mp = floor((d - md).xy * 160.0);
		mc *= 0.85 + 0.15 * step(0.5, hash(mp));
		c += vec3(0.5, 0.55, 0.8) * pow(max(mdot, 0.0), 60.0) * moon * 0.5;
		c = mix(c, mc, mdisk * moon);
	}

	// облака: проекция на купол, крупные пиксели, освещены со стороны солнца
	if (y > 0.015) {
		vec2 uv = d.xz / (y + 0.25);
		// крупные пиксели облаков — в угловых координатах (без треугольных осколков у горизонта)
		vec2 ang = vec2(atan(d.x, d.z), asin(y));
		vec2 qa = (floor(ang * pix) + 0.5) / pix;
		vec3 qd = vec3(sin(qa.x) * cos(qa.y), sin(qa.y), cos(qa.x) * cos(qa.y));
		uv = qd.xz / (qd.y + 0.25);
		vec2 drift = vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv * 0.55 + drift);
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.12, n);
		// освещение облака: смещение к солнцу
		float n2 = fbm((uv + sd.xz * 0.25) * 0.55 + drift);
		float lit = clamp((n - n2) * 4.0 + 0.55, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit, lit);
		// край облака у солнца светится
		cc += sun_col * pow(max(sdot, 0.0), 8.0) * halo * 0.6 * (1.0 - cov * 0.5);
		float fade = smoothstep(0.03, 0.3, y);
		c = mix(c, cc, cov * fade * 0.95);
	}
	COLOR = c;
}
