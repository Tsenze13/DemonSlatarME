// Аниме-свет: тени в три чётких тона + лёгкий контровой свет.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission = 0.0;
uniform float rim = 0.18;
uniform float shade_floor = 0.0;

void fragment() {
	if (length(VERTEX) < 0.35) {
		discard;
	}
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * emission;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = nl > 0.5 ? 1.0 : (nl > 0.08 ? 0.55 : shade_floor);
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	r = step(0.45, r) * rim * step(0.08, nl);
	DIFFUSE_LIGHT += (l + r) * LIGHT_COLOR;
}
