shader_type spatial;
render_mode unshaded;

// Glowing coals (owner, 2026-11-05): patches drift between a dark red and a hot yellow in a few flat
// steps, so the coals in the brazier and the fire pit seem to breathe.
uniform vec4 cool : source_color = vec4(0.5, 0.07, 0.02, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.38, 0.06, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float speed = 1.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * speed;
	float n = sin(world.x * 21.0 + t * 1.7) * sin(world.z * 17.0 - t * 1.3) + 0.5 * sin(t * 2.9 + world.x * 9.0 + world.z * 5.0);
	float heat = floor(clamp(0.5 + 0.4 * n, 0.0, 0.999) * 3.0) / 2.0;
	ALBEDO = heat < 0.5 ? mix(cool.rgb, warm.rgb, heat * 2.0) : mix(warm.rgb, hot.rgb, heat * 2.0 - 1.0);
}
