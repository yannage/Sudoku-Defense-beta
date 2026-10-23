shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform bool face_shading = true;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// A fixed studio key and cool fill preserve the voxel silhouette on every
	// device. Depth testing, occlusion, and all geometry remain native 3D.
	vec3 normal = normalize(world_normal);
	float key = max(dot(normal, normalize(vec3(-0.45, 0.86, 0.30))), 0.0);
	float fill = max(dot(normal, normalize(vec3(0.65, 0.25, -0.72))), 0.0);
	float light = face_shading ? (0.48 + key * 0.58 + fill * 0.18) : 1.0;
	ALBEDO = tint.rgb * light;
}
