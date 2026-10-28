shader_type spatial;
// River surface: drifting ripples show the flow (+x); clear and sandy at the edge, deep blue in the middle;
// no shadows on it (owner, 2026-10-28).
render_mode shadows_disabled, cull_disabled, depth_draw_never;

uniform vec3 shallow : source_color = vec3(0.35, 0.75, 0.8);
uniform vec3 deep : source_color = vec3(0.05, 0.35, 0.65);
// Water depth in metres at which it turns fully deep and opaque.
uniform float fade = 0.8;
uniform vec2 flow = vec2(1.0, 0.0);
uniform sampler2D noise : repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float depth = VERTEX.z - view.z / view.w;
	float t = clamp(depth / fade, 0.0, 1.0);
	float a = texture(noise, world.xz * 0.04 - TIME * flow * 0.03).r;
	float b = texture(noise, world.xz * vec2(0.03, 0.09) - TIME * flow * 0.06 + 0.37).r;
	float ripple = smoothstep(0.58, 0.72, a * 0.55 + b * 0.55);
	ALBEDO = mix(shallow, deep, t) + ripple * 0.22;
	ALPHA = mix(0.15, 0.9, t);
	ROUGHNESS = 0.15;
	SPECULAR = 0.4;
}
