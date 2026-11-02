shader_type spatial;

#include "res://game/core/baked_shadow/public/baked_shadow.gdshaderinc"

// Hunt ground (owner, 2026-11-02): a ground texture in the grass's style, so the grass reads as one carpet
// with no bare gaps, and a bumpy surface on grass and sand, so the sun gives them shading and highlights.
// Vertex-coloured like vertex_ground.gdshader. Where the vertex colour is grass green it is painted in the
// grass's own colours: the blade-root green, soft blotches of the blade tips, the same yellow-green patches
// as peak_grass.gdshader and a fine mottle of tufts. Far away, where no clumps are drawn, it turns towards
// the tip colour, as a field of grass looks from a distance. Sand and mud get wind ripples and grains.
// The ground mesh has no tangents, so the bump map tilts the world normal along world x and z (the ground
// is mostly level, which is where it shows).

uniform vec3 root_color : source_color = vec3(0.16, 0.38, 0.08);
uniform vec3 tip_color : source_color = vec3(0.42, 0.7, 0.16);
uniform vec3 patch_color : source_color = vec3(0.6, 0.74, 0.2);
uniform sampler2D noise : repeat_enable;
uniform sampler2D bump : hint_normal, repeat_enable;
uniform float noiseScale = 20.0;
uniform vec2 far_fade = vec2(10.0, 30.0);
uniform float grass_bump = 0.5;
uniform float sand_bump = 1.8;

varying vec3 world;
varying vec3 world_normal;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// The bump map's slope at uv (x, z of world space), -1..1 each.
vec2 slope(vec2 uv) {
	return texture(bump, uv).xy * 2.0 - 1.0;
}

void fragment() {
	vec3 color = COLOR.rgb;
	float green = smoothstep(0.05, 0.18, COLOR.g - max(COLOR.r, COLOR.b));
	float sandy = smoothstep(0.03, 0.08, COLOR.r - COLOR.g);
	vec2 tilt = vec2(0.0);
	float shine = 0.0;
	if (green > 0.0) {
		float patch = smoothstep(0.35, 0.75, texture(noise, world.xz / noiseScale).r);
		float blotch = texture(noise, world.xz / 3.1 + vec2(0.37, 0.11)).r;
		float tuft = texture(noise, world.xz / 0.55 + vec2(0.71, 0.53)).r;
		// Stepped, not smooth: the hand-painted look of the clumps' flat-shaded blades.
		float tone = floor((blotch * 0.8 + tuft * 0.35) * 4.0) / 4.0;
		vec3 lawn = mix(root_color * 0.9, mix(tip_color, patch_color, patch), clamp(tone * 0.75, 0.0, 0.8));
		float far = smoothstep(far_fade.x, far_fade.y, length(world - CAMERA_POSITION_WORLD));
		lawn = mix(lawn, mix(root_color, mix(tip_color, patch_color, patch), 0.6), far * 0.6);
		color = mix(color, lawn, green);
		// Lumpy turf: bumps a metre or two across with small tufts on them.
		tilt += (slope(world.xz / 6.0) + slope(world.xz / 1.3) * 0.5) * grass_bump * green;
	}
	if (sandy > 0.0) {
		// Wind ripples across the bank (stretched along x) and fine grains; the ripple crests catch light.
		vec2 ripple = slope(world.xz * vec2(0.06, 0.3));
		vec2 grain = slope(world.xz / 0.7);
		tilt += (ripple + grain * 0.35) * sand_bump * sandy;
		float crest = texture(noise, world.xz * vec2(0.05, 0.3)).r;
		color *= mix(1.0, 0.82 + crest * 0.3, sandy);
		shine = sandy;
	}
	vec3 n = normalize(normalize(world_normal) + vec3(tilt.x, 0.0, tilt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = color * (1.0 - baked_shadow_at(world));
	ROUGHNESS = mix(1.0, 0.75, shine);
	SPECULAR = mix(0.2, 0.4, shine);
}
