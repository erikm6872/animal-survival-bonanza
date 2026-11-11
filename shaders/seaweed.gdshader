shader_type spatial;
// Double-sided: each blade is a single flat tapered strip with no twin
// surface behind it, so (unlike the tuna's paired flank sheets) there's
// nothing coplanar to bleed through.
render_mode cull_disabled;

uniform vec3 albedo_color : source_color = vec3(0.10, 0.42, 0.18);
uniform float sway_strength = 0.3;
uniform float sway_speed = 1.1;
// Blades are authored BLADE_HEIGHT units tall with the root at y=0; the
// bend factor needs the authored height so sway stays proportional no
// matter how each MultiMesh instance is scaled.
uniform float blade_height = 2.0;

void vertex() {
	// Phase from world position so neighboring blades in a patch drift
	// out of step instead of swaying in lockstep. MODEL_MATRIX includes
	// the per-instance MultiMesh transform.
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world_pos.x * 0.7 + world_pos.z * 0.9;
	// Root stays planted, tip sways the most.
	float bend = pow(clamp(VERTEX.y / blade_height, 0.0, 1.0), 1.5);
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_strength * bend;
	VERTEX.z += cos(TIME * sway_speed * 0.73 + phase * 1.31) * sway_strength * 0.5 * bend;
}

void fragment() {
	ALBEDO = albedo_color;
	ROUGHNESS = 0.9;
}
