shader_type canvas_item;
render_mode blend_add, unshaded;

// Screen-space sun: bright disc, wide lens glow and faint rays fanning out from it.
uniform vec2 sun_uv = vec2(0.5, 0.3);
uniform float facing = 0.0;
uniform float aspect = 1.78;
uniform float shafts = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.55);

void fragment() {
	vec2 d = (UV - sun_uv) * vec2(aspect, 1.0);
	float r = length(d);
	float disc = smoothstep(0.045, 0.036, r);
	float glow = exp(-r * 4.5) * 0.45 + exp(-r * 14.0) * 0.5;
	float angle = atan(d.y, d.x);
	float rays = (0.5 + 0.5 * sin(angle * 11.0 + 1.3)) * (0.5 + 0.5 * sin(angle * 5.0 - 0.7));
	float shaft = rays * exp(-r * 2.6) * 0.2 * shafts;
	// Fade as the sun nears the screen edge so it does not pop when it leaves the view.
	vec2 edge = smoothstep(vec2(-0.25), vec2(0.0), sun_uv) * smoothstep(vec2(1.25), vec2(1.0), sun_uv);
	float k = facing * edge.x * edge.y;
	COLOR = vec4(tint * (disc * 1.3 + glow + shaft) * k, 1.0);
}
