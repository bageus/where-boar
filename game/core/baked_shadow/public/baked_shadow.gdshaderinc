// Baked sun shadows of static things (baked_shadow.gd): 0 in the sun, baked_shadow_strength in shadow.
global uniform sampler2D baked_shadow;
global uniform mat4 baked_shadow_view;
global uniform float baked_shadow_strength;

float baked_shadow_at(vec3 world) {
	vec2 uv = (baked_shadow_view * vec4(world, 1.0)).xy;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(baked_shadow, uv).a * baked_shadow_strength;
}
