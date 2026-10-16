// Трава: травинки качаются на ветру и пригибаются рядом с героем.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 col_root : source_color = vec4(0.09, 0.24, 0.1, 1.0);
uniform vec4 col_tip : source_color = vec4(0.3, 0.56, 0.22, 1.0);
uniform vec3 player_pos = vec3(0.0);
uniform float wind = 1.0;

varying float h;

void vertex() {
	h = clamp(VERTEX.y / 0.5, 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.2 + wp.x * 0.35 + wp.z * 0.25) * 0.12 + sin(TIME * 5.3 + wp.x * 1.3) * 0.03;
	vec3 off = vec3(sway, 0.0, sway * 0.5) * wind * h * h;
	vec2 dp = wp.xz - player_pos.xz;
	float dist = length(dp);
	float push = (1.0 - smoothstep(0.0, 1.4, dist)) * h;
	off.xz += normalize(dp + 0.0001) * push * 0.35;
	off.y -= push * 0.15;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	ALBEDO = mix(col_root.rgb, col_tip.rgb, h);
	NORMAL = vec3(0.0, 1.0, 0.0) * mat3(INV_VIEW_MATRIX);
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float l = mix(0.55, 1.0, smoothstep(0.2, 0.5, nl));
	if (!LIGHT_IS_DIRECTIONAL) {
		l = ATTENUATION;
	}
	DIFFUSE_LIGHT += l * LIGHT_COLOR;
}
