// Sun glints on water: small points that flare up one after another. Strength comes from AmbientFx (0 on Low quality).
global uniform float glint_strength;

float glint_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// cell: metres per glint cell (bigger for water seen from far away).
float water_glint(vec2 world_xz, float cell, float time) {
	vec2 g = world_xz / cell;
	vec2 id = floor(g);
	float h = glint_hash(id);
	vec2 centre = vec2(glint_hash(id + 7.0), glint_hash(id + 13.0)) * 0.6 + 0.2;
	float spot = smoothstep(0.2, 0.0, length(fract(g) - centre));
	float flash = pow(max(0.0, sin(time * (1.5 + h * 2.5) + h * 40.0)), 14.0);
	return spot * flash * step(0.35, h) * glint_strength;
}
