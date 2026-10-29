shader_type spatial;
render_mode specular_disabled;

// Camp ground (owner, 2026-10-29): mottled dirt with reddish clay, a wobbly grass border along the
// rock wall, the palisade and the south-west, and trodden patches and paths (dressing.gd fills the
// worn_* uniforms). edge_band() and greenness() mirror Dressing.greenness() in dressing.gd.

uniform float half_size = 17.0;
uniform float south_split = 2.0;
uniform sampler2D mottle : filter_linear_mipmap, repeat_enable;
uniform int worn_count = 0;
// Each worn strip runs from xy to zw (a patch when they match) with the radius in worn_radius.
uniform vec4 worn_from_to[16];
uniform float worn_radius[16];

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float edge_band(float d, float t) {
	float w = 3.0 + 1.1 * sin(t * 0.37) + 0.6 * sin(t * 1.21 + 1.7);
	return 1.0 - smoothstep(w - 1.4, w + 0.4, d);
}

float greenness(vec2 p) {
	float g = max(edge_band(p.x + half_size, p.y), edge_band(p.y + half_size, p.x + 7.0));
	return max(g, edge_band(half_size - p.y, p.x + 3.0) * (1.0 - smoothstep(south_split - 4.0, south_split, p.x)));
}

float worn(vec2 p) {
	float w = 0.0;
	for (int i = 0; i < worn_count; i++) {
		vec2 a = worn_from_to[i].xy;
		vec2 ab = worn_from_to[i].zw - a;
		float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		float d = length(p - a - ab * h);
		w = max(w, 1.0 - smoothstep(worn_radius[i] * 0.45, worn_radius[i], d));
	}
	return w;
}

void fragment() {
	vec2 p = world.xz;
	float big = texture(mottle, p * 0.023).r;
	float fine = texture(mottle, p * 0.19 + 0.37).r;
	vec3 dirt = mix(vec3(0.58, 0.48, 0.34), vec3(0.71, 0.6, 0.42), big);
	dirt = mix(dirt, vec3(0.68, 0.48, 0.33), smoothstep(0.55, 0.75, fine) * 0.3);
	dirt *= 0.93 + 0.14 * fine;
	float w = worn(p + (vec2(big, fine) - 0.5) * 1.6);
	dirt = mix(dirt, vec3(0.8, 0.71, 0.56) * (0.97 + 0.06 * fine), w * 0.8);
	float g = greenness(p + (vec2(fine, big) - 0.5) * 2.2) * (1.0 - w);
	vec3 grass = mix(vec3(0.19, 0.41, 0.1), vec3(0.33, 0.53, 0.16), big) * (0.85 + 0.3 * fine);
	vec3 moss = mix(dirt, vec3(0.45, 0.47, 0.24), 0.6);
	vec3 colour = mix(mix(dirt, moss, smoothstep(0.05, 0.4, g)), grass, smoothstep(0.35, 0.8, g));
	ALBEDO = pow(colour, vec3(2.2));  // the colours above are sRGB, as in a StandardMaterial3D
	ROUGHNESS = 1.0;
}
