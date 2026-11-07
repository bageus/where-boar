shader_type spatial;
// Shout wave as an overlay pass: a band at `radius` metres (flat distance from `centre`) lights any surface
// it crosses, so the ring runs over ground, trees, stumps and rocks alike (owner, 2026-11-07).
render_mode unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 centre;
uniform float radius = 0.0;
uniform float alpha = 0.6;
uniform float width = 0.6;
uniform vec3 colour : source_color = vec3(1.0, 1.0, 0.85);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = 1.0 - abs(distance(world.xz, centre.xz) - radius) / width;
	if (band <= 0.0) {
		discard;
	}
	ALBEDO = colour;
	ALPHA = alpha * band;
}
