shader_type spatial;
render_mode unshaded;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;

	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;

	float z_near = 1.0;
	float z_far = 100.0;
	float scaled_depth = (z_far * z_near) / (z_far + (view.z * (z_near - z_far)));

	ALBEDO = vec3(scaled_depth);
}
