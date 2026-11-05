shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Cartoon low-poly flame (owner, 2026-11-05): a faceted cone that sways and flickers in steps,
// yellow where it faces the camera and low, orange then red towards the rim and the tip.
// The mesh is a unit-high cone centred on its origin (y from -0.5 to 0.5); size it with the node's scale.
uniform vec4 core : source_color = vec4(1.0, 0.92, 0.42, 1.0);
uniform vec4 body : source_color = vec4(1.0, 0.56, 0.1, 1.0);
uniform vec4 rim : source_color = vec4(0.92, 0.22, 0.05, 1.0);
uniform float sway = 0.18;
uniform float speed = 2.4;
// Animation frames per second: a choppy, hand-drawn rhythm instead of a smooth one.
uniform float frames = 10.0;

varying float height;

void vertex() {
	height = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float phase = dot(MODEL_MATRIX[3].xz, vec2(7.3, 3.1));
	float t = floor(TIME * frames) / frames * speed + phase;
	float bend = height * height;
	VERTEX.x += (sin(t + height * 3.0) + 0.4 * sin(t * 2.3)) * sway * bend;
	VERTEX.z += cos(t * 1.3 + height * 2.5) * sway * bend;
	VERTEX.y += (0.5 + 0.5 * sin(t * 2.9)) * 0.12 * height;
	VERTEX.xz *= 1.0 + 0.1 * sin(t * 3.7 + height * 4.0);
}

void fragment() {
	// Flat face normal, so every facet reads as one solid colour.
	vec3 facet = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facing = abs(dot(facet, normalize(VIEW)));
	float heat = (1.0 - facing) * 0.7 + height * 0.8;
	ALBEDO = heat < 0.55 ? core.rgb : (heat < 0.95 ? body.rgb : rim.rgb);
}
