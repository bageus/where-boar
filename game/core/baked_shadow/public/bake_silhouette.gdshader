shader_type spatial;
render_mode unshaded, cull_disabled;

// The bake render (baked_shadow.gd): only coverage counts. Parts below min_y are left out: rocks stretched
// deep below a cliff edge would otherwise shade the ground above them.
uniform float min_y = -100000.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y < min_y) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
