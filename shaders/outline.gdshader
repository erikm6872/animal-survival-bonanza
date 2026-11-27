shader_type spatial;

// Inverted-hull outline: a slightly-enlarged, backface-only copy of a mesh.
// depth_test_inverted flips the usual depth comparison so this shell only
// survives where something nearer has ALREADY been drawn (i.e. it's
// genuinely obstructed) and is discarded everywhere the view is clear --
// see OutlineEffect (scripts/core/outline_effect.gd) for how draw order
// (scene, then this shell, then the real body) makes that work.
render_mode unshaded, cull_front, depth_draw_never, depth_test_inverted;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.05;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
