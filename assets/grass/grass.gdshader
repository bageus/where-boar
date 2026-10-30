shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

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
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color, color2, 1.0- UV.y) * mix(color, color2, noiseLevel.r);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}