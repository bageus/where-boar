shader_type spatial;

// Vertex-coloured ground (hunt terrain and the land around it) with baked shadows; otherwise as a
// StandardMaterial3D with vertex_color_use_as_albedo.
#include "res://game/core/baked_shadow/public/baked_shadow.gdshaderinc"

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - baked_shadow_at(world));
	ROUGHNESS = 1.0;
}
