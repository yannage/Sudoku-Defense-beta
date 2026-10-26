shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec2 bar_size = vec2(0.48, 0.08);
uniform float border = 0.015;
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 track_color : source_color = vec4(0.071, 0.149, 0.188, 1.0);
uniform vec4 fill_color : source_color = vec4(1.0, 0.765, 0.584, 1.0);

void fragment() {
	vec2 p = UV * bar_size;
	float fill_end = border + (bar_size.x - 2.0 * border) * fill_ratio;
	bool inside = p.x >= border && p.x < fill_end && p.y >= border && p.y <= bar_size.y - border;
	ALBEDO = inside ? fill_color.rgb : track_color.rgb;
}
