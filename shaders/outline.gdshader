shader_type spatial;

// Inverted-hull outline: a slightly-enlarged, backface-only copy of a mesh,
// drawn with depth testing off so it's visible through obstruction once
// shown. Visibility itself (only-when-obstructed) is NOT done here -- a
// per-pixel depth trick turned out to always self-occlude against the
// character's own body no matter the draw order (the shell is, by
// definition, always geometrically behind its own owner's front face).
// Instead scripts/core/outline_visibility.gd toggles this mesh's `visible`
// based on a physics raycast from the camera to the character, so this
// shader only has to worry about rendering through obstruction once it's
// told to be on.
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.05;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
