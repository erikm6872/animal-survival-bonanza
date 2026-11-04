shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

// Replaces the flat single-color StandardMaterial3D every water mesh
// (river/pond/waterfall ribbons, see water_generator.gd) used before --
// animated vertex ripple + depth-tinted color + fresnel edge brightening,
// all computed per-frame in-shader so there's no extra per-frame CPU cost
// on top of the one-time mesh build this project already does for water.

uniform vec4 shallow_color : source_color = vec4(0.3, 0.62, 0.68, 0.55);
uniform vec4 deep_color : source_color = vec4(0.04, 0.18, 0.32, 0.88);
uniform float wave_speed = 0.6;
uniform float wave_height = 0.03;
uniform float wave_frequency = 2.2;
uniform float fresnel_power = 3.0;

varying float wave_offset;

void vertex() {
	float t = TIME * wave_speed;
	float wave = sin(VERTEX.x * wave_frequency + t) * cos(VERTEX.z * wave_frequency * 0.8 + t * 1.3);
	wave_offset = wave;
	VERTEX.y += wave * wave_height;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float mix_t = 0.5 + 0.5 * wave_offset;
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, mix_t);
	ALBEDO = mix(base, vec3(1.0), fresnel * 0.4);
	ALPHA = clamp(mix(deep_color.a, shallow_color.a, mix_t) + fresnel * 0.2, 0.0, 1.0);
	ROUGHNESS = 0.05;
	METALLIC = 0.1;
	EMISSION = base * fresnel * 0.15;
}
