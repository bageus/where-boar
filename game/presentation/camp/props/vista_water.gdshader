shader_type spatial;
// The river seen from the camp's drop-off: blue, glossy, with sun glints (game/core/ambient_fx, off on Low quality).
render_mode shadows_disabled;

#include "res://game/core/sun_fx/public/water_glint.gdshaderinc"

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float glint = water_glint(world.xz, 5.0, TIME);
	ALBEDO = vec3(0.25, 0.55, 0.75) + glint;
	EMISSION = vec3(1.0, 0.95, 0.8) * glint * 1.5;
	METALLIC = 0.3;
	ROUGHNESS = 0.15;
}
