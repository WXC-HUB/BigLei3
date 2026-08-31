shader_type spatial;
// Roystan / IronWarrior Toon Water 的同一套算法，搬到 Compatibility 水球上。
// 原文：https://roystan.net/articles/toon-water.html
// 1) 深度缓冲算水深 → 浅/深渐变
// 2) 水深 + 噪声阈值 → 岸边泡沫
// 3) 噪声贴图滚动 + 扭曲贴图 → 表面浪
// 没有 Unity 的 CameraNormalsTexture，用法线从深度重建，泡沫带宽公式不变。
render_mode unshaded, blend_mix, depth_draw_never, cull_back, specular_disabled, shadows_disabled;

uniform vec4 depth_gradient_shallow : source_color = vec4(0.325, 0.807, 0.971, 0.725);
uniform vec4 depth_gradient_deep : source_color = vec4(0.086, 0.407, 1.0, 0.749);
uniform float depth_max_distance = 0.9;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D surface_noise : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 surface_noise_scroll = vec2(0.03, 0.03);
uniform float surface_noise_cutoff : hint_range(0.0, 1.0) = 0.74;
uniform float surface_noise_scale = 10.0;
uniform sampler2D surface_distortion : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float surface_distortion_amount : hint_range(0.0, 1.0) = 0.27;
uniform float surface_distortion_scale = 6.0;
uniform float foam_max_distance = 0.65;
uniform float foam_min_distance = 0.06;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

// 飘云投影：水面是 unshaded，吃不到 DirectionalLight 阴影，只能按云在地面上的
// 落点自己画一团软斑。xy = 世界 XZ，z = 半径，w = 浓度。
uniform vec4 cloud_shadows[8];
uniform int cloud_shadow_count = 0;

const float SMOOTHSTEP_AA = 0.01;


vec4 alpha_blend(vec4 top, vec4 bottom) {
	vec3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
	float alpha = top.a + bottom.a * (1.0 - top.a);
	return vec4(color, alpha);
}


void fragment() {
	float raw_depth = texture(depth_texture, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 scene_clip = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 scene_view = scene_clip.xyz / scene_clip.w;
	float existing_depth_linear = -scene_view.z;
	float water_depth_linear = -VERTEX.z;
	float depth_difference = existing_depth_linear - water_depth_linear;

	float water_depth_01 = clamp(depth_difference / max(depth_max_distance, 0.0001), 0.0, 1.0);
	vec4 water_color = mix(depth_gradient_shallow, depth_gradient_deep, water_depth_01);

	vec3 existing_normal = normalize(cross(dFdx(scene_view), dFdy(scene_view)));
	float normal_dot = clamp(dot(existing_normal, normalize(NORMAL)), 0.0, 1.0);
	float foam_distance = mix(foam_max_distance, foam_min_distance, normal_dot);
	float foam_depth_01 = clamp(depth_difference / max(foam_distance, 0.0001), 0.0, 1.0);
	float noise_cutoff = foam_depth_01 * surface_noise_cutoff;

	vec2 distort_uv = UV * surface_distortion_scale;
	vec2 distort_sample = (texture(surface_distortion, distort_uv).xy * 2.0 - 1.0) * surface_distortion_amount;
	vec2 noise_uv = UV * surface_noise_scale + TIME * surface_noise_scroll + distort_sample;
	float surface_noise_sample = texture(surface_noise, noise_uv).r;
	float surface_noise_mask = smoothstep(
		noise_cutoff - SMOOTHSTEP_AA,
		noise_cutoff + SMOOTHSTEP_AA,
		surface_noise_sample
	);

	vec4 surface_noise_color = foam_color;
	surface_noise_color.a *= surface_noise_mask;
	vec4 out_col = alpha_blend(surface_noise_color, water_color);

	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cloud_shade = 0.0;
	for (int i = 0; i < 8; i++) {
		float live = step(float(i) + 0.5, float(cloud_shadow_count));
		vec4 blob = cloud_shadows[i];
		float dist = length(world_pos.xz - blob.xy);
		float inner = max(blob.z * 0.28, 0.05);
		float outer = max(blob.z, inner + 0.01);
		float cover = (1.0 - smoothstep(inner, outer, dist)) * blob.w * live;
		cloud_shade = max(cloud_shade, cover);
	}
	vec3 shadow_mul = mix(vec3(0.52, 0.62, 0.74), vec3(1.0), 1.0 - cloud_shade);

	ALBEDO = out_col.rgb * shadow_mul;
	ALPHA = mix(out_col.a, min(out_col.a + 0.10, 0.92), cloud_shade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
