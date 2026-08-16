shader_type canvas_item;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = vec3(gray) * 0.62;
	source.a *= 0.72;
	COLOR = source;
}
