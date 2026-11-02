shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://game/core/baked_shadow/public/baked_shadow.gdshaderinc"

// Stylized grass (owner, 2026-11-02: grass like in PEAK): bright, saturated blades, dark at the root and
// light yellow-green at the tip, two tints in big soft patches across the ground, a gentle sway in the wind.
// The clump mesh (assets/grass/peak_grass.res, tools/bake_peak_rocks.gd) has UV.y 0 at the root, 1 at the tip.

uniform vec3 root_color : source_color = vec3(0.16, 0.38, 0.08);
uniform vec3 tip_color : source_color = vec3(0.42, 0.7, 0.16);
uniform vec3 patch_color : source_color = vec3(0.6, 0.74, 0.2);
uniform sampler2D noise;
uniform float noiseScale = 20.0;
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.6;

// Leaf pits on the hunt map (x, z, radius): clumps standing in an opening are collapsed away.
uniform vec4 holes[8];
uniform int hole_count = 0;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	for (int i = 0; i < hole_count; i++) {
		if (distance(MODEL_MATRIX[3].xz, holes[i].xy) < holes[i].z) {
			VERTEX = vec3(0.0);
		}
	}
	// Only the upper blade moves; the phase runs across the field so the wind travels in waves.
	float bend = UV.y * UV.y * wind_strength;
	float phase = TIME * wind_speed + MODEL_MATRIX[3].x * 0.35 + MODEL_MATRIX[3].z * 0.2;
	VERTEX.x += sin(phase) * bend * 2.0;
	VERTEX.z += cos(phase * 0.8) * bend;
}

void fragment() {
	float patch = smoothstep(0.35, 0.75, texture(noise, worldPos.xz / noiseScale).r);
	vec3 tip = mix(tip_color, patch_color, patch);
	// Grass under a tree or rock darkens with the ground (baked shadows, game/core/baked_shadow).
	ALBEDO = mix(root_color, tip, smoothstep(0.0, 1.0, UV.y)) * (1.0 - baked_shadow_at(worldPos));
	ROUGHNESS = 1.0;
}
