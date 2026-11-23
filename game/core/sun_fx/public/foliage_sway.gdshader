shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_back;

// Trees, pines, palms and bushes (assets/nature/meshes/peak) swaying in the wind: a vertex shader, no textures, as
// cheap as a StandardMaterial3D with vertex colours (same look). The wind blows along +x (clouds, river), in gusts
// that travel across the woods; the top of a tree moves most, leaves flutter a little. strength 0 = still (Low quality).

uniform float strength = 1.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	float h = max(VERTEX.y, 0.0) * scale;
	float phase = TIME * 1.5 + origin.x * 0.07 + origin.z * 0.04;
	float bend = h * h * 0.0022 * strength;
	vec3 push = vec3(0.6 + sin(phase) + 0.4 * sin(phase * 2.3), 0.0, 0.5 * cos(phase * 0.8)) * bend;
	float flutter = 0.02 * strength * smoothstep(0.2, 1.5, h);
	push += vec3(sin(phase * 5.0 + VERTEX.y * 3.0), 0.0, cos(phase * 4.3 + VERTEX.x * 3.0)) * flutter;
	// The push is in world space; bring it into the (rotated, scaled) model's space.
	VERTEX += (push * mat3(MODEL_MATRIX)) / (scale * scale);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
