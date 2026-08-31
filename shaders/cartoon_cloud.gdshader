shader_type spatial;
// 选关图飘云：几颗圆球叠成一团，亮面白、肚皮略蓝、外沿一圈浅线。
// 不采样贴图、不吃光，避免 KayKit 那套低模图集看起来像石头。
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;

uniform vec4 fill : source_color = vec4(0.99, 0.99, 1.0, 1.0);
uniform vec4 belly : source_color = vec4(0.82, 0.90, 0.98, 1.0);
uniform vec4 line : source_color = vec4(0.58, 0.72, 0.88, 1.0);
uniform float line_width : hint_range(0.0, 0.6) = 0.28;


void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float down = smoothstep(-0.05, 0.72, -world_n.y);
	float facing = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(1.0 - line_width, 1.0, facing);
	ALBEDO = mix(fill.rgb, belly.rgb, down * 0.85);
	ALBEDO = mix(ALBEDO, line.rgb, rim);
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
